# Plan: Repository refactor for CI checks, skill script pruning, and docs freshness

## Overview

This plan refactors the repository in four sequential integration sprints. It consolidates CI checks around a single source of truth, removes
obsolete skill scripts without legacy-compatibility guarantees, and updates docs so commands and paths remain accurate after refactors. The
execution model is sequential by sprint, with parallel task lanes only inside each sprint.

## Scope

- In scope:
  - CI check and test workflow consolidation across `.github/workflows` and `scripts/check.sh`.
  - Removal of stale `skills/**/scripts/**` assets that are no longer required by active skill contracts.
  - Full docs accuracy refresh for root docs, runbooks, and testing docs impacted by CI/script changes.
  - Guardrails that prevent CI-check drift, stale scripts, and doc-command drift from reappearing.
- Out of scope:
  - Adding legacy compatibility layers for removed scripts.
  - New product features unrelated to CI/script/docs refactor.
  - Release/publish workflow policy changes not needed for test/check integrity.

## Assumptions

1. Refactor target branch is `main` and this plan is executed in this repository root.
2. Removing unreferenced scripts is acceptable even when historical local aliases break.
3. Existing required pre-merge checks remain at least as strict as current `scripts/check.sh --all`.
4. `nils-cli` (`plan-tooling`) and Python dev dependencies are available during implementation.

## Sprint 1: Baseline and execution map

**Goal**: Produce a deterministic baseline for CI checks, script reachability, and docs references before mutations.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --lint`
  - `scripts/check.sh --tests -- -m script_regression`
  - `plan-tooling validate --file docs/plans/repo-refactor-ci-skills-docs-plan.md`
- Verify:
  - Baseline passes or failures are captured in sprint artifacts under `docs/plans/artifacts/repo-refactor-ci-skills-docs/`.
  - Task dependency graph is executable and split-ready.

**PR grouping intent**: group
**Execution Profile**: parallel-x3

### Task 1.1: Capture baseline check and CI inventory

- **Location**:
  - `.github/workflows/lint.yml`
  - `.github/workflows/api-test-runner.yml`
  - `scripts/check.sh`
  - `scripts/lint.sh`
  - `scripts/test.sh`
  - `DEVELOPMENT.md`
  - `docs/plans/artifacts/repo-refactor-ci-skills-docs/ci-parity-matrix.md`
- **Description**: Build a baseline matrix of all checks/tests currently run locally and in CI, including duplicates and missing parity points.
- **Dependencies**: none
- **Complexity**: 5
- **Acceptance criteria**:
  - A parity matrix exists mapping each CI step to a local command.
  - Duplicate setup/check logic and parity gaps are explicitly listed.
- **Validation**:
  - `test -f docs/plans/artifacts/repo-refactor-ci-skills-docs/ci-parity-matrix.md`
  - `rg -n "CI step|Local command|Parity status" docs/plans/artifacts/repo-refactor-ci-skills-docs/ci-parity-matrix.md`

### Task 1.2: Build CI installation/bootstrap consolidation design

- **Location**:
  - `scripts/install-homebrew-nils-cli.sh`
  - `.github/workflows/lint.yml`
  - `.github/workflows/api-test-runner.yml`
  - `docs/plans/artifacts/repo-refactor-ci-skills-docs/ci-bootstrap-design.md`
- **Description**: Define the target bootstrap pattern so all workflows use one
  installation path for Homebrew + `nils-cli` and shared setup semantics.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - A single preferred bootstrap entrypoint and fallback behavior are specified.
  - Migration order is defined so no workflow is left partially migrated.
- **Validation**:
  - `test -f docs/plans/artifacts/repo-refactor-ci-skills-docs/ci-bootstrap-design.md`
  - `rg -n "Canonical bootstrap|Fallback|Migration order" docs/plans/artifacts/repo-refactor-ci-skills-docs/ci-bootstrap-design.md`

### Task 1.3: Build skill script reachability inventory

- **Location**:
  - `skills/tools/devex/desktop-notify/scripts/codex-notify.sh`
  - `skills/tools/devex/desktop-notify/SKILL.md`
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
  - `skills/automation/gh-fix-ci/SKILL.md`
  - `tests/script_specs/skills/tools/devex/desktop-notify/scripts/desktop-notify.sh.json`
  - `out/tests/script-coverage/summary.json`
  - `docs/plans/artifacts/repo-refactor-ci-skills-docs/skill-script-reachability.md`
- **Description**: Produce a script reachability graph from skill contracts, tests, and script coverage to identify removable stale scripts.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Each tracked script is classified as required, transitional, or removable.
  - Candidate removals include concrete evidence (no contract/test coverage dependency).
- **Validation**:
  - `test -f docs/plans/artifacts/repo-refactor-ci-skills-docs/skill-script-reachability.md`
  - `rg -n "script_path|classification|evidence" docs/plans/artifacts/repo-refactor-ci-skills-docs/skill-script-reachability.md`

### Task 1.4: Build docs accuracy inventory and drift rubric

- **Location**:
  - `README.md`
  - `DEVELOPMENT.md`
  - `docs/runbooks/agent-docs/context-dispatch-matrix.md`
  - `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
  - `docs/testing/script-regression.md`
  - `docs/testing/script-smoke.md`
  - `docs/plans/artifacts/repo-refactor-ci-skills-docs/docs-claim-inventory.md`
