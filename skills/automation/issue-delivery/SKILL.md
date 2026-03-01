---
name: issue-delivery
description:
  "Orchestrate plan-issue review/close loops where main-agent owns orchestration and review only, subagents own implementation task lanes,
  and close gates require approval plus merged PRs."
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
  - sprint-scoped `SUBAGENT_INIT_SNAPSHOT_PATH`
  - issue-scoped `PLAN_SNAPSHOT_PATH`
  - task-scoped `DISPATCH_RECORD_PATH`
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
- Subagent-owned task lanes stay stable across implementation, clarification, CI, and review follow-up unless main-agent explicitly
  reassigns the lane.

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
- Plan-sprint originated dispatch launched without required bundle (`TASK_PROMPT_PATH`, `SUBAGENT_INIT_SNAPSHOT_PATH`,
  `PLAN_SNAPSHOT_PATH`, `DISPATCH_RECORD_PATH`, plan task snippet/link/path).
- Review or clarification follow-up is redirected into a replacement branch/worktree/PR without explicit task-lane reassignment.

## Role Boundary (Mandatory)

- Main-agent is limited to issue orchestration:
  - status/review-handoff/close gates
  - dispatch and acceptance decisions
- Main-agent must not implement issue tasks directly.
- Even for a single-PR issue, implementation must be produced by a subagent PR and then reviewed by main-agent.
- Main-agent review/merge decisions should use `issue-pr-review`; this loop skill enforces ownership and close gates.

## Task Lane Continuity (Mandatory)

- Follow the shared task-lane continuity policy:
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Treat each `Task Decomposition` row as one task lane and keep follow-up on
  that lane by default.
- Replacement dispatch is allowed only when the original subagent cannot
  continue or when assignment facts must change; preserve issue row and PR
  linkage deterministically when reassigning.

## References

- Local rehearsal playbook (`plan-issue-local` and `plan-issue --dry-run`): `references/LOCAL_REHEARSAL.md`
- Shared task-lane continuity policy (canonical):
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Shared main-agent review rubric (canonical):
  `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
- Shared post-review outcome handling (canonical):
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`

## Core usage

1. Live mode is default in this main skill: `plan-issue <subcommand> ...`.
2. Resolve and reuse a single `ISSUE_NUMBER` from upstream plan orchestration, then dispatch implementation to subagents via
   `issue-subagent-pr`.
   - If the issue originated from `plan-issue start-sprint`, dispatch each subagent with:
     - rendered `TASK_PROMPT_PATH`
     - `SUBAGENT_INIT_SNAPSHOT_PATH`
     - `PLAN_SNAPSHOT_PATH`
     - `DISPATCH_RECORD_PATH`
     - assigned plan task section snippet/link/path
3. Keep runtime-truth rows synchronized with `link-pr`; add `status-plan` checkpoints when needed, and use `blocked` while a task lane is
   waiting on clarification or another external unblock.
4. Handoff review with `ready-plan`, apply the shared main-agent review rubric,
   run review decisions through `issue-pr-review`, and route follow-up back to
   the same subagent-owned task lane until close gates are satisfied.
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
2. Confirm the plan issue already exists, capture `ISSUE_NUMBER` from upstream orchestration output, and keep using that single value for
   all `--issue` flags.
3. Confirm task decomposition ownership remains subagent-only.
4. Main-agent dispatches implementation tasks to subagents (for example via `issue-subagent-pr`), while remaining orchestration/review-only.
   - For plan-sprint originated issues, dispatch must include the required bundle:
     - rendered `TASK_PROMPT_PATH`
     - `SUBAGENT_INIT_SNAPSHOT_PATH`
     - `PLAN_SNAPSHOT_PATH`
     - `DISPATCH_RECORD_PATH`
     - assigned plan task section snippet/link/path
5. As subagent PRs progress, run `link-pr` to update issue task `PR` and `Status` fields (instead of manual table edits).
   - Task-scoped link:
     `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - `--task` automatically syncs shared-lane rows (`per-sprint` / `pr-shared`) in one operation.
   - Sprint-scoped link is valid only when the target resolves to one runtime lane; otherwise specify `--pr-group`.
   - Use `in-progress` while a lane is actively implementing or addressing requested follow-up.
   - Use `blocked` while a lane is waiting on missing/conflicting context or an external unblock.
6. If a subagent reports missing/conflicting context or another blocker, stop forward progress, clarify the task, and send the work back to
   the same task lane by default instead of widening scope or opening a replacement PR path.
7. Run `status-plan` to generate a main-agent snapshot comment for task/PR/review state checkpoints.
8. Run `ready-plan` when the issue is ready for main-agent review handoff.
9. Main-agent reviews subagent PRs against
   `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
   (typically using `issue-pr-review`), requests follow-up back to the current
   subagent-owned task lane or merges until close gates are satisfied.
10. After each review decision, apply
    `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md` to keep
    issue/task state synchronized before any further dispatch or final close
    gate work.
11. Run `close-plan` with `PLAN_APPROVED_COMMENT_URL` to enforce final gates
    (task status plus merged PR checks), re-sync/normalize the issue task
    table, and close the issue.

## Notes

- Keep local rehearsal details in `references/LOCAL_REHEARSAL.md`; load it only when explicitly requested.
- Prefer `link-pr` for PR/status updates so row normalization and lane sync rules stay consistent.
- `Execution Mode` controls branch/worktree uniqueness checks: only `pr-isolated` requires unique branch/worktree per row.
- Use `--dry-run` to suppress write operations while previewing commands.
- Use a single `ISSUE_NUMBER` variable across the run to avoid cross-issue updates.
- If the original subagent cannot continue, reassign explicitly and keep the
  new subagent on the same task-lane facts unless the issue row is
  intentionally updated first.
- After `request-followup` or `close-pr`, do not continue orchestration from a
  stale row; apply the shared post-review outcome handling first.
- For `issue-pr-review`, prefer structured outcome flags (`request-followup`:
  `--row-status`, `--next-owner`; `close-pr`: `--close-reason`,
  `--next-action`, optional `--replacement-pr`, `--row-status`) so row sync
  comments are deterministic.
