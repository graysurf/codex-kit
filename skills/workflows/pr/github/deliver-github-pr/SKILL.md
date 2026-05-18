---
name: deliver-github-pr
description:
  "Deliver GitHub pull requests end to end with one provider-specific workflow: preflight, create via create-github-pr, wait/fix checks until green, then close via close-github-pr."
---

# Deliver GitHub PR

## Contract

Prereqs:

- Run inside the target GitHub-backed git repo.
- `git`, `gh`, and `python3` available on `PATH`, and `gh auth status` succeeds.
- Working tree may be dirty before preflight; preflight must run scope triage first.
- Working tree must be clean before close/merge.
- Companion skills available: `create-github-pr` and `close-github-pr`.

Inputs:

- `kind=feature|bug`.
- Feature or bug summary, target branch, testing notes, and PR number when closing an existing PR.
- Optional base branch for preflight (default: `main`).
- Optional close controls: `--allow-no-checks`, `--keep-branch`, and `--no-cleanup`.
- Optional ambiguity bypass flag for preflight: `--bypass-ambiguity` (alias: `--proceed-all`). Use only after explicit user confirmation
  that suspicious files are in scope.

Outputs:

- Branch created from the confirmed base branch when new work is needed:
  - `kind=feature` -> `feat/<slug>`
  - `kind=bug` -> `fix/<slug>`
- A GitHub PR created through `create-github-pr`.
- Required GitHub checks green; failed, pending, skipped, or blocked required
  checks are fixed before close. Optional skipped checks are reported by GitHub
  but do not block delivery.
- PR marked ready when draft, merged, and cleaned up through `close-github-pr`.
- `deliver-github-pr` is successful only after close/merge is complete; create-only is not a successful delivery outcome.

Exit codes:

- `0`: success
- `1`: workflow blocked/failure (branch mismatch, checks failure, auth issues, command failure)
- `2`: usage error
- `124`: checks wait timeout

Failure modes:

- Initial branch is not the expected base branch (`main` by default):
  - Stop immediately and ask the user to confirm source branch and target branch.
- Required GitHub checks fail, are canceled, time out, are skipped, are blocked,
  or require action:
  - Do not merge; fix issues on the delivery branch, push, and re-run `wait-checks`.
- No checks exist for the PR:
  - Stop by default; continue only when the user explicitly supplied `--allow-no-checks`.
- Skill conflict or ambiguity (branch target, merge strategy, source branch deletion, or "skip checks"):
  - Stop and ask the user to confirm the canonical workflow before continuing.
- PR remains draft and automatic `gh pr ready` fails during close.
- Missing `gh` auth/permissions, wrong GitHub repository, or non-mergeable PR.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/pr/github/deliver-github-pr/scripts/deliver-github-pr.sh`

## Workflow

1. Choose kind
   - Use `kind=feature` for feature delivery. Branch prefix is `feat/`.
   - Use `kind=bug` for bugfix delivery. Branch prefix is `fix/`.

2. Branch-intent preflight (mandatory)
   - Run:
     - `deliver-github-pr.sh --kind <feature|bug> preflight --base main`
   - Optional explicit bypass run:
     - `deliver-github-pr.sh --kind <feature|bug> preflight --base main --bypass-ambiguity`
   - Contract:
     - This delivery method starts from the confirmed base branch, creates or reuses a source branch, and targets the confirmed target branch.
     - Preflight must classify `staged`/`unstaged`/`untracked` changes and apply suspicious-signal triage.
     - If current branch is not `main` (or not the user-confirmed base), stop and ask the user.
     - `--bypass-ambiguity` only bypasses ambiguity block payloads after explicit user approval. It does not bypass branch guard, auth
       checks, or later checks gates.

3. Create PR
   - Use `create-github-pr` to:
     - create or reuse the source branch
     - implement + test
     - commit + push
     - open a draft PR by default

4. Wait for required checks and repair until green
   - Run:
     - `deliver-github-pr.sh --kind <feature|bug> wait-checks --pr <number>`
   - For repositories without checks, use explicit no-check acknowledgement:
     - `deliver-github-pr.sh --kind <feature|bug> wait-checks --pr <number> --allow-no-checks`
   - If any required check fails or blocks:
     - fix on the same delivery branch
     - push updates
     - re-run `wait-checks`
   - Do not proceed to close until required checks are green, unless the user explicitly confirms `--allow-no-checks`.
   - Optional skipped checks do not block when required checks pass.

5. Close PR
   - Run:
     - `deliver-github-pr.sh --kind <feature|bug> close --pr <number>`
   - The close flow delegates to `close-github-pr` and:
     - requires a clean working tree
     - marks draft PRs ready with `gh pr ready <number>`
     - merges with a merge commit
     - allows missing checks only when `--allow-no-checks` is explicitly supplied
     - gates on required checks; optional skipped checks do not block
     - deletes the remote source branch unless `--keep-branch` is explicitly supplied
     - switches back to the target branch, pulls it, and deletes the local source branch unless cleanup is disabled

6. Report delivery artifacts
   - Include PR URL/number, checks status summary, merge result, target branch, and final branch state.

## Completion Gate

- If there is no blocking error, this workflow must run end-to-end through `close`.
- Do not stop after create/open PR and report "next step is wait-checks/close".
- A stop before `close` is valid only when a real block/failure exists (for example: ambiguity confirmation pending, checks still failing,
  timeout, auth/permission failure, non-mergeable PR, or explicit user pause).
- Closing a PR without merge is cleanup/abort, not successful delivery.
- When stopping before `close`, report status as `BLOCKED` or `FAILED` with the exact unblock action; do not report partial success.

## Bypass Guidance

- Use `--bypass-ambiguity` (or `--proceed-all`) when:
  - preflight returns `BLOCK_STATE=blocked_for_ambiguity`
  - the user explicitly asks to continue despite ambiguity
  - the changed paths are confirmed in scope for the requested delivery
- Do not use bypass when:
  - branch guard fails
  - authentication/permission checks fail
  - checks fail or block
  - checks are missing and `--allow-no-checks` was not explicitly supplied
  - handling draft-state PRs
  - mergeability or repository policy checks fail

## Stop-And-Confirm Output Contract

- When preflight blocks for ambiguity, return a deterministic block payload and exit `1`.
- Required fields:
  - `BLOCK_STATE`: must be `blocked_for_ambiguity`
  - `CHANGE_STATE_SUMMARY`: counts for `staged`, `unstaged`, `untracked`, and `mixed_status=true|false`
  - `SUSPICIOUS_FILES`: list of paths flagged by suspicious-signal triage
  - `SUSPICIOUS_REASONS`: one reason per suspicious file
  - `DIFF_INSPECTION_RESULT`: per file classification `in-scope|out-of-scope|uncertain`
  - `CONFIRMATION_PROMPT`: explicit user action request to proceed or abort
  - `NEXT_ACTION`: must state "wait for user confirmation before continuing"