- **Description**: Create an inventory of command/path claims in docs and define a drift rubric for outdated content detection.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - A docs claim checklist exists for commands, file paths, and workflow behavior.
  - Priority order is defined for critical docs to update first.
- **Validation**:
  - `test -f docs/plans/artifacts/repo-refactor-ci-skills-docs/docs-claim-inventory.md`
  - `rg -n "Claim|Current state|Drift severity|Owner" docs/plans/artifacts/repo-refactor-ci-skills-docs/docs-claim-inventory.md`

### Sprint 1 PR Group Map

- Group `s1-g1`: Task 1.1 + Task 1.2 (owner: CI lane)
- Group `s1-g2`: Task 1.3 (owner: skill-script lane)
- Group `s1-g3`: Task 1.4 (owner: docs-audit lane)
- Merge order: `s1-g1` first, then `s1-g2` and `s1-g3` in parallel.

### Sprint 1 scorecard

- **Execution Profile**: parallel-x3
- **TotalComplexity**: 19
- **CriticalPathComplexity**: 10
- **MaxBatchWidth**: 3
- **OverlapHotspots**:
  - `DEVELOPMENT.md` and `.github/workflows/lint.yml` touched by Tasks 1.1 and 1.2.
  - Use one owner for final merge of shared CI docs/files.

## Sprint 2: CI check/test consolidation

