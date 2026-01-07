---
name: close-progress-pr
description: "Finalize and archive a progress file for a GitHub PR: locate the related docs/progress file (prefer PR body Progress link), set Status to DONE, move it to docs/progress/archived/, update docs/progress/README.md, merge the PR with gh, and patch the PR body Progress link to point to the base branch so it survives branch deletion. Use when a feature PR is ready to be closed and its progress tracking should be marked DONE."
---

# Close Progress PR

## Setup

- Requires `gh` CLI authenticated with the target repo
- Load local helper commands (optional): `source $CODEX_TOOLS_PATH/_codex-tools.zsh`

## Key rule: Progress links must survive branch deletion

After merge, GitHub often deletes the head branch. Any PR body link like:

- `https://github.com/<owner>/<repo>/blob/<head-branch>/docs/progress/...`

will break.

Patch the PR body `## Progress` link to point to the base branch (usually `main`) after merge:

- `https://github.com/<owner>/<repo>/blob/<base-branch>/docs/progress/archived/<file>.md`

## Workflow

1. Identify the PR number
   - Prefer current branch PR: `gh pr view --json number -q .number`
2. Preflight
   - Ensure working tree is clean: `git status --porcelain=v1` should be empty
   - Ensure checks pass (optional but recommended): `gh pr checks <pr>`
3. Locate the progress file
   - Prefer parsing the PR body `## Progress` link and extracting `docs/progress/...`
   - If missing, fallback: search by PR URL inside `docs/progress/`:
     - `pr_url="$(gh pr view <pr> --json url -q .url)"`
     - `rg -n --fixed-string "$pr_url" docs/progress -S`
4. Finalize progress
   - Update the progress file:
     - Fail-fast if any unchecked checklist item under `## Steps (Checklist)` lacks a `Reason:` (excluding Step 4 “Release / wrap-up”)
     - Set Status to `DONE`
     - Update the `Updated` date to today
     - Set `Links -> PR` to the PR URL
     - Ensure `Links -> Docs` and `Links -> Glossary` are Markdown links (not backticks) that resolve to existing files
     - If there are no related docs for this PR, set `Links -> Docs` to `None` (do not guess a random file)
   - Move it to `docs/progress/archived/<file>.md` if not already archived
   - Update `docs/progress/README.md` (move row to Archived; set PR link to `[#<number>](<url>)`; best-effort if table format differs)
5. Commit and push these changes to the PR branch
6. Merge and delete branch
   - Default merge method: merge commit
   - `gh pr merge <pr> --merge --delete-branch`
7. Post-merge: patch PR body links to base branch
   - Get base branch: `gh pr view <pr> --json baseRefName -q .baseRefName`
   - Update `## Progress` to:
     - `https://github.com/<owner>/<repo>/blob/<baseRefName>/docs/progress/archived/<file>.md`

## Optional helper script

- Use `scripts/close_progress_pr.sh` in this skill folder to run a deterministic version of steps 3–7.
- If `scripts/close_progress_pr.sh` fails, attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
