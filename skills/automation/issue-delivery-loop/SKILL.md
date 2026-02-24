---
name: issue-delivery-loop
description: "Orchestrate end-to-end issue execution loops where main-agent owns issue flow/review only, subagents own implementation PRs, and close gates require approval + merged PRs."
---

# Issue Delivery Loop

## Contract

Prereqs:

- Run inside (or have access to) the target repository.
- `gh` available on `PATH`, and `gh auth status` succeeds for issue/PR reads and writes.
- Base workflow scripts exist:
  - `$AGENT_HOME/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh`

Inputs:

- Main-agent issue metadata (`title`, optional body/labels/assignees/milestone).
- Optional task decomposition TSV for bootstrap comments.
- Optional review summary text.
- Approval comment URL (`https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`) when closing.
- Task owners must be subagent identities (must reference `subagent`); `main-agent` ownership is invalid for implementation tasks.

Outputs:

- Deterministic orchestration over issue lifecycle commands with explicit gate checks.
- Status snapshot and review-request markdown blocks for traceable issue history.
- Issue close only when review approval and merged-PR checks pass.
- Definition of done: execution is complete only when `close-after-review` succeeds and the target issue is actually closed.
- Error contract: if any gate/command fails, stop forward progress and report the failing command plus key stderr/stdout gate errors.
- Main-agent acts as orchestrator/reviewer only; implementation branches/PRs are delegated to subagents.
- Issue task table remains the single execution source of truth (`Subagent PRs` section is legacy and removed by sync).

Exit codes:

- `0`: success
- non-zero: usage errors, missing tools, gh failures, or gate validation failures

Failure modes:

- Missing required options (`--title`, `--issue`, `--approved-comment-url`, etc.).
- Invalid approval URL format or repo mismatch with `--repo`.
- Task rows violate close gates (status not `done`, execution metadata/PR missing, or PR not merged).
- Issue/PR metadata fetch fails via `gh`.
- Task `Owner` is `main-agent`/non-subagent identity in `Task Decomposition`.

## Entrypoint

- `$AGENT_HOME/skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh`

## Role Boundary (Mandatory)

- Main-agent is limited to issue orchestration:
  - open/update/snapshot/review-handoff/close gates
  - dispatch and acceptance decisions
- Main-agent must not implement issue tasks directly.
- Even for a single-PR issue, implementation must be produced by a subagent PR and then reviewed by main-agent.
- Main-agent review/merge decisions should use `issue-pr-review`; this loop skill enforces owner and close gates.

## Core usage

1. Start issue execution:
   - `.../manage_issue_delivery_loop.sh start --repo <owner/repo> --title "<title>" --label issue --task-spec <tasks.tsv>`
2. Dispatch implementation to subagent(s):
   - Use `issue-subagent-pr` workflow to create task worktrees/PRs.
3. Update status snapshot (main-agent checkpoint):
   - `.../manage_issue_delivery_loop.sh status --repo <owner/repo> --issue <number>`
4. Request review (main-agent review handoff):
   - `.../manage_issue_delivery_loop.sh ready-for-review --repo <owner/repo> --issue <number> --summary "<review focus>"`
5. Main-agent review decision:
   - Use `issue-pr-review` to request follow-up or merge after checks/review are satisfied.
6. Close after explicit review approval:
   - `.../manage_issue_delivery_loop.sh close-after-review --repo <owner/repo> --issue <number> --approved-comment-url <url>`

## Completion Policy (Mandatory)

- Do not stop at `start`, `status`, or `ready-for-review` as a final state.
- A successful run must terminate at `close-after-review` with issue state `CLOSED`.
- If close gates fail, treat the run as unfinished and report:
  - failing command
  - gate errors (task status, PR merge, approval URL, or owner policy)
  - next required unblock action

## Full Skill Flow

1. Confirm repository context and `gh auth status` are valid.
2. Prepare issue metadata (title/body/labels) and optional task decomposition TSV (`Owner` must be subagent identities).
3. Run `start` to open the issue and optionally bootstrap `Task Decomposition` from the TSV.
4. Main-agent dispatches implementation tasks to subagents (for example via `issue-subagent-pr`), while remaining orchestration/review-only.
5. As subagent PRs progress, update the issue task table and PR links so task state stays consistent.
   - Fill real `Owner` / `Branch` / `Worktree` / `Execution Mode` / `PR` values as execution happens (initial `TBD` rows are expected).
   - Use canonical PR references as `#<number>` for tables/comments.
6. Run `status` to generate a main-agent snapshot comment for task/PR/review state checkpoints.
7. Run `ready-for-review` when the issue is ready for main-agent review handoff (adds review comment/labels as configured).
8. Main-agent reviews subagent PRs (typically with `issue-pr-review`), requests follow-up or merges until close gates are satisfied.
9. Run `close-after-review` with an explicit approval comment URL to enforce final gates (task status + merged PR checks), re-sync/normalize the issue task table, and close the issue.

## Notes

- `status` and `ready-for-review` also support `--body-file` for offline/dry-run rendering in tests.
- `close-after-review` supports `--body-file` for offline gate checks; it prints `DRY-RUN-CLOSE-SKIPPED` in body-file mode.
- `Execution Mode` controls branch/worktree uniqueness checks: only `per-task` requires unique branch/worktree per row.
- Use `--dry-run` to suppress write operations while previewing commands.
