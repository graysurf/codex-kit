# Plan: GitLab MR Pipeline Cleanup

## Overview

Fix the GitLab MR delivery gaps captured in the HEURISTIC_SYSTEM inbox entry:
pipeline status parsing for `glab ci status --output json`, skipped/manual
source-branch CI policy for repos whose meaningful CI runs on the target branch,
and local cleanup after a successful merge. Keep the provider-specific
`deliver-gitlab-mr` and `close-gitlab-mr` workflows intact; this plan tightens
their parsing, safety messages, docs, and regression coverage without changing
GitLab provider boundaries.

## Read First

- Primary source:
  `heuristic-system/error-inbox/deliver-gitlab-mr-skipped-pipeline-and-cleanup.md`
- Source type: existing issue/spec
- Open questions carried into execution: none

## Scope

- In scope:
  - Fix `pipeline_status_from_json` behavior in GitLab MR delivery scripts so
    `pipeline.status` and `pipeline.detailed_status.group` payloads are parsed.
  - Preserve the safety rule that skipped/manual source-branch pipelines do not
    auto-pass; report them as explicit policy blocks with actionable guidance.
  - Document the target-branch CI case for repos where source-branch CI is
    intentionally skipped and deployment/build validation happens after merge.
  - Replace local cleanup `git pull --ff-only` behavior with deterministic
    `git fetch origin <target>` plus `git merge --ff-only origin/<target>` where
    cleanup is attached to the target branch.
  - Add focused tests and script smoke coverage for the parsing and cleanup
    regressions.
- Out of scope:
  - Changing GitLab project CI configuration.
  - Treating skipped or manual source-branch pipelines as implicit success.
  - Making `--skip-pipeline` a default.
  - Adding a new GitLab provider skill or merging GitHub/GitLab workflow code.
  - Implementing `skill-usage` CLI locking or operation-record promotion beyond
    updating this inbox entry lifecycle after the plan exists.

## Assumptions

1. `--skip-pipeline` remains an explicit user-confirmed merge control.
2. A skipped/manual source-branch pipeline should produce a parsed status and a
   policy error, not a parse error or silent success.
3. The same JSON parsing behavior should be covered in both
   `deliver-gitlab-mr` and `close-gitlab-mr` because each script currently owns
   a local `pipeline_status_from_json` function.
4. Cleanup should succeed or warn non-fatally after merge; it must not turn a
   confirmed merged MR into a false delivery failure.
5. Existing fake `glab` fixtures are the preferred regression surface; live
   GitLab validation is optional and should not be required for acceptance.

## Sprint 1: Regression Fixtures

**Goal**: Reproduce the known failures in focused tests before changing script
behavior.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --tests -- -k 'gitlab_mr and (deliver or close)'`
  - `scripts/check.sh --tests -- tests/test_script_smoke.py -k 'gitlab and mr'`
- Verify:
  - Tests fail for the current `pipeline.status` nested JSON shape.
  - Tests fail or expose missing coverage for cleanup when target branch local
    config makes `git pull --ff-only` ambiguous.
  - Existing success, missing-pipeline, failed-pipeline, and explicit
    `--skip-pipeline` behavior stays covered.

### Task 1.1: Add Pipeline JSON Shape Fixtures

- **Location**:
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/tests/test_workflows_mr_gitlab_deliver_gitlab_mr.py`
  - `skills/workflows/mr/gitlab/close-gitlab-mr/tests/test_workflows_mr_gitlab_close_gitlab_mr.py`
- **Description**: Extend the fake `glab ci status --output json` helper so
  tests can emit the real observed shape:
  `{ "pipeline": { "status": "skipped" } }`, plus
  `{ "pipeline": { "detailed_status": { "group": "manual" } } }`. Add tests
  proving both scripts parse the shape and report a policy block instead of
  `failed to parse pipeline status`.
- **Dependencies**:
  - none
