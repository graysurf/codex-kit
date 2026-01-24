# Progress PR Workflow (Runbook)

Status: Draft  
Last updated: 2026-01-24

This runbook documents the end-to-end flow across the progress PR skills:

- `create-progress-pr`
- `handoff-progress-pr`
- `worktree-stacked-feature-pr`
- `close-progress-pr`
- `progress-addendum`

## Quickstart (real GitHub run)

1) Preflight:

- Run inside the target repo root.
- `gh auth status` succeeds.
- Clean working tree in the primary checkout.

2) Create the planning progress PR (docs-only):

- Follow `skills/workflows/pr/progress/create-progress-pr/SKILL.md`.
- Ensure the PR body includes a Progress link with a full GitHub blob URL:
  - `https://github.com/<owner>/<repo>/blob/<branch>/docs/progress/<file>.md`

3) Handoff (merge planning PR and patch Progress link):

- `bash $CODEX_HOME/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh --pr <planning_pr_number>`

4) Create worktrees and stacked branches from a spec:

- `bash $CODEX_HOME/skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh --spec <path/to/pr-splits.tsv>`
- Optional flags:
  - `--worktrees-root <path>` to override the default worktrees root.
  - `--dry-run` to print planned worktrees without creating them.

5) Open implementation PRs (draft) from each worktree:

- PR1 base: `main`
- PR2+ base: PR1 branch (stacked) until PR1 merges.
- Include in each PR body:
  - Progress link on base branch: `https://github.com/<owner>/<repo>/blob/main/docs/progress/<file>.md`
  - Planning PR reference: `#<planning_pr_number>`

6) Close out the workflow after implementation merges:

- `bash $CODEX_HOME/skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh --pr <final_pr_number> --progress-file docs/progress/<file>.md`
- Optional cleanup of worktrees (preview first):
  - `bash $CODEX_HOME/skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh --prefix <branch-prefix> --dry-run`
  - `bash $CODEX_HOME/skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh --prefix <branch-prefix> --yes`

## Invariants (must always hold)

### Progress PR creation

- Progress file path is `docs/progress/<YYYYMMDD>_<feature_slug>.md`.
- Progress PR body includes a Progress link to the progress file using a full GitHub blob URL.
- Planning PR body includes an `Implementation PRs` section (use `PR: TBD` until real PRs exist).

### Handoff (merge planning PR)

- Planning PR is merged into the base branch (default `main`).
- Planning PR body Progress link is patched to `blob/<base-branch>/...` so it survives branch deletion.

### Stacked implementation PRs

- PR1 base is `main`.
- PR2+ base is PR1 branch until PR1 merges; then rebase and retarget to `main`.
- Every implementation PR body includes:
  - Progress link on the base branch (`blob/main/...`).
  - Planning PR reference (`#<planning_pr_number>`).
- Worktrees are created under the default root `../.worktrees/<repo_name>/` unless overridden with `--worktrees-root`.
- Worktree names are filesystem-safe (replace `/` with `__`).

### Close + archive

- Progress file is moved to `docs/progress/archived/` and the index updated (when present).
- Final PR body reflects the archival action and any required link patches.
- Planning PR body lists all implementation PRs once they exist.

## CI vs Real GitHub Matrix

| Area | CI (fixtures + gh stub) | Real GitHub (required) |
| --- | --- | --- |
| Progress file formatting + placeholder removal | `rg`/validation scripts ensure no `[[...]]` tokens | N/A |
| Progress index table updates | `validate_progress_index.sh` | Confirm index link renders on GitHub |
| Worktree helper scripts | Fixture tests verify `create_worktrees_from_tsv.sh` and `cleanup_worktrees.sh` behavior | Optional spot-check with real repo paths |
| PR creation + merge | Stubbed `gh` validates arguments | Must create/merge real PRs |
| Progress link patching | Stubbed `gh pr edit` flow | Must verify PR body links resolve in GitHub UI |
| Stacked PR base retarget | Stubbed `gh pr edit` flow | Must verify base branch updates in GitHub UI |
| Archive progress file | Fixture tests verify file move + index edit | Must verify archived file link renders on GitHub |

## Evidence checklist (real GitHub run)

Capture these artifacts under `out/e2e/progress-pr-workflow/`:

- Planning PR URL (merged) with patched Progress link to `blob/<base-branch>/...`.
- Implementation PR URLs (draft or open) with correct base branches.
- Proof of stacked base retarget after PR1 merge (before/after `gh pr view` JSON or screenshots).
- Archived progress file URL under `docs/progress/archived/`.
- Final PR URL showing close/archive notes (if applicable).
- Command logs for handoff, worktree creation, and cleanup (stdout/stderr).

## Known failure modes

- Planning PR still draft or not mergeable → stop and fix before handoff.
- Worktree path collisions → remove/rename and run `git worktree prune`.
- Stacked PRs touching the same files heavily → split further (Sprint 2a/2b/2c) or serialize.
- Progress link points to a branch that gets deleted → repatch to `blob/<base-branch>/...`.
- Using `gh pr merge --delete-branch` while the head branch is checked out in a worktree can fail *after* a successful merge and prevent post-merge link patching → prefer the provided progress scripts (or avoid `--delete-branch` and delete the remote branch separately).
