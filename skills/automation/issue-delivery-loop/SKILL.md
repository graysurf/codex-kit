---
name: issue-delivery-loop
description: "Orchestrate plan-issue review/close loops where main-agent owns orchestration and review only, subagents own implementation PRs, and close gates require approval plus merged PRs."
---

# Issue Delivery Loop

## Contract

Prereqs:

- Run inside (or have access to) the target repository.
- `plan-issue` and `plan-issue-local` available on `PATH`.
- `gh` available on `PATH`, and `gh auth status` succeeds for live issue/PR reads and writes.
- `issue-pr-review` is the review decision workflow after handoff.

Inputs:

- Plan issue number (`--issue <number>`) created during plan orchestration.
- Optional repository override (`--repo <owner/repo>`).
- Optional review summary text (`--summary`).
- Approval comment URL (`https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`) when closing.
- Local rehearsal body markdown file (`--body-file <path>`) for dry-run handoff/close checks.
- Runtime mode:
  - Live mode: `plan-issue ...` for GitHub-backed orchestration.
  - Local rehearsal mode:
    - `plan-issue-local ... --dry-run` for local sprint/status orchestration from body files.
    - `plan-issue --dry-run --body-file ...` for plan-level review/close gate rehearsal.
- Task owners must be subagent identities (must reference `subagent`); `main-agent` ownership is invalid for implementation tasks.

Outputs:

- Deterministic orchestration over typed `plan-issue`/`plan-issue-local` command flows with explicit gate checks.
- Status snapshots and review-request markdown blocks for traceable issue history.
- Issue close only when review approval and merged-PR checks pass via `close-plan`.
- Definition of done: execution is complete only when `close-plan` succeeds and the target issue is actually closed.
- Error contract: if any gate/command fails, stop forward progress and report the failing command plus key stderr/stdout gate errors.
- Main-agent acts as orchestrator/reviewer only; implementation branches/PRs are delegated to subagents.
- Issue task table remains the single execution source of truth (`Subagent PRs` section is legacy and removed by sync).

Exit codes:

- `0`: success
- `1`: runtime failure / gate failure
- `2`: usage error

Failure modes:

- Missing required options (`--issue`, `--approved-comment-url`, `--summary` when required by policy).
- Missing required binaries (`plan-issue`/`plan-issue-local`; `gh` for live mode).
- Invalid approval URL format or repo mismatch with `--repo`.
- Task rows violate close gates (status not `done`, execution metadata/PR missing, or PR not merged).
- Issue/PR metadata fetch fails via `gh` in live mode.
- `close-plan --dry-run` invoked without required `--body-file` in local rehearsal.
- Task `Owner` is `main-agent`/non-subagent identity in `Task Decomposition`.

## Role Boundary (Mandatory)

- Main-agent is limited to issue orchestration:
  - status/review-handoff/close gates
  - dispatch and acceptance decisions
- Main-agent must not implement issue tasks directly.
- Even for a single-PR issue, implementation must be produced by a subagent PR and then reviewed by main-agent.
- Main-agent review/merge decisions should use `issue-pr-review`; this loop skill enforces ownership and close gates.

## Core usage

1. Select execution mode:
   - Live mode: `plan-issue <subcommand> ...`
   - Local rehearsal mode: `plan-issue-local` for local sprint/status checks; `plan-issue --dry-run --body-file ...` for `ready-plan`/`close-plan`.
2. Dispatch implementation to subagent(s):
   - Use `issue-subagent-pr` workflow to create task worktrees/PRs.
3. Update status snapshot (main-agent checkpoint):
   - `plan-issue status-plan --repo <owner/repo> --issue <number>`
   - Local rehearsal: `plan-issue-local status-plan --body-file <path> --dry-run`
4. Request review (main-agent review handoff):
   - `plan-issue ready-plan --repo <owner/repo> --issue <number> --summary "<review focus>"`
   - Local rehearsal: `plan-issue ready-plan --summary "<review focus>" --dry-run --body-file <path>`
5. Main-agent review decision:
   - Use `issue-pr-review` to request follow-up or merge after checks/review are satisfied.
6. Close after explicit review approval:
   - `plan-issue close-plan --repo <owner/repo> --issue <number> --approved-comment-url <url>`
   - Local rehearsal: `plan-issue close-plan --approved-comment-url <url> --dry-run --body-file <path>`

## Completion Policy (Mandatory)

- Do not stop at `status-plan` or `ready-plan` as a final state.
- A successful run must terminate at `close-plan` with issue state `CLOSED`.
- If close gates fail, treat the run as unfinished and report:
  - failing command
  - gate errors (task status, PR merge, approval URL, or owner policy)
  - next required unblock action

## Full Skill Flow

1. Confirm repository context, runtime mode (`plan-issue` vs `plan-issue-local`), and `gh auth status` for live mode.
2. Confirm the plan issue already exists and task decomposition ownership remains subagent-only.
3. Main-agent dispatches implementation tasks to subagents (for example via `issue-subagent-pr`), while remaining orchestration/review-only.
4. As subagent PRs progress, update the issue task table and PR links so task state stays consistent.
   - Fill real `Owner` / `Branch` / `Worktree` / `Execution Mode` / `PR` values as execution happens (initial `TBD` rows are expected).
   - Use canonical PR references as `#<number>` for tables/comments.
5. Run `status-plan` to generate a main-agent snapshot comment for task/PR/review state checkpoints.
6. Run `ready-plan` when the issue is ready for main-agent review handoff.
7. Main-agent reviews subagent PRs (typically with `issue-pr-review`), requests follow-up or merges until close gates are satisfied.
8. Run `close-plan` with an explicit approval comment URL to enforce final gates (task status plus merged PR checks), re-sync/normalize the issue task table, and close the issue.

## Notes

- Use `plan-issue-local` for local sprint/status orchestration from body files.
- Use `plan-issue --dry-run --body-file ...` for deterministic offline `ready-plan` / `close-plan` gate rehearsal.
- `Execution Mode` controls branch/worktree uniqueness checks: only `pr-isolated` requires unique branch/worktree per row.
- Use `--dry-run` to suppress write operations while previewing commands.