- **Complexity**: 4
- **Acceptance criteria**:
  - `deliver-gitlab-mr wait-pipeline` prints `PIPELINE_STATUS=skipped` for the
    nested `pipeline.status` fixture and exits with a policy failure.
  - `close-gitlab-mr` prints `PIPELINE_STATUS=skipped` for the same fixture and
    does not call `glab mr merge`.
  - Manual/action-required nested status fixtures are parsed and blocked.
  - No test expects skipped/manual source-branch CI to pass by default.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'gitlab_mr and (pipeline or skipped or manual)'`

### Task 1.2: Add Target-Branch CI Policy Coverage

- **Location**:
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/tests/test_workflows_mr_gitlab_deliver_gitlab_mr.py`
  - `skills/workflows/mr/gitlab/close-gitlab-mr/tests/test_workflows_mr_gitlab_close_gitlab_mr.py`
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/SKILL.md`
  - `skills/workflows/mr/gitlab/close-gitlab-mr/SKILL.md`
- **Description**: Add tests and doc assertions for the explicit target-branch
  CI model: source-branch CI may be skipped by repo rules, but the workflow must
  still require user-confirmed `--skip-pipeline` plus MR mergeability review
  before merging.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 3
- **Acceptance criteria**:
  - Tests cover the default blocked path for skipped source-branch CI.
  - Tests cover the existing explicit `--skip-pipeline` path as the only merge
    bypass for this case.
  - Skill docs explain the target-branch CI case without making it the default.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'gitlab_mr and skip_pipeline'`

### Task 1.3: Add Cleanup Regression Fixture

- **Location**:
  - `skills/workflows/mr/gitlab/close-gitlab-mr/tests/test_workflows_mr_gitlab_close_gitlab_mr.py`
  - `tests/script_specs/skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh.json`
- **Description**: Add a local git fixture with an `origin` remote, target
  branch, source branch, and branch config that makes `git pull --ff-only`
  unsafe or ambiguous. The test should run close cleanup without `--no-cleanup`
  and prove cleanup uses explicit fetch/merge semantics.
- **Dependencies**:
  - none
- **Complexity**: 5
- **Acceptance criteria**:
  - The fixture would fail under the current `git pull --ff-only` cleanup path.
  - After the fix, close cleanup fetches `origin/<target>`, fast-forwards the
    attached target branch, and deletes the local source branch when allowed.
  - If cleanup cannot switch to the target branch, the existing non-fatal
    warning behavior remains covered.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'gitlab_mr and cleanup'`
  - `scripts/check.sh --tests -- tests/test_script_smoke.py -k 'close and gitlab'`

## Sprint 2: Script And Policy Fixes

**Goal**: Implement the parsing, policy messaging, cleanup, and docs updates
proved by Sprint 1.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --tests -- -k 'gitlab_mr and (deliver or close)'`
  - `scripts/check.sh --tests -- tests/test_script_smoke.py -k 'gitlab and mr'`
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`
  - `bash scripts/ci/stale-skill-scripts-audit.sh --check`
  - `scripts/check.sh --entrypoint-ownership`
- Verify:
  - Nested GitLab CI JSON status is parsed in both scripts.
  - Skipped/manual source-branch CI is a clear, user-confirmable policy block.
  - Successful merge cleanup no longer depends on ambiguous `git pull` config.
  - Script specs and skill docs stay aligned.

### Task 2.1: Fix Pipeline Status Parsing

- **Location**:
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh`
  - `skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh`
- **Description**: Update `pipeline_status_from_json` to read the observed
  GitLab JSON paths before falling back to legacy top-level paths:
  `pipeline.status`, `pipeline.detailed_status.group`,
  `pipeline.detailedStatus.group`, `status`, `detailed_status.group`, and
  `detailedStatus.group`. Keep malformed JSON and missing status as hard parse
  errors.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 3