**Goal**: Make CI checks deterministic, non-duplicated, and aligned with local entrypoints.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --all`
  - `scripts/check.sh --tests -- -m script_smoke`
- Verify:
  - CI workflows invoke consolidated bootstrap/check flows.
  - Required check coverage remains unchanged or stronger.

**PR grouping intent**: group
**Execution Profile**: parallel-x2

### Task 2.1: Centralize workflow bootstrap and tool setup

- **Location**:
  - `scripts/install-homebrew-nils-cli.sh`
  - `.github/workflows/lint.yml`
  - `.github/workflows/api-test-runner.yml`
- **Description**: Replace duplicated inline setup blocks with a shared bootstrap pattern and normalize setup command semantics.
- **Dependencies**:
  - Task 1.2
  - Task 1.3
  - Task 1.4
- **Complexity**: 5
- **Acceptance criteria**:
  - Both workflows rely on one canonical bootstrap implementation.
  - Setup retries and PATH/export behavior are consistent across jobs.
- **Validation**:
  - `rg -n "install-homebrew-nils-cli\.sh" .github/workflows/lint.yml .github/workflows/api-test-runner.yml`

### Task 2.2: Align CI check phases with `scripts/check.sh` modes

- **Location**:
  - `.github/workflows/lint.yml`
  - `scripts/check.sh`
  - `scripts/lint.sh`
  - `scripts/test.sh`
- **Description**: Restructure CI jobs so each phase maps directly to a
  documented `scripts/check.sh` mode to remove drift between local and CI checks.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 5
- **Acceptance criteria**:
  - CI checks can be traced 1:1 to local CLI entrypoints.
  - Redundant ad-hoc checks in workflows are removed.
- **Validation**:
  - `scripts/check.sh --lint`
  - `scripts/check.sh --plans`
  - `scripts/check.sh --env-bools`

### Task 2.3: Normalize test artifacts and summaries across workflows

- **Location**:
  - `.github/workflows/api-test-runner.yml`
  - `docs/testing/script-regression.md`
  - `docs/testing/script-smoke.md`
- **Description**: Standardize artifact paths and summary publication to improve triage consistency across pytest and API test workflows.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Artifact naming and location conventions are consistent and documented.
  - Every relevant workflow emits actionable failure evidence.
- **Validation**:
  - `rg -n "upload-artifact|summary\.md|out/tests|out/api-test-runner" \
    .github/workflows/api-test-runner.yml docs/testing/script-regression.md \
    docs/testing/script-smoke.md`

### Task 2.4: Add CI parity guardrails and regression checks

- **Location**:
  - `tests/test_ci_check_parity.py`
  - `docs/testing/ci-check-parity.md`
  - `.github/workflows/lint.yml`
  - `scripts/check.sh`
- **Description**: Add automated checks that detect divergence between required local checks and workflow-implemented checks.
- **Dependencies**:
  - Task 2.2
  - Task 2.3
- **Complexity**: 3
- **Acceptance criteria**:
  - CI fails when required check phases are missing or renamed without local counterpart updates.
  - Parity guardrails are documented with remediation steps.
- **Validation**:
  - `scripts/check.sh --tests -- -k parity -m script_regression`
  - `scripts/check.sh --all`

### Sprint 2 PR Group Map

- Group `s2-g1`: Task 2.1 + Task 2.2 (owner: CI-core lane)
- Group `s2-g2`: Task 2.3 (owner: artifacts/docs lane)
- Group `s2-g3`: Task 2.4 (owner: parity-gate lane)
- Merge order: `s2-g1` and `s2-g2` after Task 2.1, then `s2-g3`.

### Sprint 2 scorecard

- **Execution Profile**: parallel-x2
- **TotalComplexity**: 17
- **CriticalPathComplexity**: 13
- **MaxBatchWidth**: 2
- **OverlapHotspots**:
  - `scripts/check.sh` overlap between Tasks 2.2 and 2.4.
  - Keep parity gate changes small and merge after CI-core lane.

## Sprint 3: Skill script pruning (no legacy compatibility)

**Goal**: Remove stale skill scripts and tighten contracts/tests so remaining entrypoints are explicit and enforced.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --contracts`
  - `scripts/check.sh --skills-layout`
  - `scripts/check.sh --tests -- -m script_regression`
- Verify:
  - Removed scripts are absent from the tree and no residual references remain.
  - Skill contracts/tests align with the post-prune script set.

**PR grouping intent**: group
**Execution Profile**: parallel-x2

### Task 3.1: Add deterministic stale-script detection rule set

- **Location**:
  - `scripts/ci/stale-skill-scripts-audit.sh`
  - `tests/test_stale_skill_scripts_audit.py`
  - `DEVELOPMENT.md`
- **Description**: Implement and document deterministic criteria to classify stale scripts using contract references, tests, and runtime coverage.
- **Dependencies**:
  - Task 2.4
- **Complexity**: 4
- **Acceptance criteria**:
  - Detection rule set is runnable locally and in CI.
  - Rule output clearly distinguishes removable scripts from active entrypoints.
- **Validation**:
  - `bash scripts/ci/stale-skill-scripts-audit.sh --check`
  - `scripts/check.sh --tests -- -k stale_skill_scripts_audit`

### Task 3.2: Remove stale skill scripts and delete dead references

- **Location**:
  - `skills/tools/devex/desktop-notify/scripts/codex-notify.sh`
  - `skills/tools/devex/desktop-notify/SKILL.md`
  - `skills/tools/devex/desktop-notify/tests/test_tools_devex_desktop_notify.py`
- **Description**: Remove scripts classified as stale (for example currently
  unreferenced wrappers such as `codex-notify.sh`) and clean contract references.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Deleted scripts are removed from git tracking.
  - No stale script path remains in skill contracts.
