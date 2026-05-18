---
name: close-gitlab-mr
description:
  "Merge and close GitLab merge requests with glab after provider-specific pipeline gating, draft readiness, merge, and local cleanup."
---

# Close GitLab MR

## Contract

Prereqs:

- Run inside the target GitLab-backed git repo.
- `git`, `glab`, and `python3` available on `PATH`, and `glab auth status` succeeds for the target host.
- Working tree clean (`git status --porcelain=v1` is empty).

Inputs:

- `kind=feature|bug|config|deploy|docs|chore`.
- MR IID/branch, or current-branch MR when `--mr` is omitted.
- Optional pipeline controls: `--poll-seconds <n>`, `--max-wait-seconds <n>`, `--skip-pipeline`, and `--allow-no-pipeline`.
- Optional merge controls: `--remove-source-branch`, `--squash`, and `--sha <commit>`.
- Optional local cleanup controls: `--keep-local-branch` and `--no-cleanup`.

Outputs:

- MR pipeline verified as passing, or explicitly accepted as missing with `--allow-no-pipeline`.
- Draft MRs marked ready with `glab mr update <mr> --ready --yes` before merge.
- MR merged with `glab mr merge`.
- Remote source branch removed only when `--remove-source-branch` is supplied.
- Local checkout switched back to target branch and updated; local source branch deleted unless `--keep-local-branch` or
  `--no-cleanup` is supplied.

Exit codes:

- `0`: success
- `1`: workflow blocked/failure (dirty tree, missing pipeline without explicit allow, failed pipeline, non-open MR, merge failure,
  command failure)
- `2`: usage error
- `124`: pipeline wait timeout

Failure modes:

- Pipeline is missing and `--allow-no-pipeline` was not supplied.
- Pipeline is failing, canceled, skipped, blocked, manual/action-required, still pending, or unknown.
- MR is draft and automatic `glab mr update --ready` fails.
- MR is not open, not mergeable, or `glab`/`git` permissions are insufficient.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh`

## Workflow

1. Resolve MR metadata
   - Run:
     - `close-gitlab-mr.sh --kind <kind> --mr <iid>`
   - Resolve MR URL, target branch, source branch, state, and draft state through `glab mr view`.

2. Gate on GitLab pipeline
   - Default behavior blocks missing pipelines:
     - `close-gitlab-mr.sh --kind <kind> --mr <iid>`
   - Repositories without CI require explicit acknowledgement:
     - `close-gitlab-mr.sh --kind <kind> --mr <iid> --allow-no-pipeline`
   - `--allow-no-pipeline` only accepts a missing pipeline. It must not bypass failed, skipped, blocked, manual, pending, or
     unknown pipeline states.
   - `--skip-pipeline` is reserved for explicit user-confirmed cases where the pipeline gate should not run at all.
   - For repos whose source-branch pipeline is intentionally skipped and whose
     real build/deploy gate is target-branch CI, verify MR mergeability and the
     target-branch validation model before using explicit `--skip-pipeline`.

3. Mark ready and merge
   - If draft, run `glab mr update <mr> --ready --yes` automatically.
   - Merge with `glab mr merge <mr> --yes`.
   - Pass `--remove-source-branch`, `--squash`, and `--sha <commit>` only when explicitly supplied.

4. Cleanup
   - Switch to the target branch, fetch `origin/<target>`, fast-forward the
     local target branch, and delete the local source branch unless cleanup is
     disabled.
   - If the target branch is locked by another worktree, fall back to detached `origin/<target>` for local branch deletion.

## Kind Policy

- `kind=feature`: use for feature MRs originally created by `create-gitlab-mr`.
- `kind=bug`: use for bugfix MRs originally created by `create-gitlab-mr`.
- `kind=docs`: use for documentation-only MRs originally created by `create-gitlab-mr`.
- `kind=config|deploy|chore`: use for operational/configuration MRs originally created by `create-gitlab-mr`.
- The close mechanics are provider-specific and shared across kinds; kind is retained for auditability and composition by
  `deliver-gitlab-mr`.
