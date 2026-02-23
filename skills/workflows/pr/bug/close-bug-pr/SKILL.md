---
name: close-bug-pr
description: Merge and close a bug PR with gh after a quick PR hygiene review (title, required sections, testing notes) aligned with create-bug-pr. Use when the user asks to merge/close a bug PR, delete the remote branch, and do post-merge cleanup.
---

# Close Bug PR

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Working tree clean (`git status --porcelain=v1` is empty).

Inputs:

- PR number (or current-branch PR).
- Optional: whether to skip checks (`--skip-checks`).

Outputs:

- PR merged (default merge commit) and remote branch deleted.
- Local checkout switched back to base branch and updated; local bugfix branch deleted (best-effort).

Exit codes:

- `0`: success
- non-zero: checks failing, PR not mergeable, auth issues, or git/gh command failures

Failure modes:

- PR is draft and automatic `gh pr ready` fails.
- Required checks failing or branch not mergeable.
- Missing `gh` auth or insufficient permissions.

## Setup

- Ensure `gh auth status` succeeds.

## When to use

- The user asks to merge/close a PR and clean up the bugfix branch.

## Workflow

1. Identify the PR number
   - Prefer current branch PR: `gh pr view --json number -q .number`
2. Preflight
   - Ensure working tree is clean: `git status --porcelain=v1` should be empty
   - Ensure checks pass: `gh pr checks <pr>`
   - Ensure PR is not draft: `gh pr view <pr> --json isDraft -q .isDraft` should be `false`; if `true`, run `gh pr ready <pr>` automatically, then continue to merge.
3. Review PR hygiene (aligned with `create-bug-pr`)
   - Title reflects bug-fix outcome; capitalize the first word.
   - PR body includes: `Summary`, `Problem`, `Reproduction`, `Issues Found`, `Fix Approach`, `Testing`, `Risk / Notes`.
   - If PR body includes `Open Questions` and/or `Next Steps` and they are not already `- None`, update them to the latest status (resolve questions or confirm with the user, check off completed steps, link follow-ups).
   - `Testing` records results (`pass/failed/skipped`) and reasons if not run.
   - If edits are needed: use `gh pr edit <pr> --title ...` / `gh pr edit <pr> --body-file ...`.
4. Merge and delete branch
   - Default merge method: merge commit
   - `gh pr merge <pr> --merge --delete-branch`
5. Local cleanup
   - Resolve refs:
     - `baseRefName="$(gh pr view <pr> --json baseRefName -q .baseRefName)"`
     - `headRefName="$(gh pr view <pr> --json headRefName -q .headRefName)"`
   - `git switch "$baseRefName" && git pull --ff-only`
   - Delete local bugfix branch if it still exists: `git branch -d "$headRefName"`

## Optional helper script

- Use `$AGENT_HOME/skills/workflows/pr/bug/close-bug-pr/scripts/close_bug_pr.sh` in this skill folder to run a deterministic merge + cleanup.
- If `$AGENT_HOME/skills/workflows/pr/bug/close-bug-pr/scripts/close_bug_pr.sh` fails, attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
