---
name: issue-pr-review
description: Main-agent PR review workflow that enforces explicit PR comment links, mirrors decisions to the issue timeline, and controls merge/close outcomes.
---

# Issue PR Review

Main agent reviews subagent PRs, requests changes via PR comments, links those comments back to issues, and decides merge/close actions.

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
- Issue timeline comments containing the exact PR comment URL.
- Merged or closed PR state, with optional issue close/update actions.
- PR body hygiene re-check before merge/close, with optional automatic correction via `gh pr edit`.

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

## Core usage

1. Request follow-up from subagent and sync explicit PR comment link to issue:
   - `.../manage_issue_pr_review.sh request-followup --pr 456 --issue 123 --body-file references/REQUEST_CHANGES_TEMPLATE.md`
2. Merge PR and close issue when complete:
   - `.../manage_issue_pr_review.sh merge --pr 456 --method merge --issue 123 --close-issue --issue-comment "Completed in #456"`
   - If PR body is stale/placeholder-filled, provide a corrected body:
   - `.../manage_issue_pr_review.sh merge --pr 456 --issue 123 --pr-body-file /tmp/pr-456-fixed.md --method squash`
3. Close PR without merge and preserve issue traceability:
   - `.../manage_issue_pr_review.sh close-pr --pr 456 --comment "Superseded" --issue 123 --issue-comment "PR #456 closed, replacement pending"`

## References

- Request changes template: `references/REQUEST_CHANGES_TEMPLATE.md`
- Issue sync template: `references/ISSUE_SYNC_TEMPLATE.md`

## Notes

- Important review instructions should remain in PR comments; always mirror the exact comment URL into the issue to direct subagents unambiguously.
- Use `--dry-run` in workflow simulations before touching live GitHub state.
- Before `merge`/`close-pr`, main-agent re-validates the current PR body using the `issue-subagent-pr` PR-body validator and must correct invalid placeholder content.
- Main-agent performs review/acceptance only; implementation changes belong to subagent-owned task branches/PRs.
- This skill is the canonical path for main-agent review decisions in issue-delivery loops.
