---
name: deliver-feature-pr
description: Define the default end-to-end feature delivery method: create PR, wait/fix CI until green, then close PR.
---

# Deliver Feature PR

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Working tree is clean before preflight and before merge/close.
- Companion skills available:
  - `create-feature-pr`
  - `close-feature-pr`

Inputs:

- Feature summary + acceptance criteria (forwarded to `create-feature-pr`).
- Optional `base` and merge target branch (default: `main` -> `main`).
- Optional PR number (if omitted, resolve from the current branch PR).

Outputs:

- Feature branch created from the confirmed base branch.
- A GitHub PR created via `create-feature-pr`.
- CI checks fully green; failed checks are fixed before merge.
- PR merged and cleaned up via `close-feature-pr`.

Exit codes:

- `0`: success
- `1`: workflow blocked/failure (branch mismatch, CI failure, auth issues, command failure)
- `2`: usage error
- `124`: CI wait timeout

Failure modes:

- Initial branch is not the expected base branch (`main` by default):
  - Stop immediately and ask the user to confirm source branch and merge target.
- CI checks fail:
  - Do not merge; fix issues on the feature branch, push, and re-run CI wait.
- Skill conflict or ambiguity (branch target, merge strategy, or "skip CI"):
  - Stop and ask the user to confirm the canonical workflow before continuing.
- Missing `gh` auth/permissions or non-mergeable PR.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`

## Workflow

1. Branch-intent preflight (mandatory)
   - Run:
     - `deliver-feature-pr.sh preflight --base main`
   - Contract:
     - This delivery method starts from `main`, creates `feat/*`, and merges back to `main`.
     - If current branch is not `main` (or not the user-confirmed base), stop and ask the user.
2. Create feature PR
   - Use `create-feature-pr` to:
     - create a new `feat/<slug>` branch from confirmed base
     - implement + test
     - commit + push + open PR
3. Wait for CI and repair until green
   - Run:
     - `deliver-feature-pr.sh wait-ci --pr <number>`
   - If any check fails:
     - fix on the same feature branch
     - push updates
     - re-run `wait-ci`
   - Do not proceed to merge until checks are fully green.
4. Close feature PR
   - Run:
     - `deliver-feature-pr.sh close --pr <number>`
   - This delegates to `close-feature-pr` behavior: merge PR and clean branches.
5. Report delivery artifacts
   - Include PR URL, CI status summary, merge commit SHA, and final branch state.

## Conflict policy

- This skill is a delivery-policy skill and is designed to compose with implementation skills.
- If another skill suggests a conflicting branch target, merge strategy, or CI bypass:
  - ask the user first
  - continue only after one clear, confirmed flow is chosen.
