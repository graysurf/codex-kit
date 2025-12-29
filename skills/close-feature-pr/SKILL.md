---
name: close-feature-pr
description: Merge and close a feature PR with gh, archive the progress file, and update PR links to point to the base branch (e.g. main) after branch deletion.
---

# Close Feature PR

## Setup

- Requires `gh` CLI authenticated with the target repo
- Load local helper commands (optional): `source ~/.codex/tools/_codex-tools.zsh`

## When to use

- The user asks to merge/close a PR, clean up the feature branch, and finalize the progress file.

## Key rule: Progress links must survive branch deletion

GitHub often deletes the feature branch after merge. Any PR body link like:

- `https://github.com/<owner>/<repo>/blob/<feature-branch>/docs/progress/...`

will break.

After merge, update links under `## Progress` to point to the base branch (usually `main`):

- Example:
  - `[docs/progress/archived/<file>.md](https://github.com/<owner>/<repo>/blob/main/docs/progress/archived/<file>.md)`

## Workflow

1. Identify the PR number
   - Prefer current branch PR: `gh pr view --json number -q .number`
2. Preflight
   - Ensure working tree is clean: `git status --porcelain=v1` should be empty
   - Ensure checks pass: `gh pr checks <pr>`
3. Finalize progress
   - Locate the progress file by searching for the PR URL inside `docs/progress/`:
     - `pr_url="$(gh pr view <pr> --json url -q .url)"`
     - `rg -n --fixed-string "$pr_url" docs/progress -S`
   - If it’s still under `docs/progress/`, set Status to `DONE`, move it to `docs/progress/archived/`, and update `docs/progress/README.md` index.
   - Commit and push these changes to the PR branch.
4. Merge and delete branch
   - Default merge method: merge commit
   - `gh pr merge <pr> --merge --delete-branch`
5. Post-merge: patch PR body links to base branch
   - Get base branch: `gh pr view <pr> --json baseRefName -q .baseRefName`
   - Update the `## Progress` link(s) to:
     - `https://github.com/<owner>/<repo>/blob/<baseRefName>/docs/progress/archived/<file>.md`
   - `gh pr edit <pr> --body-file <file>`
6. Local cleanup
   - `git switch <baseRefName> && git pull --ff-only`
   - Delete local feature branch if it still exists: `git branch -d <headRefName>`

## Optional helper script

- Use `scripts/close_feature_pr.sh` in this skill folder to run a deterministic version of steps 3–5.
- If `scripts/close_feature_pr.sh` fails, you must attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
