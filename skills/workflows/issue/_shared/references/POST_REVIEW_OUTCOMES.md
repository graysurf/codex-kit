# Post-Review Outcomes

Purpose: canonical handling for main-agent actions after a review decision is
made.

Applies to:

- `skills/workflows/issue/issue-pr-review`
- `skills/automation/issue-delivery`
- `skills/automation/plan-issue-delivery`
- `skills/workflows/issue/issue-lifecycle`
- plan-issue main-agent init prompt

## Core Rule

- GitHub-side review actions and runtime-truth row sync are both required.
- Do not leave the review result only in PR comments.
- After every `merge`, `request-followup`, or `close-pr` decision, sync the
  issue/task state before more dispatch, acceptance, or close-gate work.

## Request-Followup

- Use `issue-pr-review request-followup`.
- Keep the current task lane active.
- Mirror the exact PR comment URL into the issue timeline.
- When using `issue-pr-review`, keep the auto-generated issue headline and pass
  row-state details either through structured follow-up flags
  (`--row-status`, `--next-owner`, optional `--lane-action`,
  `--requested-by`) or through `--issue-note-file` using
  `skills/workflows/issue/issue-pr-review/references/ISSUE_SYNC_TEMPLATE.md`
  as the canonical fallback shape.
- Sync the task row immediately:
  - keep the same PR reference
  - use `in-progress` if the assigned subagent can continue immediately
  - use `blocked` if the lane is waiting on missing/conflicting context or
    another external unblock
- Do not open a replacement branch/worktree/PR for ordinary follow-up.
- Next step remains on the same assigned lane.

## Close-PR

### Without replacement

- Use `issue-pr-review close-pr`.
- Treat the current lane as retired immediately after the close decision.
- Pass issue-side traceability through structured close outcome flags
  (`--close-reason`, optional `--replacement-pr`, `--row-status`,
  `--next-action`) or through `--issue-comment-file` using
  `skills/workflows/issue/issue-pr-review/references/CLOSE_PR_ISSUE_SYNC_TEMPLATE.md`
  as the canonical fallback shape.
- Add issue-side traceability that states:
  - closed PR reference
  - reason for closing
  - `replacement pending`
  - `row status = blocked`
  - `do not resume the closed lane`
  - explicit next unblock action
- Sync the task row immediately:
  - use `blocked`
  - keep the last closed PR reference for traceability until a replacement lane
    exists
- Do not dispatch another subagent from the retired lane.

### With replacement

- Use `issue-pr-review close-pr` on the retired PR.
- Pass issue-side traceability through structured close outcome flags or
  `--issue-comment-file` using
  `skills/workflows/issue/issue-pr-review/references/CLOSE_PR_ISSUE_SYNC_TEMPLATE.md`
  so the issue timeline records both retirement and replacement.
- Add issue-side traceability that links the replacement PR/lane.
- Update the authoritative task row to the replacement lane facts before
  resuming implementation.
- Then sync the row against the replacement PR with the correct live status
  (`in-progress` or `done`).
- Do not resume the retired lane after replacement is declared.

## Merge

- Use `issue-pr-review merge`.
- Keep the merged PR as the canonical PR reference for the task row.
- Let the owning acceptance gate (`accept-sprint`, `close-plan`, or equivalent)
  advance status to `done`; do not invent an earlier done-state transition that
  conflicts with the active workflow gate.

## Sync Guidance

- In `plan-issue` flows, use `link-pr` immediately after the review decision to
  keep `PR` and `Status` aligned with the chosen outcome.
- Outside `plan-issue` flows, use the issue lifecycle/body sync path to mirror
  the same semantics.
- If a lane is retired, future dispatch is blocked until the authoritative row
  has either been updated to a replacement lane or explicitly unblocked by
  main-agent.
