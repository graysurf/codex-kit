---
name: deliver-gitlab-mr
description:
  "Deliver GitLab merge requests end to end with one workflow: preflight, create via create-gitlab-mr, wait/fix pipeline until green, then close via close-gitlab-mr."
---

# Deliver GitLab MR

## Contract

Prereqs:

- Run inside the target GitLab-backed git repo.
- `git`, `glab`, and `python3` available on `PATH`, and `glab auth status` succeeds for the target host.
- Working tree may be dirty before preflight; preflight must run scope triage first.
- Working tree must be clean before merge.
- Companion skills available: `create-gitlab-mr` and `close-gitlab-mr`.

Inputs:

- `kind=feature|bug|config|deploy|docs|chore`.
- MR outcome summary plus target branch, source branch, testing notes, and related deployment/config evidence when applicable.
- Optional MR IID or current-branch MR resolution.
- Optional base branch for preflight (default: `main`).
- Optional merge controls: `--remove-source-branch`, `--squash`, `--sha <commit>`, `--skip-pipeline`, `--allow-no-pipeline`,
  `--keep-local-branch`, and `--no-cleanup`.
- Optional ambiguity bypass flag for preflight: `--bypass-ambiguity` (alias: `--proceed-all`). Use only after explicit user confirmation
  that suspicious files are in scope.

Outputs:

- Branch created from the confirmed base branch when new work is needed:
  - `kind=feature` -> `feat/<slug>`
  - `kind=bug` -> `fix/<slug>`
  - `kind=docs` -> `docs/<slug>`
  - `kind=config|deploy|chore` -> `chore/<slug>`
- A GitLab MR created through `create-gitlab-mr`.
- Pipeline status fully green; failed or blocked pipelines are fixed before merge.
- MR marked ready when it is draft, merged, and cleaned up through `close-gitlab-mr`.
- `deliver-gitlab-mr` is successful only after close/merge is complete; create-only is not a successful delivery outcome.

Exit codes:

- `0`: success
- `1`: workflow blocked/failure (branch mismatch, pipeline failure, auth issues, command failure)
- `2`: usage error
- `124`: pipeline wait timeout

Failure modes:

- Initial branch is not the expected base branch (`main` by default):
  - Stop immediately and ask the user to confirm source branch and target branch.
- `glab auth status` fails or exceeds `AGENT_KIT_GLAB_AUTH_TIMEOUT_SEC` (default: `30`):
  - Stop and report GitLab auth/network status before attempting MR creation or merge.
- Pipeline fails, is canceled, is skipped, is blocked, or requires a manual action:
  - Do not merge; fix issues on the delivery branch, push, and re-run pipeline wait.
- No pipeline exists for the source branch:
  - Stop by default; continue only when the user explicitly supplied `--allow-no-pipeline`.
- Skill conflict or ambiguity (branch target, merge strategy, source branch deletion, or "skip pipeline"):
  - Stop and ask the user to confirm the canonical workflow before continuing.
