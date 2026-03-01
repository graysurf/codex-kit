---
name: issue-pr-review
description:
  Main-agent PR review workflow that enforces explicit PR comment links, routes follow-up back to subagent-owned task lanes, mirrors
  decisions to the issue timeline, and controls merge/close outcomes.
---

# Issue PR Review

Main agent reviews subagent-owned PR lanes, requests changes via PR comments, links those comments back to issues, and decides merge/close
actions.

## Contract

Prereqs:

- Run inside the target git repo.
- `gh` available on `PATH`, and `gh auth status` succeeds.
- Target PR and related issue numbers are known.

Inputs:

- PR number and related issue number.
- Review feedback body (inline or file).
- Merge/close strategy (`merge|squash|rebase`, optional issue close metadata).
- Optional corrected PR body (`--pr-body` / `--pr-body-file`) for hygiene fixes before merge/close.

Outputs:

- PR review comments with explicit follow-up requirements.
- Follow-up requests routed back to the current subagent-owned task lane.
- Main-agent review decisions grounded in the shared review rubric before any
  follow-up, merge, or close action.
- Issue timeline comments containing the exact PR comment URL.
- Merged or closed PR state, with optional issue close/update actions.
- PR body hygiene re-check before merge/close, with optional automatic correction via `gh pr edit`.
- Post-review outcome handling requirements available for runtime-truth row sync
  after `request-followup`, `merge`, or `close-pr`.

Exit codes:

- `0`: success
- non-zero: missing required flags, invalid method/reason values, or `gh` command failures

Failure modes:

- Missing required identifiers (`--pr`, `--issue` for follow-up sync).
- Ambiguous comment input (`--body` and `--body-file`).
- Invalid merge method or issue close reason.
- PR body fails required-section/placeholder validation before merge/close.
- `gh` auth/permission failures for PR/issue operations.

## Entrypoint

- `$AGENT_HOME/skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh`

## Follow-Up Routing (Mandatory)

- Follow the shared task-lane continuity policy:
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Treat review follow-up as continuation on the current subagent-owned task
  lane, not as permission to start a replacement lane.
- Default follow-up target is the subagent that already owns the task
  branch/worktree/PR for the related issue row.
- If the original subagent cannot continue, main-agent may reassign the lane,
  but the replacement must preserve task execution facts and the exact PR
  comment URL that triggered follow-up.
- Main-agent review comments must not ask main-agent to implement product-code changes directly.

## Review Method (Mandatory)

- Follow the shared main-agent review rubric:
  `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
- Run hard-gate, task-fidelity, correctness, and integration review before
  deciding `request-followup`, `merge`, or `close-pr`.
- Treat `issue-pr-review` as the execution path for review decisions, not as a
  replacement for reviewer judgment.

## Post-Review Outcome Handling (Mandatory)

- Follow the shared post-review outcome rules:
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`
- `issue-pr-review` executes the GitHub-side review action; main-agent must also
  sync runtime-truth task state after each outcome.
- `request-followup` keeps the lane active and must be followed by row sync to
  `in-progress` or `blocked`.
- For `request-followup`, keep the script-generated issue headline and append
  row-state details using structured flags (`--row-status`, `--next-owner`,
  optional `--lane-action`, `--requested-by`) or `--issue-note-file` with
  `references/ISSUE_SYNC_TEMPLATE.md` as the canonical note shape.
- `close-pr` retires the lane and must be followed by issue-side traceability
  plus either replacement-lane sync or `blocked` state.
- For `close-pr`, prefer structured close outcome flags (`--close-reason`,
  optional `--replacement-pr`, `--row-status`, `--next-action`) or
  `--issue-comment-file` from
  `references/CLOSE_PR_ISSUE_SYNC_TEMPLATE.md`.

## Core usage

1. Request follow-up from subagent and sync explicit PR comment link to issue:

   ```bash
   .../manage_issue_pr_review.sh request-followup --pr 456 --issue 123 \
     --body-file references/REQUEST_CHANGES_TEMPLATE.md \
     --row-status in-progress \
     --next-owner subagent-1
   ```

2. Merge PR and close issue when complete:
   - `.../manage_issue_pr_review.sh merge --pr 456 --method merge --issue 123 --close-issue --issue-comment "Completed in #456"`
   - If PR body is stale/placeholder-filled, provide a corrected body:
   - `.../manage_issue_pr_review.sh merge --pr 456 --issue 123 --pr-body-file /tmp/pr-456-fixed.md --method squash`
3. Close PR without merge and preserve issue traceability:

   ```bash
   .../manage_issue_pr_review.sh close-pr --pr 456 --comment "Superseded" --issue 123 \
     --close-reason "Superseded by #789" \
     --replacement-pr "#789" \
     --row-status in-progress \
     --next-action "Continue implementation on PR #789"
   ```

## References

- Request changes template: `references/REQUEST_CHANGES_TEMPLATE.md`
- Follow-up issue-note template (`--issue-note-file`): `references/ISSUE_SYNC_TEMPLATE.md`
- Close-PR issue sync template (`--issue-comment-file`): `references/CLOSE_PR_ISSUE_SYNC_TEMPLATE.md`
- Shared task-lane continuity policy (canonical):
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Shared main-agent review rubric (canonical):
  `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
- Shared post-review outcome handling (canonical):
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`

## Notes

- Important review instructions should remain in PR comments; always mirror the exact comment URL into the issue to direct subagents
  unambiguously.
- `request-followup` already generates the issue headline with the PR comment
  URL; use structured follow-up flags by default, or
  `references/ISSUE_SYNC_TEMPLATE.md` for `--issue-note-file` fields without
  duplicating the headline.
- A review request is not a new implementation lane by itself; by default it returns to the existing subagent-owned branch/worktree/PR.
- Use `--dry-run` in workflow simulations before touching live GitHub state.
- Before `merge`/`close-pr`, main-agent runs internal/self-contained PR body hygiene validation (required headings, placeholder rejection,
  issue bullet check) and must correct invalid content.
- Main-agent performs review/acceptance only; implementation changes belong to subagent-owned task branches/PRs.
- This skill is the canonical path for main-agent review decisions in issue-delivery loops.
