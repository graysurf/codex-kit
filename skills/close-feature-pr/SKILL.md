---
name: close-feature-pr
description: Merge and close a feature PR with gh after a quick PR hygiene review (title, required sections, testing notes) aligned with create-feature-pr. Use when the user asks to merge/close a feature PR, delete the remote branch, and do post-merge cleanup.
---

# Close Feature PR

## Setup

- Requires `gh` CLI authenticated with the target repo
- Requires `git`
- Load local helper commands (optional): `source ~/.codex/tools/_codex-tools.zsh`

## When to use

- The user asks to merge/close a PR and clean up the feature branch.

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

- Use `scripts/close_feature_pr.sh` in this skill folder to run a deterministic merge + cleanup.
- If `scripts/close_feature_pr.sh` fails, attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
