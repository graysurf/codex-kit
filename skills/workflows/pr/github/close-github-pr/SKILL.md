---
name: close-github-pr
description:
  "Merge and close GitHub pull requests with gh after provider-specific checks gating, draft readiness, merge, and local cleanup. Use with
  `kind=feature` or `kind=bug`."
---

# Close GitHub PR

## Contract

Prereqs:

- Run inside the target GitHub-backed git repo.
- `git`, `gh`, and `python3` available on `PATH`.
- Working tree clean (`git status --porcelain=v1` is empty).

Inputs:

- `kind=feature|bug`.
- PR number, or current-branch PR when `--pr` is omitted.
- Optional cleanup controls: `--keep-branch` and `--no-cleanup`.
- Optional no-CI acknowledgement: `--allow-no-checks`.

Outputs:

- Required PR checks verified as passing, or checks explicitly accepted as
  missing with `--allow-no-checks`. Optional skipped checks do not block merge.
- Draft PRs marked ready with `gh pr ready <pr>` before merge.
- PR merged with a merge commit.
- Remote head branch deleted unless `--keep-branch` is supplied.
- Local checkout switched back to base branch and updated; local head branch deleted unless `--no-cleanup` is supplied.

Exit codes:

- `0`: success
- `1`: workflow blocked/failure (dirty tree, missing checks without explicit allow, failed checks, non-open PR, merge failure, command failure)
- `2`: usage error

Failure modes:

- PR checks are missing and `--allow-no-checks` was not supplied.
- Required PR checks are failing, canceled, timed out, skipped, blocked, or
  still pending.
- PR is draft and automatic `gh pr ready` fails.
- PR is not open, not mergeable, or `gh`/`git` permissions are insufficient.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/pr/github/close-github-pr/scripts/close-github-pr.sh`

## Workflow

1. Resolve PR metadata
   - Run:
     - `close-github-pr.sh --kind <feature|bug> --pr <number>`
   - Resolve PR URL, base branch, head branch, state, and draft state through `gh pr view`.

2. Gate on required GitHub checks
   - Default behavior blocks missing checks:
     - `close-github-pr.sh --kind <feature|bug> --pr <number>`
   - Repositories with no checks require explicit acknowledgement:
     - `close-github-pr.sh --kind <feature|bug> --pr <number> --allow-no-checks`
   - Required checks are the hard merge gate. Optional skipped checks are
     non-blocking when required checks pass.
   - `--allow-no-checks` only accepts missing checks. It must not bypass failed, canceled, timed out, blocked, pending, skipped, or unknown
     required check states.

3. Mark ready and merge
   - If draft, run `gh pr ready <pr>` automatically.
   - Merge with `gh pr merge <pr> --merge` plus `--yes` when supported.

4. Cleanup
   - Delete the remote head branch unless `--keep-branch` is supplied.
   - Switch to the base branch, pull fast-forward, and delete the local head branch unless `--no-cleanup` is supplied.
   - If the base branch is locked by another worktree, fall back to detached `origin/<base>` for local branch deletion.

## Kind Policy

- `kind=feature`: use for feature PRs originally created by `create-github-pr`.
- `kind=bug`: use for bugfix PRs originally created by `create-github-pr`.
- The close mechanics are provider-specific and shared across both kinds; kind is retained for auditability and composition by
  `deliver-github-pr`.
