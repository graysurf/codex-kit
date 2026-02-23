---
name: deliver-bug-pr
description: "Define the default end-to-end bug PR delivery method: create PR, wait/fix CI until green, then close PR."
---

# Deliver Bug PR

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Working tree may be dirty before preflight; preflight must run scope triage first.
- Working tree must be clean before merge/close.
- Companion skills available:
  - `create-bug-pr`
  - `close-bug-pr`

Inputs:

- bug summary + expected vs actual behavior (forwarded to `create-bug-pr`).
- Optional `base` and merge target branch (default: `main` -> `main`).
- Optional PR number (if omitted, resolve from the current branch PR).
- Optional ambiguity bypass flag for preflight: `--bypass-ambiguity` (alias: `--proceed-all`).
  Use only after explicit user confirmation that suspicious files are in scope.

Outputs:

- Bugfix branch created from the confirmed base branch.
- A GitHub PR created via `create-bug-pr`.
- CI checks fully green; failed checks are fixed before merge.
- PR merged and cleaned up via `close-bug-pr`.
- `deliver-bug-pr` is successful only after merge/close is complete; create-only is not a successful delivery outcome.

Exit codes:

- `0`: success
- `1`: workflow blocked/failure (branch mismatch, CI failure, auth issues, command failure)
- `2`: usage error
- `124`: CI wait timeout

Failure modes:

- Initial branch is not the expected base branch (`main` by default):
  - Stop immediately and ask the user to confirm source branch and merge target.
- CI checks fail:
  - Do not merge; fix issues on the bugfix branch, push, and re-run CI wait.
- Skill conflict or ambiguity (branch target, merge strategy, or "skip CI"):
  - Stop and ask the user to confirm the canonical workflow before continuing.