- **Validation**:
  - `! rg -n "codex-notify\.sh" skills/tools/devex/desktop-notify`
  - `scripts/check.sh --tests -- -m script_regression -k desktop-notify`

### Task 3.3: Rebalance script regression/smoke specs after pruning

- **Location**:
  - `tests/script_specs/scripts/check.sh.json`
  - `tests/script_specs/skills/tools/devex/desktop-notify/scripts/desktop-notify.sh.json`
  - `tests/script_specs/skills/tools/devex/desktop-notify/scripts/project-notify.sh.json`
  - `tests/test_script_smoke.py`
  - `tests/test_script_regression.py`
  - `docs/testing/script-smoke.md`
  - `docs/testing/script-regression.md`
- **Description**: Update regression/smoke specs so coverage metrics reflect the reduced script surface and no orphan specs remain.
- **Dependencies**:
  - Task 3.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Script coverage summary has no removed scripts and no missing regression entries.
  - Smoke expectations are explicit for all remaining critical entrypoints.
- **Validation**:
  - `scripts/check.sh --tests -- -m script_smoke`
  - `scripts/check.sh --tests -- -m script_regression`

### Task 3.4: Enforce script-entrypoint ownership parity gate

- **Location**:
  - `skills/_shared/python/skill_testing/assertions.py`
  - `tests/test_skill_script_entrypoint_ownership.py`
  - `scripts/check.sh`
  - `.github/workflows/lint.yml`
- **Description**: Enforce that every retained skill script has explicit ownership in entrypoint assertions or an approved exclusion.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 4
- **Acceptance criteria**:
  - CI detects newly added unowned scripts.
  - Intentional exclusions are explicit, reviewed, and minimal.
- **Validation**:
  - `scripts/check.sh --tests -- -k entrypoint_ownership`
  - `scripts/check.sh --contracts`

### Sprint 3 PR Group Map

- Group `s3-g1`: Task 3.1 (owner: detection lane)
- Group `s3-g2`: Task 3.2 + Task 3.3 (owner: removal and coverage lane)
- Group `s3-g3`: Task 3.4 (owner: ownership-gate lane)
- Merge order: `s3-g1` first, then `s3-g2` and `s3-g3` in parallel.

### Sprint 3 scorecard

- **Execution Profile**: parallel-x2
- **TotalComplexity**: 16
- **CriticalPathComplexity**: 12
- **MaxBatchWidth**: 2
- **OverlapHotspots**:
  - `scripts/check.sh` overlap between Tasks 3.4 and existing CI checks.
  - `docs/testing/script-*.md` overlap between Task 3.3 and Sprint 4 docs work.

## Sprint 4: Documentation correction and freshness enforcement

**Goal**: Update all affected docs and add checks that prevent future command/path drift.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --markdown`
  - `scripts/check.sh --third-party`
  - `scripts/check.sh --all`
- Verify:
  - README, runbooks, and testing docs align with refactored scripts/workflows.
  - Doc freshness checks fail on stale command/path references.

**PR grouping intent**: group
**Execution Profile**: parallel-x2

### Task 4.1: Implement docs command/path verification helper

- **Location**:
  - `scripts/ci/docs-freshness-audit.sh`
  - `tests/test_docs_freshness_audit.py`
  - `docs/plans/artifacts/repo-refactor-ci-skills-docs/docs-freshness-rules.md`
- **Description**: Add an automated helper that checks documented commands and critical paths against the current repository layout.
- **Dependencies**:
  - Task 3.3
  - Task 3.4
- **Complexity**: 4
- **Acceptance criteria**:
  - Helper flags stale commands and missing paths in scoped docs.
  - Rule coverage and false-positive policy are documented.
- **Validation**:
  - `bash scripts/ci/docs-freshness-audit.sh --check`
  - `scripts/check.sh --tests -- -k docs_freshness_audit`

### Task 4.2: Wire docs freshness helper into local and CI gates

- **Location**:
  - `scripts/check.sh`
  - `.github/workflows/lint.yml`
  - `DEVELOPMENT.md`
- **Description**: Integrate docs freshness verification into local checks and CI, including failure messaging and remediation hints.
- **Dependencies**:
  - Task 4.1
- **Complexity**: 3
- **Acceptance criteria**:
  - Lint workflow fails when docs freshness audit fails.
  - Development guide includes the docs freshness command in the required check list.
- **Validation**:
  - `scripts/check.sh --all`
  - `rg -n "docs-freshness-audit|--docs" scripts/check.sh .github/workflows/lint.yml DEVELOPMENT.md`

### Task 4.3: Update root and workflow docs to current behavior

- **Location**:
  - `README.md`
  - `DEVELOPMENT.md`
  - `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
