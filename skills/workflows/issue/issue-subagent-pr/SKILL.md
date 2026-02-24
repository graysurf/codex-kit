---
name: issue-subagent-pr
description: Subagent workflow for isolated worktree implementation, draft PR creation, and review-response updates linked back to the owning issue.
---

# Issue Subagent PR

Subagents implement only in dedicated worktrees, open/update PRs, and mirror key updates back to the owning issue.

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Worktree branch strategy defined by the main agent.

Inputs:

- Issue number and subagent task scope.
- Branch/base/worktree naming inputs.
- PR title/body metadata and optional review-comment URL for follow-up updates.

Outputs:

- Dedicated worktree path for the task.
- Parameterized subagent task prompt rendered from assigned execution facts (issue/task/owner/branch/worktree/execution mode).
- Draft PR URL for the implementation branch.
- Automatic writeback of `Task Decomposition.PR` (and related sprint comment table rows) for tasks matched by the opened PR head branch / shared `pr-group`.
- PR body validation gate that rejects unfilled templates/placeholders before PR open.
- PR follow-up comments referencing main-agent review comment URLs.
- Optional mirrored issue comments for traceability.

Exit codes:

- `0`: success
- non-zero: invalid args, missing repo context, or `git`/`gh` failures

Failure modes:

- Missing required flags (`--branch`, `--issue`, `--title`, `--review-comment-url`).
- Worktree path collision.
- PR body source conflicts (`--body` and `--body-file`).
- Missing/empty PR body for `open-pr`.
- Placeholder/template PR body content (`TBD`, `TODO`, `<...>`, `#<number>`, stub testing lines).
- Invalid subagent prompt render inputs (placeholder `Owner/Branch/Worktree`, invalid `Execution Mode`, non-subagent owner).
- `gh` auth/permissions insufficient to open or comment on PRs.

## Entrypoint

- `$AGENT_HOME/skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh`

## Core usage

1. Create isolated worktree:
   - `.../manage_issue_subagent_pr.sh create-worktree --branch feat/issue-123-api --base main`
2. Render a subagent task prompt from assigned task facts (recommended before implementation handoff):
   - `.../manage_issue_subagent_pr.sh render-task-prompt --issue 123 --task-id T1 --summary "Implement API task" --owner subagent-api --branch issue/123/t1-api --worktree .worktrees/issue/123-t1-api --execution-mode per-task --pr-title "feat(issue): implement API task"`
3. Open draft PR and sync PR URL to issue:
   - `cp references/PR_BODY_TEMPLATE.md /tmp/pr-123.md && <edit file>`
   - `.../manage_issue_subagent_pr.sh open-pr --issue 123 --title "feat: api task" --body-file /tmp/pr-123.md`
4. Validate PR body before submitting (optional explicit precheck):
   - `.../manage_issue_subagent_pr.sh validate-pr-body --issue 123 --body-file /tmp/pr-123.md`
5. Respond to main-agent review comment with explicit link:
   - `.../manage_issue_subagent_pr.sh respond-review --pr 456 --review-comment-url <url> --body-file references/REVIEW_RESPONSE_TEMPLATE.md --issue 123`

## References

- PR body template: `references/PR_BODY_TEMPLATE.md`
- Review response template: `references/REVIEW_RESPONSE_TEMPLATE.md`
- Subagent task prompt template: `references/SUBAGENT_TASK_PROMPT_TEMPLATE.md`

## Notes

- Use `--dry-run` in orchestration/testing contexts.
- `open-pr` now syncs the issue task table PR references using canonical `#<number>` format and marks matched `planned` rows as `in-progress`.
- `render-task-prompt` is intended to freeze real execution facts (`Owner/Branch/Worktree/Execution Mode/PR title`) into a reusable subagent handoff prompt and reduce manual dispatch mistakes.
- `open-pr --use-template` is not a substitute for filling the PR body; subagent must submit a fully edited body that passes validation.
- Keep implementation details and evidence in PR comments; issue comments should summarize status and link back to PR artifacts.
- Subagents own implementation execution; main-agent does not implement issue task code directly.
- Even when an issue has a single implementation PR, that PR remains subagent-owned.