- PR remains draft and automatic `gh pr ready` fails during close.
- Missing `gh` auth/permissions or non-mergeable PR.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/pr/bug/deliver-bug-pr/scripts/deliver-bug-pr.sh`

## Workflow

1. Branch-intent preflight (mandatory)
   - Run:
     - `deliver-bug-pr.sh preflight --base main`
   - Optional explicit bypass run (non-blocking mode):
     - `deliver-bug-pr.sh preflight --base main --bypass-ambiguity`
   - Contract:
     - This delivery method starts from `main`, creates `fix/*`, and merges back to `main`.
     - Preflight must classify `staged`/`unstaged`/`untracked` changes and apply the suspicious-signal matrix.
     - If current branch is not `main` (or not the user-confirmed base), stop and ask the user.
     - `--bypass-ambiguity` only bypasses ambiguity block payloads after explicit user approval.
       It does not bypass branch guard, auth checks, or later CI gates.
2. Create bug PR
   - Use `create-bug-pr` to:
     - create a new `fix/<slug>` branch from confirmed base
     - implement + test
     - commit + push + open PR
3. Wait for CI and repair until green
   - Run:
     - `deliver-bug-pr.sh wait-ci --pr <number>`
   - If any check fails:
     - fix on the same bugfix branch
     - push updates
     - re-run `wait-ci`
   - Do not proceed to merge until checks are fully green.
4. Close bug PR
   - Run:
     - `deliver-bug-pr.sh close --pr <number>`
   - This delegates to `close-bug-pr` behavior: if draft, auto-mark ready first, then merge PR and clean branches.
5. Report delivery artifacts
   - Include PR URL, CI status summary, merge commit SHA, and final branch state.

## Completion gate

- If there is no blocking error, this workflow must run end-to-end through `close`.
- Do not stop after create/open PR and report "next step is wait-ci/close".
- A stop before `close` is valid only when a real block/failure exists (for example: ambiguity confirmation pending, CI still failing, timeout, auth/permission failure, non-mergeable PR, or explicit user pause).
- When stopping before `close`, report status as `BLOCKED` or `FAILED` with the exact unblock action; do not report partial success.

## Suspicious-signal matrix

| Signal | Check rule | Risk level | Required handling |
| --- | --- | --- | --- |
| Cross-domain path spread | Changed paths span 2+ domains (app/product, infra/CI/tooling, docs/process) for a single-domain request. | medium | Inspect suspicious diffs before deciding scope. |
| Infra/tooling-only edits unrelated to request | Files are only infra/tooling paths (for example `.github/`, `scripts/`, `skills/tools/`, lockfiles) while user request is bug-fix/product behavior. | high | Inspect diffs; if request linkage is unclear, block and confirm. |
| Same-file `staged`+`unstaged` overlap | Any identical path appears in both staged and unstaged sets. | high | Always escalate to diff inspection; do not auto-pass filename triage. |

## Escalation policy

- When any suspicious signal is present:
  - inspect diffs for each suspicious path first
  - classify each path as `in-scope`, `out-of-scope`, or `uncertain`
  - if any path remains `uncertain`, stop and confirm with the user
- `uncertain => stop and confirm` is mandatory for both mixed-status and single-status preflight.
- Explicit bypass exception:
  - after the user clearly confirms "proceed all" / "all suspicious files are in scope",
    run preflight again with `--bypass-ambiguity` to continue without blocking.
  - do not silently bypass; user confirmation is required in the same task context.
- Do not auto-stage, auto-reset, or silently drop files during escalation.

## Bypass guidance

- Use `--bypass-ambiguity` (or `--proceed-all`) when:
  - preflight returns `BLOCK_STATE=blocked_for_ambiguity`
  - the user explicitly asks to continue despite ambiguity
  - the changed paths are confirmed in-scope for the requested delivery
- Do not use bypass when:
  - branch guard fails (wrong source/base branch)
  - authentication/permission checks fail
  - CI checks are failing (must fix and rerun)
  - handling draft-state PRs (draft is resolved by auto-ready in close flow, not by bypass)
  - mergeability/policy checks fail

## Stop-and-confirm output contract

- When preflight blocks for ambiguity, return a deterministic block payload and exit `1`.
- Required fields:
  - `BLOCK_STATE`: must be `blocked_for_ambiguity`
  - `CHANGE_STATE_SUMMARY`: counts for `staged`, `unstaged`, `untracked`, and `mixed_status=true|false`
  - `SUSPICIOUS_FILES`: list of paths flagged by the suspicious-signal matrix
  - `SUSPICIOUS_REASONS`: one reason per suspicious file, mapped to matrix signal names
  - `DIFF_INSPECTION_RESULT`: per file classification `in-scope|out-of-scope|uncertain`
  - `CONFIRMATION_PROMPT`: explicit user action request to proceed or abort
  - `NEXT_ACTION`: must state "wait for user confirmation before continuing"

## Preflight outcome examples

1. Pass (`single_status_fast_path` or `mixed_status`)
   - Example output:
     - `CHANGE_STATE_SUMMARY=staged:2,unstaged:0,untracked:0,mixed_status=false`
     - `FLOW=single_status_fast_path`
     - `ok: preflight passed (base=main)`
2. Ambiguity block (`blocked_for_ambiguity`)
   - Example output:
     - `FLOW=single_status_escalation`
     - `BLOCK_STATE=blocked_for_ambiguity`
     - `SUSPICIOUS_FILES=...`
     - `SUSPICIOUS_REASONS=...`
     - `DIFF_INSPECTION_RESULT=...`
     - `CONFIRMATION_PROMPT=Confirm whether the suspicious files are in scope for this task (proceed/abort).`
     - `NEXT_ACTION=wait for user confirmation before continuing`
3. Branch mismatch block
   - Example output:
     - `error: initial branch guard failed (current=bugfix/demo, expected=main)`
     - `action: stop and ask user to confirm source branch and merge target before continuing.`
4. Ambiguity bypass pass (`single_status_escalation_bypass_ambiguity` / `mixed_status_bypass_ambiguity`)
   - Example output:
     - `FLOW=single_status_escalation_bypass_ambiguity`
     - `BYPASS_STATE=ambiguity_bypassed`
     - `SUSPICIOUS_FILES=...`
     - `BYPASS_NOTE=Preflight ambiguity checks were explicitly bypassed via --bypass-ambiguity.`
     - `ok: preflight passed (base=main)`

## Conflict policy

- This skill is a delivery-policy skill and is designed to compose with implementation skills.
- If another skill suggests a conflicting branch target, merge strategy, or CI bypass:
  - ask the user first
  - continue only after one clear, confirmed flow is chosen.