- **Acceptance criteria**:
  - Both scripts parse nested `pipeline.status=skipped` and print
    `PIPELINE_STATUS=skipped`.
  - Both scripts parse nested detailed status groups.
  - Existing top-level `status=success`, failed status, and missing-pipeline
    behavior is unchanged.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'gitlab_mr and pipeline'`

### Task 2.2: Tighten Skipped Source CI Policy

- **Location**:
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh`
  - `skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh`
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/SKILL.md`
  - `skills/workflows/mr/gitlab/close-gitlab-mr/SKILL.md`
- **Description**: Keep skipped/manual/action-required source-branch CI as
  blocking statuses, but make the error text describe the intended recovery:
  verify MR mergeability, confirm the repo uses target-branch CI, then rerun
  close with explicit `--skip-pipeline` only when the user accepts the risk.
- **Dependencies**:
  - Task 1.2
  - Task 2.1
- **Complexity**: 3
- **Acceptance criteria**:
  - Default wait/close paths block skipped/manual source-branch CI with a
    message that mentions target-branch CI and explicit `--skip-pipeline`.
  - `--skip-pipeline` still prints `PIPELINE_STATUS=skipped_by_user_confirmation`.
  - Skill docs state that target-branch CI must be verified after merge when it
    is the real deployment/build gate.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'gitlab_mr and skip_pipeline'`
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`

### Task 2.3: Make Local Cleanup Deterministic

- **Location**:
  - `skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh`
  - `skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh`
- **Description**: Replace attached-target cleanup `git pull --ff-only` with
  explicit `git fetch origin <target_branch>` followed by
  `git merge --ff-only origin/<target_branch>`. Update the duplicated cleanup
  helper in `deliver-gitlab-mr.sh` only if it is still reachable; otherwise
  remove or leave it after confirming no test path uses it.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 4
- **Acceptance criteria**:
  - Close cleanup does not call `git pull`.
  - Close cleanup fast-forwards the local target branch from `origin/<target>`.
  - Close cleanup deletes the local source branch when not on it and
    `--keep-local-branch` is absent.
  - A merged MR plus cleanup failure remains handled as a cleanup warning when
    cleanup cannot be safely completed.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'gitlab_mr and cleanup'`
  - `scripts/check.sh --tests -- tests/test_script_smoke.py -k 'close and gitlab'`

### Task 2.4: Refresh Script Specs And Retained Inbox State

- **Location**:
  - `tests/script_specs/skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh.json`
  - `tests/script_specs/skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh.json`
  - `heuristic-system/error-inbox/deliver-gitlab-mr-skipped-pipeline-and-cleanup.md`
- **Description**: Align script smoke specs with the updated command surface
  and mark the inbox entry lifecycle according to the completed work. During
  plan creation the entry should be `planned`; after implementation and full
  validation it can be promoted separately to an operation record or marked
  `promoted` with durable links.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 2.3
- **Complexity**: 2
- **Acceptance criteria**:
  - Script smoke specs still cover help and at least one safe fixture path per
    GitLab MR script.
  - The inbox entry links this plan while work is pending.
  - No raw `skill-usage.record.json` is committed.
- **Validation**:
  - `bash scripts/ci/stale-skill-scripts-audit.sh --check`
  - `skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh verify heuristic-system/error-inbox/deliver-gitlab-mr-skipped-pipeline-and-cleanup.md`

## Testing Strategy

- Unit:
  - Focused pytest coverage in the two GitLab MR skill test files using fake
    `glab` payloads for top-level and nested pipeline status JSON.
- Integration:
  - Local git fixture coverage for close cleanup with an `origin` remote,
    target branch, source branch, and ambiguous local pull configuration.
- E2E/manual:
  - Optional live GitLab check only when a real MR with skipped source CI and
    target-branch CI is available. Live validation is not required for local
    acceptance because fake `glab` plus git fixtures reproduce the failure
    modes.

## Risks & gotchas

- Changing skipped/manual status handling can accidentally weaken merge safety;
  keep the default as blocked and require explicit `--skip-pipeline`.
- The two scripts duplicate JSON parsing helpers; update both in the same
  change or extract a tiny shared helper only if the repo already has a suitable
  shared shell pattern.
- Cleanup runs after merge, so failures can be misleading. Tests should assert
  MR merge success is not reported as implementation failure solely because
  local cleanup needs repair.
- Fake `glab` fixtures must stay simple and deterministic; avoid live API
  coupling in acceptance tests.
- Do not promote the HEURISTIC_SYSTEM inbox entry until the GitLab script fixes,
  tests, and docs are all validated.

## Rollback plan

- Revert the GitLab MR script/doc/test commit if parsing or cleanup behavior
  regresses.
- Keep the inbox entry linked to this plan with status `planned` or `triaged`
  until a corrected implementation lands.
- If cleanup changes cause unexpected local branch behavior, temporarily use
  `--no-cleanup` and perform manual cleanup with
  `git fetch origin <target> && git merge --ff-only origin/<target>`.
