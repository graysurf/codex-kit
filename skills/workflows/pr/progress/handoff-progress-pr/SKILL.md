---
name: handoff-progress-pr
description: Merge and close a progress planning PR created by create-progress-pr, patch its PR body Progress link to point to the base branch so it survives branch deletion, and kick off implementation work by creating feature PRs that reference the planning PR and progress file. Use when a progress plan PR is approved and you are ready to start implementation.
---

# Handoff Progress PR

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Planning PR body contains a `## Progress` section with a `docs/progress/...` link (preferred), or you pass `--progress-file` explicitly.

Inputs:

- Planning PR number (or current-branch PR).
- Optional: progress file path (when PR body is missing/ambiguous).
- Optional: merge/cleanup flags (keep branch, skip checks, patch-only).

Outputs:

- Planning PR merged and closed; remote head branch deleted by default (best-effort via `git push origin --delete`, unless `--keep-branch`).
- Planning PR body `## Progress` link patched to point to the base branch (survives branch deletion).
- Implementation guidance: create one or more feature PRs that link back to the planning PR and the progress file.

Exit codes:

- `0`: success
- non-zero: missing progress link/file, merge blocked, or `git`/`gh` command failures

Failure modes:

- Planning PR is draft (must mark ready first).
- Required checks failing or PR not mergeable.
- Multiple `docs/progress/...` links in the PR body (must choose one via `--progress-file`).
- Progress link breaks after merge because it still points to the deleted head branch (this skill prevents that).

## Setup

- Ensure `gh auth status` succeeds.
- Ensure the working tree is clean if you plan to merge (stash/commit unrelated work first).

## Key rules

### Progress links must survive branch deletion

If the planning PR is merged and the head branch is deleted, any link like:

- `https://github.com/<owner>/<repo>/blob/<head-branch>/docs/progress/...`

will break.

After merge, patch the planning PR body `## Progress` link to point to the base branch:

- `https://github.com/<owner>/<repo>/blob/<base-branch>/docs/progress/...`

### Implementation PRs must reference the planning PR

When creating feature PRs for implementation:

- Add a clear link back to the planning PR (for traceability).
- Keep linking consistent across multiple implementation PRs (same planning PR + same progress file).

Recommended pattern for feature PR bodies:

- Keep `## Progress` as-is (link to the progress file).
- Add `## Planning PR`:
  - `- #<number>`

## Workflow

1. Identify the planning PR number
   - Prefer current branch PR: `gh pr view --json number -q .number`
2. Resolve the progress file path
   - Prefer parsing the planning PR body `## Progress` link for a `docs/progress/...` path
   - If missing/ambiguous: pass `--progress-file docs/progress/<file>.md`
3. Merge the planning PR (docs-only)
   - Ensure checks pass: `gh pr checks <pr>` (optional but recommended)
   - If draft, mark ready: `gh pr ready <pr>`
   - Merge (merge commit):
     - `gh pr merge <pr> --merge` (add `--yes` when available)
   - Best-effort delete the remote head branch (unless `--keep-branch`):
     - `git push origin --delete <headRefName>`
4. Patch the planning PR body Progress link to base branch
   - Ensure the `## Progress` link points to `blob/<base-branch>/docs/progress/...`
5. Kick off implementation PR(s)
   - Use `create-feature-pr` to implement and open one or more feature PRs.
   - In each implementation PR body:
     - Link the progress file (full GitHub blob URL).
     - Add a `## Planning PR` link back to this planning PR.
   - In the first implementation PR, update the progress file Links block to include the planning PR for long-term traceability:
     - Add: `- Planning PR: <planning PR url>` (if missing)

## Optional helper script

- Use `$CODEX_HOME/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh` to merge and patch deterministically (best-effort remote delete; local cleanup is warning-only):
  - `bash $CODEX_HOME/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh --pr <number>`
  - If already merged but links are broken: `--patch-only`
