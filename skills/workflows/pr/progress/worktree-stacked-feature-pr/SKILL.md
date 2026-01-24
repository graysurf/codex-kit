---
name: worktree-stacked-feature-pr
description: Handoff a progress planning PR, then create multiple stacked feature PRs using git worktrees and parallel subagents (one PR per sprint/phase).
---

# Worktree Stacked Feature PR

Create multiple implementation PRs from a single progress/planning PR, using:

- `gh` + `git` for PR/branch management
- `git worktree` for parallel local checkouts
- subagents for parallel implementation (one worktree per subagent)

This skill is designed to “follow” a progress PR created by `create-progress-pr`, and is aligned with `handoff-progress-pr` (merge planning PR + keep Progress links stable), but extends the workflow to kick off multiple implementation PRs at once.

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Working tree is clean in the *primary* repo checkout before starting.
- You have a progress planning PR number (the docs-only PR), and it is approved and mergeable.
- You intend to create **2+ implementation PRs** that can be worked on in parallel (typically stacked).

Inputs:

- Planning PR number (the progress PR).
- Progress file path: `docs/progress/<YYYYMMDD>_<feature_slug>.md`
- Implementation plan file path (optional but recommended): `docs/plans/<...>-plan.md`
- PR split spec (recommended):
  - `PR 1`: Sprint 1 (base: `main`)
  - `PR 2`: Sprint 2–4 (base: PR 1 branch) — *stacked PR*
  - Add more PRs if needed (e.g., `PR 2a/2b/2c`) to reduce conflicts.

Outputs:

- Planning PR merged and closed; head branch deleted by default.
- Planning PR body Progress link patched to `blob/<base-branch>/...` so it survives branch deletion.
- 2+ implementation branches created.
- 2+ implementation PRs opened (draft by default), each referencing:
  - the progress file (stable link on base branch)
  - the planning PR (`#<number>`)
- Worktrees created for each branch, ready for subagent work.

## Worktree usage policy (explicit rules)

### Directory layout

- **Worktrees root (default)**: `<repo_root>/../.worktrees/<repo_name>/`
  - Example: if repo root is `/work/Rytass/TunGroup`, worktrees go to `/work/Rytass/.worktrees/TunGroup/`
- **Worktree path**: `<worktrees_root>/<worktree_name>/`
  - `worktree_name` must be filesystem-safe: replace `/` with `__`.
  - Example: branch `feat/notifications-sprint1` → worktree `feat__notifications-sprint1`

### Commands (canonical)

- List worktrees:
  - `git worktree list --porcelain`
- Add a worktree + create branch:
  - `git worktree add -b <branch> <path> <start-point>`
  - `<start-point>` is usually `main` (PR1) or `feat/<pr1-branch>` (stacked PR2).
- Remove a worktree (after PR is created/merged):
  - `git worktree remove <path>`
  - `git worktree prune`

### Safety rules

- Never run “global refactors” across multiple worktrees in parallel.
- Do **not** run `yarn install` in multiple worktrees concurrently (contention + huge disk churn).
- Each subagent must:
  - touch only its assigned worktree directory
  - commit only on its assigned branch
  - push only its assigned branch
- When using stacked PRs:
  - PR2 must be based on PR1 branch, and its PR base must be PR1 branch (not `main`) until PR1 merges.

## Workflow

### Step 0 — Preflight (must pass)

1. Confirm planning PR details:
   - Not draft, mergeable, checks green (or explicitly accepted to bypass).
2. Confirm progress file path:
   - Prefer parsing the planning PR body `## Progress` link.
3. Decide PR split(s):
   - Default: (Sprint 1) + (Sprint 2–4 stacked on Sprint 1).

### Step 1 — Handoff (merge) the planning PR

Use the same outcome as `handoff-progress-pr`:

1. Merge planning PR into base (`main`) and delete the head branch.
2. Patch the planning PR body Progress link so it points to `blob/main/...` after merge.

If you have the helper script available:

- `bash $CODEX_HOME/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh --pr <planning_pr_number>`

### Step 2 — Create branches + worktrees (stacked)

Create worktrees from a TSV spec (recommended). Example spec:

- See: `references/pr-splits.example.tsv`

Create worktrees:

- `bash $CODEX_HOME/skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh --spec $CODEX_HOME/skills/workflows/pr/progress/worktree-stacked-feature-pr/references/pr-splits.example.tsv`

### Step 2.5 — Create the PRs (draft) after the first commit

This skill expects each implementation branch to contain at least one commit before opening a PR.

Per branch/worktree (repeat for each PR):

1. Make the first change (it can be a small scaffold commit).
2. Commit using `semantic-commit` / `semantic-commit-autostage` (do not run `git commit` directly).
3. Push the branch.
4. Open the draft PR with the correct base branch:
   - PR1 base: `main`
   - PR2 base: PR1 branch (stacked)

Recommended PR body includes:

- Progress link: `https://github.com/<owner>/<repo>/blob/main/docs/progress/<file>.md`
- Planning PR: `- #<planning_pr_number>`

### Step 2.6 — Patch the planning PR with implementation links (recommended)

After opening the implementation PRs, update the merged planning PR body to include:

- Sprint 1 PR link/number
- Sprint 2–4 PR link/number (and note it is stacked, if applicable)

This makes the planning PR a stable entry point from the progress file.

### Step 3 — Parallelize implementation with subagents

Spawn one subagent per worktree/PR. Each subagent must receive:

- Worktree path
- Branch name
- Scope (which Sprint(s)/tasks to implement)
- Validation commands to run
- PR base branch (for stacked PRs)
- Required PR body metadata:
  - Progress link: `https://github.com/<owner>/<repo>/blob/main/docs/progress/<file>.md`
  - Planning PR: `- #<planning_pr_number>`

**Subagent completion criteria** (required):

- Branch pushed to origin
- Draft PR opened with correct base branch
- Commands run (or “not run (reason)” documented in PR body)
- Short report: files changed + what’s complete vs blocked

### Step 4 — Integration + conflict management

- Prefer stacked PRs to resolve dependencies cleanly.
- If PR2 needs PR1 changes:
  - keep PR2 base on PR1 branch until PR1 merges
  - after PR1 merges, rebase PR2 onto `main` and update the PR base

### Step 5 — Cleanup

- Keep worktrees while PRs are active if you expect follow-up commits.
- Remove worktrees after PR merge (recommended):
  - `git worktree remove <path>`
  - `git worktree prune`

## Failure modes (and what to do)

- Planning PR is still draft → stop; mark ready first.
- Planning PR not mergeable / checks failing → stop; fix or explicitly accept bypass.
- Worktree paths already exist → stop; remove/rename; run `git worktree prune`.
- Two PRs modify the same files heavily → split into more PRs (Sprint 2a/2b/2c) or serialize.