- MR remains draft and automatic `glab mr update --ready` fails during merge.
- Missing `glab` auth/permissions, wrong GitLab project, or non-mergeable MR.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh`

## Workflow

1. Choose kind
   - Use `kind=feature` for feature delivery. Branch prefix is `feat/`.
   - Use `kind=bug` for bugfix delivery. Branch prefix is `fix/`.
   - Use `kind=docs` for documentation-only delivery. Branch prefix is `docs/`.
   - Use `kind=config`, `kind=deploy`, or `kind=chore` for operational/configuration delivery. Branch prefix is `chore/`.

2. Branch-intent preflight (mandatory)
   - Run:
     - `deliver-gitlab-mr.sh --kind <kind> preflight --base main`
   - Optional explicit bypass run (non-blocking mode):
     - `deliver-gitlab-mr.sh --kind <kind> preflight --base main --bypass-ambiguity`
   - Contract:
     - This delivery method starts from the confirmed base branch, creates or reuses a source branch, and targets the confirmed target branch.
     - Preflight must classify `staged`/`unstaged`/`untracked` changes and apply the suspicious-signal matrix.
     - Preflight must bound `glab auth status` with `AGENT_KIT_GLAB_AUTH_TIMEOUT_SEC` so GitLab network/auth failures do not hang delivery.
     - If current branch is not `main` (or not the user-confirmed base), stop and ask the user.
     - `--bypass-ambiguity` only bypasses ambiguity block payloads after explicit user approval. It does not bypass branch guard, auth
       checks, or later pipeline gates.

3. Create MR
   - Use `create-gitlab-mr` to:
     - create or reuse the source branch
     - implement + test
     - commit + push
     - open a draft MR by default
   - MR creation must keep the audited marker required by `create-gitlab-mr`: `AGENT_KIT_PR_SKILL=create-gitlab-mr`.

4. Wait for pipeline and repair until green
   - Run:
     - `deliver-gitlab-mr.sh --kind <kind> wait-pipeline --mr <iid>`
   - For repositories without CI, use explicit no-pipeline acknowledgement:
     - `deliver-gitlab-mr.sh --kind <kind> wait-pipeline --mr <iid> --allow-no-pipeline`
   - If any pipeline fails or blocks:
     - fix on the same delivery branch
     - push updates
     - re-run `wait-pipeline`
   - Do not proceed to merge until the pipeline is green, unless the user explicitly confirms `--allow-no-pipeline` or `--skip-pipeline`.
   - For repos whose source-branch pipeline is intentionally skipped and whose
     real build/deploy gate is target-branch CI, verify MR mergeability and the
     target-branch validation model before using explicit `--skip-pipeline`.

5. Close MR
   - Run:
     - `deliver-gitlab-mr.sh --kind <kind> close --mr <iid>`
   - The close flow delegates to `close-gitlab-mr` and:
     - requires a clean working tree
     - marks draft MRs ready with `glab mr update <iid> --ready --yes`
     - merges with `glab mr merge <iid> --yes`
     - allows missing CI only when `--allow-no-pipeline` is explicitly supplied
     - does not remove the remote source branch unless `--remove-source-branch` is explicitly supplied
     - switches back to the target branch, fast-forwards from `origin/<target>`, and deletes the local source branch unless cleanup is disabled

6. Report delivery artifacts
   - Include MR URL/IID, pipeline status summary, merge result, target branch, and final branch state.

## Completion Gate

- If there is no blocking error, this workflow must run end-to-end through `close`.
- Do not stop after create/open MR and report "next step is wait-pipeline/close".
- A stop before `close` is valid only when a real block/failure exists (for example: ambiguity confirmation pending, pipeline still
  failing, timeout, auth/permission failure, non-mergeable MR, or explicit user pause).
- Closing an MR without merge is cleanup/abort, not successful delivery.
- When stopping before `close`, report status as `BLOCKED` or `FAILED` with the exact unblock action; do not report partial success.

## Suspicious-Signal Matrix

| Signal                                        | Check rule                                                                                                                                  | Risk level | Required handling                                                |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------------------------------------------------------------- |
| Cross-domain path spread                      | Changed paths span 2+ domains (app/product, infra/CI/tooling, docs/process) for a single-domain request.                                    | medium     | Inspect suspicious diffs before deciding scope.                  |
| Infra/tooling-only edits unrelated to request | Files are only infra/tooling paths (for example `.gitlab-ci.yml`, `.github/`, `scripts/`, `skills/tools/`, lockfiles) while request is app. | high       | Inspect diffs; if request linkage is unclear, block and confirm. |
| Same-file `staged`+`unstaged` overlap         | Any identical path appears in both staged and unstaged sets.                                                                                | high       | Always escalate to diff inspection; do not auto-pass triage.     |

## Bypass Guidance

- Use `--bypass-ambiguity` (or `--proceed-all`) when:
  - preflight returns `BLOCK_STATE=blocked_for_ambiguity`
  - the user explicitly asks to continue despite ambiguity
  - the changed paths are confirmed in scope for the requested delivery
- Do not use bypass when:
  - branch guard fails
  - authentication/permission checks fail
  - pipeline fails or blocks
  - pipeline is missing and `--allow-no-pipeline` was not explicitly supplied
  - handling draft-state MRs
  - mergeability or project policy checks fail

## Stop-And-Confirm Output Contract

- When preflight blocks for ambiguity, return a deterministic block payload and exit `1`.
- Required fields:
  - `BLOCK_STATE`: must be `blocked_for_ambiguity`
  - `CHANGE_STATE_SUMMARY`: counts for `staged`, `unstaged`, `untracked`, and `mixed_status=true|false`
  - `SUSPICIOUS_FILES`: list of paths flagged by the suspicious-signal matrix
  - `SUSPICIOUS_REASONS`: one reason per suspicious file, mapped to matrix signal names
  - `DIFF_INSPECTION_RESULT`: per file classification `in-scope|out-of-scope|uncertain`
  - `CONFIRMATION_PROMPT`: explicit user action request to proceed or abort
  - `NEXT_ACTION`: must state "wait for user confirmation before continuing"
