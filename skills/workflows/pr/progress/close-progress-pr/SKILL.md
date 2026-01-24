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
- If the progress is implemented via multiple PRs (stacked/split), run this on the **final** PR when the progress should be marked `DONE`.

Inputs:

- PR number (or current-branch PR).
- Optional: progress file under `docs/progress/` referenced by the PR (use `--progress-file` when PR body is missing/ambiguous).
- Optional: `--keep-branch` to keep the remote head branch after merge.

Outputs:

- Progress file finalized (`Status: DONE`), moved to `docs/progress/archived/`, and indexed in `docs/progress/README.md`.
- PR merged (default merge commit) and head branch deleted (remote; best-effort).
- PR body `## Progress` link patched to point to base branch (survives branch deletion).

Exit codes:

- `0`: success
- non-zero: missing progress link/file, validation failures, or git/gh command failures

Failure modes:

- Deferred checklist items missing `Reason:` (fail-fast).
- Unchecked checklist items containing invalid `~~` (fail-fast; must be full-line `- [ ] ~~...~~`).
- Progress file cannot be located or moved (path mismatch, conflicts).
- PR merge blocked (draft/checks failing/permissions).
- PR is not progress-tracked (`## Progress` is `None` or missing); use `close-feature-pr` instead.

## Setup

- Ensure `gh auth status` succeeds.

## Key rule: Progress links must survive branch deletion

After merge, GitHub often deletes the head branch. Any PR body link like:

- `https://github.com/<owner>/<repo>/blob/<head-branch>/docs/progress/...`

will break.

Patch the PR body `## Progress` link to point to the base branch (usually `main`) after merge:

- `https://github.com/<owner>/<repo>/blob/<base-branch>/docs/progress/archived/<file>.md`

## Key rule: Planning PRs should link to the implementation PR

If the progress file references a planning PR (explicit `- Planning PR:` or a docs-only progress PR under `Links -> PR`), ensure that planning PR body includes:

- `## Implementation PRs` (preferred), or legacy `## Implementation`
- A link to this PR (append if missing; do not overwrite existing entries)

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
     - Auto-defer unchecked checklist items under `## Steps (Checklist)` by marking them `~~...~~` (excluding Step 4 “Release / wrap-up”)
       - Pass: `- [x] ...`
       - Auto-fix: `- [ ] ...` → `- [ ] ~~...~~`
       - Fail: unchecked item contains `~~` but is not full-line `- [ ] ~~...~~`
     - For intentionally deferred / not-do items (Steps 0–3), keep the checkbox unchecked, include an explicit `Reason:`, and mark the item text with Markdown strikethrough (use `- [ ] ~~like this~~`)
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
   - `gh pr merge <pr> --merge`
   - Best-effort delete remote head branch:
     - `git push origin --delete <headRefName>`
7. Post-merge: patch PR body links to base branch
   - Get base branch: `gh pr view <pr> --json baseRefName -q .baseRefName`
   - Update `## Progress` to:
     - `https://github.com/<owner>/<repo>/blob/<baseRefName>/docs/progress/archived/<file>.md`
8. Post-merge: patch planning PR (when present)
   - Extract planning PR from the progress file (`Links -> Planning PR` when present; otherwise infer from the pre-close `Links -> PR` if it points to a docs-only planning PR)
   - Ensure the planning PR body contains:
     - `## Implementation PRs` (preferred) or legacy `## Implementation`
       - Includes `- [#<feature_pr_number>](<feature_pr_url>)` (append if missing; do not overwrite existing entries)

## Optional helper script

- Use `$CODEX_HOME/skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh` in this skill folder to run a deterministic version of steps 3–8.
- If `$CODEX_HOME/skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh` fails, attempt to fix the underlying cause (prefer fixing the script when it's a script bug, otherwise fix the documented prerequisites/workflow), re-run it, and explicitly report whether the fix succeeded.
