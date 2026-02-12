---
name: close-feature-pr
description: Merge and close a feature PR with gh after a quick PR hygiene review (title, required sections, testing notes) aligned with create-feature-pr. Use when the user asks to merge/close a feature PR, delete the remote branch, and do post-merge cleanup.
---

# Close Feature PR

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Working tree clean (`git status --porcelain=v1` is empty).

Inputs:

- PR number (or current-branch PR).
- Optional: merge readiness decisions (draft → ready; checks pass).

Outputs:

- PR merged (default merge commit) and remote branch deleted.
- Local checkout switched back to base branch and updated; local feature branch deleted (best-effort).

Exit codes:

- `0`: success
- non-zero: checks failing, PR not mergeable, auth issues, or git/gh command failures

Failure modes:

- PR is draft (must confirm and mark ready first).
- Required checks failing or branch not mergeable.
- Missing `gh` auth or insufficient permissions.

## Setup

- Ensure `gh auth status` succeeds.

## When to use

- The user asks to merge/close a PR and clean up the feature branch.
- If the PR is tracked by a progress file (PR body links to `docs/progress/...`) and you want to finalize/archive that progress, use `close-progress-pr` instead.

## Workflow

1. Identify the PR number
   - Prefer current branch PR: `gh pr view --json number -q .number`
2. Preflight
   - Ensure working tree is clean: `git status --porcelain=v1` should be empty
   - Ensure checks pass: `gh pr checks <pr>`
   - Ensure PR is not draft: `gh pr view <pr> --json isDraft -q .isDraft` should be `false` (if `true`, confirm with the user then run `gh pr ready <pr>`)
3. Review PR hygiene (aligned with `create-feature-pr`)
   - Title reflects feature outcome; capitalize the first word.
   - PR body includes: `Summary`, `Changes`, `Testing`, `Risk / Notes`.
   - `## Progress`/`## Planning PR` are progress-derived metadata and must be treated as a pair.
   - Non-progress feature PR: both sections should be absent.
   - Progress-derived feature PR: both sections must exist with non-empty values.
   - If only one section exists, or either section is `None` (or empty), remove both sections entirely.
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
   - Delete local feature branch if it still exists: `git branch -d "$headRefName"`

## Optional helper script

- Use `$CODEX_HOME/skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh` in this skill folder to run a deterministic merge + cleanup.
- If `$CODEX_HOME/skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh` fails, attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
