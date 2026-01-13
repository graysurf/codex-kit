---
name: script-smoke-planned-pr
description: Implement a single Script Smoke Step 2 planned PR (by PR number) tracked in docs/progress/20260113_script-smoke-tests.md, keep the stack rebased (feat/script-smoke-tests onto main; children onto feat/script-smoke-tests), and close it via close-feature-pr.
---

# Script Smoke Planned PR

## Purpose

- Standardize how we implement the Step 2 "Planned PRs" for the script smoke expansion.
- Canonical progress file: `docs/progress/20260113_script-smoke-tests.md` (see "Step 2 PR Plan").

## Usage

- User invocation (preferred): `$script-smoke-planned-pr #23`

## Contract

Prereqs:

- Run inside this repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Working tree clean (`git status --porcelain=v1` is empty).

Inputs:

- PR number (e.g. `#23`).

Outputs:

- The specified PR implemented per its row in "Step 2 PR Plan".
- Branch synced to the latest base fixes (see "Rebase policy").
- PR merged + closed via `close-feature-pr` (and remote branch deleted).

Exit codes:

- `0`: completed successfully (including "already closed" no-op)
- non-zero: invalid input, missing/ambiguous scope in progress file, dirty working tree, rebase/test failures, or merge failure

Failure modes:

- `gh auth status` fails or `gh pr view` cannot read PR metadata.
- PR is not `OPEN` (skill stops and reports status).
- PR number not found in `docs/progress/20260113_script-smoke-tests.md` "Step 2 PR Plan" table.
- Rebase conflicts or force-push rejected (requires manual resolution).
- Tests or required checks fail; PR cannot be merged.

Non-goals:

- Do not expand scope beyond what the progress file assigns to that PR.
- Do not merge/close the main progress PR; this skill is for *feature PRs* only.

## Workflow

1. Resolve PR metadata
   - Read PR JSON (at minimum `baseRefName`, `headRefName`, `state`, `isDraft`).
   - If not `OPEN`, stop and report status.
2. Confirm scope from the progress file
   - Open `docs/progress/20260113_script-smoke-tests.md`.
   - Locate the PR row under "Step 2 PR Plan" that matches `#<number>`.
   - If missing or ambiguous, use `ask-questions-if-underspecified` before coding.
3. Checkout and preflight
   - Ensure clean tree.
   - `gh pr checkout <number>` (preferred).
4. Rebase policy (keep in sync with fixes)
   - Always fetch: `git fetch origin --prune`.
   - Stacked PR strategy (**default**):
     - Keep the base branch `feat/script-smoke-tests` (PR #22) rebased onto `origin/main`.
     - Keep each planned PR branch rebased onto `origin/feat/script-smoke-tests`.
   - Steps:
     1) If `baseRefName == feat/script-smoke-tests`:
        - Update the base branch first:
          - `git switch feat/script-smoke-tests`
          - `git rebase origin/main`
          - `git push --force-with-lease`
        - Then update the planned PR branch:
          - `git switch <headRefName>` (or `gh pr checkout <number>`)
          - `git rebase origin/feat/script-smoke-tests`
          - `git push --force-with-lease`
     2) If `baseRefName == main` (or default branch):
        - `git rebase origin/main`
        - `git push --force-with-lease`
     3) Otherwise:
        - Use `ask-questions-if-underspecified` to confirm the intended stacking/rebase plan.
5. Implement the planned scope
   - Keep changes minimal and aligned to the PR scope in the progress file.
   - Avoid real network/DB operations; prefer fixtures under `tests/fixtures/**` and stubs under
     `tests/stubs/bin/**`.
6. Validate and record Testing notes
   - Run the narrowest relevant command(s).
   - Default for smoke work: `scripts/test.sh -m script_smoke`.
   - Ensure the PR body has a clear `Testing` section (or add a PR comment).
7. Finalize and close
   - Ensure branch pushed and checks are green.
   - Run the `close-feature-pr` skill for merge + cleanup.

## Commits

- Use the `semantic-commit` skill for every commit; do not call `git commit` directly.

## When uncertain (must ask)

- Use `ask-questions-if-underspecified` and ask the minimum set of questions needed to proceed.
- Recommended "Need to know" template:

```text
Need to know
1) Rebase strategy (baseRefName is not main)?
   a) **Stacked: rebase feat/script-smoke-tests onto origin/main; rebase this PR onto origin/feat/script-smoke-tests**
   b) Retarget this PR to main + rebase origin/main
   c) Other: I will describe the desired stack
2) Required validation for this PR?
   a) **scripts/test.sh -m script_smoke**
   b) script_smoke + additional suite(s): <specify>
Reply with: defaults (or 1a 2a)
```
