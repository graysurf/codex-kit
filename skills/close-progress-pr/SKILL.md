---
name: close-progress-pr
description: "Finalize and archive a progress file for a GitHub PR: locate the related docs/progress file (prefer PR body Progress link), set Status to DONE, move it to docs/progress/archived/, update docs/progress/README.md, merge the PR with gh, patch the PR body Progress link to point to the base branch so it survives branch deletion, and (when present) patch the planning PR body to include an Implementation PR link. Use when a feature PR is ready to be closed and its progress tracking should be marked DONE."
---

# Close Progress PR

## Contract

Prereqs:

- Run inside the target git repo with a clean working tree.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Target PR body contains a `docs/progress/...` link under `## Progress` (preferred; not `None`), or you pass `--progress-file`, or the progress file contains the PR URL.

Inputs:

- PR number (or current-branch PR).
- Optional: progress file under `docs/progress/` referenced by the PR (use `--progress-file` when PR body is missing/ambiguous).

Outputs:

- Progress file finalized (`Status: DONE`), moved to `docs/progress/archived/`, and indexed in `docs/progress/README.md`.
- PR merged (default merge commit) and branch deleted.
- PR body `## Progress` link patched to point to base branch (survives branch deletion).

Exit codes:

- `0`: success
- non-zero: missing progress link/file, validation failures, or git/gh command failures

Failure modes:

- Unchecked checklist items missing `Reason:` (fail-fast).
- Progress file cannot be located or moved (path mismatch, conflicts).
- PR merge blocked (draft/checks failing/permissions).
- PR is not progress-tracked (`## Progress` is `None` or missing); use `close-feature-pr` instead.

## Setup

- Ensure `gh auth status` succeeds.
- Load local helper commands (optional): `source $CODEX_HOME/scripts/codex-tools.sh`

## Key rule: Progress links must survive branch deletion

After merge, GitHub often deletes the head branch. Any PR body link like:

- `https://github.com/<owner>/<repo>/blob/<head-branch>/docs/progress/...`

will break.

Patch the PR body `## Progress` link to point to the base branch (usually `main`) after merge:

- `https://github.com/<owner>/<repo>/blob/<base-branch>/docs/progress/archived/<file>.md`

## Key rule: Planning PRs should link to the implementation PR

If the progress file includes a `Links -> Planning PR` entry, ensure that planning PR body includes an `## Implementation` section linking to the implementation PR (this PR).

## Workflow

1. Identify the PR number
   - Prefer current branch PR: `gh pr view --json number -q .number`
2. Preflight
   - Ensure working tree is clean: `git status --porcelain=v1` should be empty
   - Ensure checks pass (optional but recommended): `gh pr checks <pr>`
   - If PR body includes `Open Questions` and/or `Next Steps` and they are not already `- None`, update them to the latest status before merge (resolve questions or confirm with the user, check off completed steps, link follow-ups).
3. Locate the progress file
   - Prefer parsing the PR body `## Progress` link and extracting `docs/progress/...`
   - If missing, fallback: search by PR URL inside `docs/progress/`:
     - `pr_url="$(gh pr view <pr> --json url -q .url)"`
     - `rg -n --fixed-string "$pr_url" docs/progress -S`
4. Finalize progress
   - Update the progress file:
     - Fail-fast if any unchecked checklist item under `## Steps (Checklist)` lacks a `Reason:` (excluding Step 4 “Release / wrap-up”)
     - For intentionally deferred / not-do items (Steps 0–3), prefer marking the item text with Markdown strikethrough (`~~like this~~`) while keeping the checkbox unchecked, and include an explicit `Reason:`
     - Set Status to `DONE`
     - Update the `Updated` date to today
     - Set `Links -> PR` to the PR URL
     - Ensure `Links -> Docs` and `Links -> Glossary` are Markdown links (not backticks) that resolve to existing files
     - If there are no related docs for this PR, set `Links -> Docs` to `None` (do not guess a random file)
   - Move it to `docs/progress/archived/<file>.md` if not already archived
   - Update `docs/progress/README.md` (move row to Archived; keep Archived sorted newest-first by `Date`; set PR link to `[#<number>](<url>)`; best-effort if table format differs)
5. Commit and push these changes to the PR branch
6. Merge and delete branch
   - Default merge method: merge commit
   - `gh pr merge <pr> --merge --delete-branch`
7. Post-merge: patch PR body links to base branch
   - Get base branch: `gh pr view <pr> --json baseRefName -q .baseRefName`
   - Update `## Progress` to:
     - `https://github.com/<owner>/<repo>/blob/<baseRefName>/docs/progress/archived/<file>.md`
8. Post-merge: patch planning PR (when present)
   - Extract planning PR from the progress file `Links -> Planning PR`
   - Ensure the planning PR body contains:
     - `## Implementation`
       - `- [PR #<feature_pr_number>: <feature_pr_title>](<feature_pr_url>)`

## Optional helper script

- Use `scripts/close_progress_pr.sh` in this skill folder to run a deterministic version of steps 3–8.
- If `scripts/close_progress_pr.sh` fails, attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