- **Description**: Rewrite root-level and workflow guidance to match consolidated CI checks and post-prune script topology.
- **Dependencies**:
  - Task 4.2
  - Task 2.4
- **Complexity**: 4
- **Acceptance criteria**:
  - Core getting-started and required-check commands are accurate and runnable.
  - Removed script names are no longer recommended.
- **Validation**:
  - `! rg -n "codex-notify\.sh" README.md DEVELOPMENT.md docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
  - `scripts/check.sh --markdown`

### Task 4.4: Update skills/testing docs and completion checklist

- **Location**:
  - `docs/testing/script-regression.md`
  - `docs/testing/script-smoke.md`
  - `docs/testing/ci-check-parity.md`
  - `skills/tools/devex/desktop-notify/SKILL.md`
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
- **Description**: Update skill/testing docs so examples reference only active scripts and add a docs completion checklist for future refactors.
- **Dependencies**:
  - Task 4.2
  - Task 3.3
- **Complexity**: 4
- **Acceptance criteria**:
  - Skill docs use currently supported script entrypoints.
  - Testing docs and checklist align with current artifact paths and gates.
- **Validation**:
  - `rg -n "scripts/|out/tests/|api-test-runner|ci-check-parity" \
    docs/testing/script-regression.md docs/testing/script-smoke.md \
    docs/testing/ci-check-parity.md skills/tools/devex/desktop-notify/SKILL.md \
    skills/workflows/plan/create-plan-rigorous/SKILL.md`
  - `scripts/check.sh --markdown`

### Sprint 4 PR Group Map

- Group `s4-g1`: Task 4.1 + Task 4.2 (owner: docs-gate lane)
- Group `s4-g2`: Task 4.3 (owner: root-docs lane)
- Group `s4-g3`: Task 4.4 (owner: skills/testing-docs lane)
- Merge order: `s4-g1` first, then `s4-g2` and `s4-g3` in parallel.

### Sprint 4 scorecard

- **Execution Profile**: parallel-x2
- **TotalComplexity**: 15
- **CriticalPathComplexity**: 11
- **MaxBatchWidth**: 2
- **OverlapHotspots**:
  - `DEVELOPMENT.md` overlap between Tasks 4.2 and 4.3.
  - `docs/testing/ci-check-parity.md` overlap between Tasks 4.3 and 4.4.

## Testing Strategy

- Unit:
  - Extend `tests/` for parity guardrails, stale-script detection, entrypoint ownership checks, and docs freshness helpers.
- Integration:
  - Run `scripts/check.sh --all` as the mandatory integration gate after each sprint integration.
- E2E/manual:
  - Validate representative workflows via `scripts/check.sh --tests -- -m script_smoke` and inspect `out/tests/**` artifact summaries.

## Risks & gotchas

- File-overlap conflicts in `.github/workflows/lint.yml`, `scripts/check.sh`, and `DEVELOPMENT.md` can cause frequent rebases.
- Removing scripts without compatibility may break undocumented personal aliases; communicate removals in changelog/docs.
- CI parity tests can become brittle if workflow naming changes; assert required phases/behaviors rather than exact step text.
- Docs freshness checks can be noisy if scope is too broad; start with critical docs and expand once false positives are tuned.

## Rollback plan

1. Tag each sprint merge point before the next sprint starts.
2. If a sprint causes unstable CI, revert only sprint-specific PR groups and rerun `scripts/check.sh --all`.
3. If script removals break required flows, restore removed scripts from the previous sprint tag in a dedicated rollback PR, rerun stale-script
   audit, then re-remove with corrected evidence.
4. If docs freshness gate is too strict, temporarily keep the helper but downgrade CI gate to non-blocking for one cycle, then restore blocking
   status after false positives are fixed.
