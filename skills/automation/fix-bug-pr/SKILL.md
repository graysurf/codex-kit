---
name: fix-bug-pr
description: Find bug-type PRs with unresolved bug items (Issues Found table), fix and push updates, comment with what changed, and keep PR body status synced (set to fixed when complete).
---

# Fix Bug PR

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- `python3` available on `PATH` (helper scripts parse/patch PR Markdown deterministically).
- Start from a clean working tree (avoid staging unrelated local changes).

Inputs:

- Optional PR number to operate on; otherwise resolve an open bug-type PR automatically.
- Optional label filters to narrow candidate PRs (defaults: `bug`, `type: bug`).

Outputs:

- If a matching PR exists:
  - Code fix committed and pushed to the PR head branch.
  - PR comment describing what changed, tests run, and which bug IDs were updated.
  - PR body updated so the Issues Found table reflects latest bug Status; if all bugs are fixed, set overall `Status: fixed`.
- If no bug-type PR exists (or none with unresolved bugs): no repo changes; report “no related issues”.

Exit codes:

- N/A (workflow skill). Helper scripts define their own exit codes.

Failure modes:

- No matching bug-type PR found, or PR body does not include a parseable `## Issues Found` table.
- Missing tooling (`gh`/`git`/`python3`) or `gh` not authenticated.
- Dirty working tree, merge conflicts, or failing tests prevent a safe push.
- High-risk areas (auth/billing/migrations/deploy) should stop or be skipped.

## Workflow

1. Resolve the target PR:
   - Auto-pick an open PR with unresolved bug items:
     - `$CODEX_HOME/skills/automation/fix-bug-pr/scripts/bug-pr-resolve.sh`
   - Or target a specific PR:
     - `$CODEX_HOME/skills/automation/fix-bug-pr/scripts/bug-pr-resolve.sh --pr <number>`
   - If it exits `2`: stop and report “沒有相關問題/沒有 bug 類型 PR”.

2. Checkout the PR branch:
   - `gh pr checkout <number>`

3. Identify the next unresolved bug item:
   - Use `next_bug_id` from `bug-pr-resolve.sh` output.
   - Fix **one** bug item per run unless multiple items share the same root cause.

4. Implement the minimal fix + validation:
   - Prefer small, targeted diffs; avoid refactors.
   - Run the most relevant checks (`scripts/check.sh --lint`, `scripts/test.sh`, etc.) when available.

5. Commit + push:
   - Use `semantic-commit-autostage` (end-to-end automation) unless the user explicitly wants manual staging.
   - Push to the PR head branch.

6. Update PR body progress (status sync):
   - Mark the fixed bug ID(s) as `fixed` and recompute overall status:
     - `$CODEX_HOME/skills/automation/fix-bug-pr/scripts/bug-pr-patch.sh --pr <number> --mark-fixed <bug_id>`
   - If all bug items are fixed, the PR body will be updated to `Status: fixed`.

7. Comment on the PR with what changed:
   - Include: fixed bug IDs, summary, tests run, and any remaining open items.
   - Use `skills/automation/fix-bug-pr/references/COMMENT_TEMPLATE.md` as the structure.
