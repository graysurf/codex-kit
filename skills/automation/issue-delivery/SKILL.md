---
name: issue-delivery
description: "Orchestrate plan-issue review/close loops where main-agent owns orchestration and review only, subagents own implementation PRs, and close gates require approval plus merged PRs."
---

# Issue Delivery

## Contract

Prereqs:

- Run inside (or have access to) the target repository.
- `plan-issue` available on `PATH`.
- `gh` available on `PATH`, and `gh auth status` succeeds for live issue/PR reads and writes.
- `issue-pr-review` is the review decision workflow after handoff.

Inputs:

- Plan issue number (`--issue <number>`) created during plan orchestration.
- `ISSUE_NUMBER` should be captured from upstream `plan-issue start-plan` output and reused across all commands in this skill.
- Optional repository override (`--repo <owner/repo>`).
- Optional review summary text (`--summary`).
- Plan-close approval comment URL (`PLAN_APPROVED_COMMENT_URL`) for `close-plan`.
- Approval URL format: `https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`.
- PR linkage inputs for runtime row sync (`--task <task-id>` or `--sprint <n> [--pr-group <group>]`, plus `--pr <#123|123|pull-url>`).
- Conditional subagent dispatch bundle (required when this issue is plan-sprint originated via `plan-issue start-sprint`):
  - rendered `TASK_PROMPT_PATH` artifact for the assigned lane/task
  - `prompts/plan-issue-delivery-subagent-init.md`
  - plan task section context (exact snippet and/or direct link/path)
- Local rehearsal policy:
  - This main skill is live-mode default (`plan-issue ...`).
  - If rehearsal is explicitly requested, load `references/LOCAL_REHEARSAL.md`.
- Task owners must be subagent identities (must reference `subagent`); `main-agent` ownership is invalid for implementation tasks.

Outputs:

- Deterministic orchestration over typed `plan-issue` command flows with explicit gate checks.
- Status snapshots and review-request markdown blocks for traceable issue history.
- Deterministic PR linkage/status sync through `link-pr` before review and close gates.
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
- Missing required binaries (`plan-issue`; `gh` for live mode).
- Invalid approval URL format or repo mismatch with `--repo`.
- `link-pr` target ambiguity (for example sprint selector spans multiple runtime lanes without `--pr-group`).
- `link-pr` rejected PR selector (`--pr` does not resolve to a concrete PR number).
- Task rows violate close gates (status not `done`, execution metadata/PR missing, or PR not merged).
- Issue/PR metadata fetch fails via `gh` in live mode.
- Task `Owner` is `main-agent`/non-subagent identity in `Task Decomposition`.
- Plan-sprint originated dispatch launched without required bundle (`TASK_PROMPT_PATH`, `plan-issue-delivery-subagent-init.md`, plan task snippet/link/path).

## Role Boundary (Mandatory)

- Main-agent is limited to issue orchestration:
  - status/review-handoff/close gates
  - dispatch and acceptance decisions
- Main-agent must not implement issue tasks directly.
- Even for a single-PR issue, implementation must be produced by a subagent PR and then reviewed by main-agent.
- Main-agent review/merge decisions should use `issue-pr-review`; this loop skill enforces ownership and close gates.

## References

- Local rehearsal playbook (`plan-issue-local` and `plan-issue --dry-run`): `references/LOCAL_REHEARSAL.md`

## Core usage

1. Live mode is default in this main skill: `plan-issue <subcommand> ...`.
2. Resolve and reuse a single `ISSUE_NUMBER` from upstream plan orchestration, then dispatch implementation to subagents via `issue-subagent-pr`.
   - If the issue originated from `plan-issue start-sprint`, dispatch each subagent with:
     - rendered `TASK_PROMPT_PATH`
     - `prompts/plan-issue-delivery-subagent-init.md`
     - assigned plan task section snippet/link/path
3. Keep runtime-truth rows synchronized with `link-pr`; add `status-plan` checkpoints when needed.
4. Handoff review with `ready-plan`, run main-agent review decisions through `issue-pr-review`, and merge/follow-up until close gates are satisfied.
5. Close with `close-plan` using `PLAN_APPROVED_COMMENT_URL`.
6. If local rehearsal is explicitly requested, switch to `references/LOCAL_REHEARSAL.md`.

## Completion Policy (Mandatory)

- Do not stop at `status-plan` or `ready-plan` as a final state.
- A successful run must terminate at `close-plan` with issue state `CLOSED`.
- If close gates fail, treat the run as unfinished and report:
  - failing command
  - gate errors (task status, PR merge, approval URL, or owner policy)
  - next required unblock action

## Full Skill Flow

1. Confirm repository context, runtime mode (`plan-issue`), and `gh auth status` for live mode.
2. Confirm the plan issue already exists, capture `ISSUE_NUMBER` from upstream orchestration output, and keep using that single value for all `--issue` flags.
3. Confirm task decomposition ownership remains subagent-only.
4. Main-agent dispatches implementation tasks to subagents (for example via `issue-subagent-pr`), while remaining orchestration/review-only.
   - For plan-sprint originated issues, dispatch must include the required bundle:
     - rendered `TASK_PROMPT_PATH`
     - `prompts/plan-issue-delivery-subagent-init.md`
     - assigned plan task section snippet/link/path
5. As subagent PRs progress, run `link-pr` to update issue task `PR` and `Status` fields (instead of manual table edits).
   - Task-scoped link: `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - `--task` automatically syncs shared-lane rows (`per-sprint` / `pr-shared`) in one operation.
   - Sprint-scoped link is valid only when the target resolves to one runtime lane; otherwise specify `--pr-group`.
6. Run `status-plan` to generate a main-agent snapshot comment for task/PR/review state checkpoints.
7. Run `ready-plan` when the issue is ready for main-agent review handoff.
8. Main-agent reviews subagent PRs (typically with `issue-pr-review`), requests follow-up or merges until close gates are satisfied.
9. Run `close-plan` with `PLAN_APPROVED_COMMENT_URL` to enforce final gates (task status plus merged PR checks), re-sync/normalize the issue task table, and close the issue.

## Notes

- Keep local rehearsal details in `references/LOCAL_REHEARSAL.md`; load it only when explicitly requested.
- Prefer `link-pr` for PR/status updates so row normalization and lane sync rules stay consistent.
- `Execution Mode` controls branch/worktree uniqueness checks: only `pr-isolated` requires unique branch/worktree per row.
- Use `--dry-run` to suppress write operations while previewing commands.
- Use a single `ISSUE_NUMBER` variable across the run to avoid cross-issue updates.
