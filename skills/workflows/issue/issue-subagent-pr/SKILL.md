---
name: issue-subagent-pr
description: Subagent workflow for isolated worktree implementation, draft PR creation, and review-response updates linked back to the owning issue.
---

# Issue Subagent PR

Subagent owns implementation execution in assigned branches/worktrees and keeps PR/issue artifacts synchronized.

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Worktree/branch ownership assigned by main-agent (or the issue Task Decomposition table when using `plan-issue` flows).

Inputs:

- Issue number, task ID/scope, and assigned owner/branch/worktree facts.
- Base branch, PR title, and PR body markdown file path.
- Optional review comment URL + response body markdown for follow-up comments.
- Optional repository override (`owner/repo`) for `gh` commands when not running in the default remote context.

Outputs:

- Dedicated task worktree checked out to the assigned branch.
- Draft PR URL for the implementation branch.
- PR/body validation evidence (required sections present; placeholders removed).
- Review response comments on the PR that reference the main-agent review comment URL.
- Optional issue sync comments (`gh issue comment`) that mirror task status and PR linkage.
- `plan-issue` artifact compatibility: canonical issue/PR references (`#<number>`) suitable for Task Decomposition sync.

Exit codes:

- `0`: success
- non-zero: invalid inputs, failed validation checks, repo context issues, or `git`/`gh` failures

Failure modes:

- Missing assigned execution facts (issue/task/owner/branch/worktree).
- Worktree path collision or branch already bound to another worktree.
- Empty PR body file or unresolved template placeholders (`TBD`, `TODO`, `<...>`, `#<number>`, template stub lines).
- Missing required PR body sections (`## Summary`, `## Scope`, `## Testing`, `## Issue`).
- `gh` auth/permission failures for PR/issue reads or writes.

## Command Contract (Scriptless)

- Use native `git` for worktree and branch lifecycle.
- Use native `gh` for draft PR creation and PR/issue comments.
- Use `rg`-based checks (or equivalent) for PR body section/placeholder validation before PR open and before final review updates.

## Core usage

1. Create isolated worktree/branch with `git worktree`:
   - ```bash
     ISSUE=123
     TASK_ID=T1
     BASE=main
     BRANCH="issue/${ISSUE}/${TASK_ID}-api"
     WORKTREE=".worktrees/issue-${ISSUE}-${TASK_ID}-api"

     git fetch origin --prune
     git worktree add -b "$BRANCH" "$WORKTREE" "origin/$BASE"
     cd "$WORKTREE"
     git branch --show-current
     git worktree list
     ```
2. Prepare and validate PR body (required sections + placeholder checks):
   - ```bash
     BODY_FILE="$WORKTREE/.tmp/pr-${ISSUE}-${TASK_ID}.md"
     mkdir -p "$(dirname "$BODY_FILE")"
     cp /Users/terry/.config/agent-kit/skills/workflows/issue/issue-subagent-pr/references/PR_BODY_TEMPLATE.md "$BODY_FILE"
     # Edit BODY_FILE and replace all template placeholders before continuing.

     for section in "## Summary" "## Scope" "## Testing" "## Issue"; do
       rg -q "^${section}$" "$BODY_FILE" || { echo "Missing section: ${section}" >&2; exit 1; }
     done

     rg -n 'TBD|TODO|<[^>]+>|#<number>|<implemented scope>|<explicitly excluded scope>|<command> \\(pass\\)|not run \\(reason\\)' "$BODY_FILE" \
       && { echo "Placeholder content found in PR body" >&2; exit 1; } || true
     ```
3. Open draft PR with `gh pr create`:
   - ```bash
     gh pr create \
       --draft \
       --base "$BASE" \
       --head "$BRANCH" \
       --title "feat(issue-${ISSUE}): implement ${TASK_ID} API changes" \
       --body-file "$BODY_FILE"

     PR_NUMBER="$(gh pr view --json number --jq '.number')"
     PR_URL="$(gh pr view --json url --jq '.url')"
     echo "Opened ${PR_URL}"
     ```
4. Post review response comment with `gh pr comment`:
   - ```bash
     REVIEW_COMMENT_URL="https://github.com/<owner>/<repo>/pull/<pr>#issuecomment-<id>"
     RESPONSE_FILE="$WORKTREE/.tmp/review-response-${PR_NUMBER}.md"
     cp /Users/terry/.config/agent-kit/skills/workflows/issue/issue-subagent-pr/references/REVIEW_RESPONSE_TEMPLATE.md "$RESPONSE_FILE"
     # Edit RESPONSE_FILE: include REVIEW_COMMENT_URL and concrete change/testing notes.

     gh pr comment "$PR_NUMBER" --body-file "$RESPONSE_FILE"
     ```
5. Optional issue sync comment with `gh issue comment` (traceability):
   - ```bash
     gh issue comment "$ISSUE" \
       --body "Task ${TASK_ID} in progress by subagent. Branch: \`${BRANCH}\`. Worktree: \`${WORKTREE}\`. PR: #${PR_NUMBER}. Review response: ${REVIEW_COMMENT_URL}"
     ```
6. Optional plan-issue artifact sync note:
   - Keep Task Decomposition row fields (`Owner`, `Branch`, `Worktree`, `Execution Mode`, `PR`) aligned with actual execution facts; use canonical PR references like `#${PR_NUMBER}` so `plan-issue status-plan` / `ready-plan` snapshots remain consistent.

## References

- PR body template: `references/PR_BODY_TEMPLATE.md`
- Review response template: `references/REVIEW_RESPONSE_TEMPLATE.md`
- Subagent task prompt template: `references/SUBAGENT_TASK_PROMPT_TEMPLATE.md`

## Notes

- Subagent may pre-fill `references/SUBAGENT_TASK_PROMPT_TEMPLATE.md` from assigned execution facts to avoid owner/branch/worktree drift during implementation.
- Treat PR body validation as a required gate, not an optional cleanup step.
- Keep implementation details and evidence in PR comments; issue comments should summarize status and link back to PR artifacts.
- Subagent owns implementation execution; main-agent remains orchestration/review-only.
- Even for single-PR issues, implementation PR authorship/ownership stays with subagent.
