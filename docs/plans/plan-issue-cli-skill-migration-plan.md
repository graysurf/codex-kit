# Plan: Plan-issue CLI migration for plan issue delivery skills

## Overview
This plan migrates plan-issue delivery orchestration skills from legacy shell wrappers to the Rust binaries `plan-issue` and `plan-issue-local`. The target state removes legacy script entrypoints, rewrites affected skill contracts to binary-first command usage, and preserves the orchestration-only role boundary for main-agent. Sprints are sequential integration gates; parallelism is optimized only inside each sprint.

## Scope
- In scope:
  - Rewrite all `plan-issue-delivery-loop` related skill contracts to use `plan-issue` / `plan-issue-local` command surface.
  - Remove deprecated shell wrappers in affected skills.
  - Update dependent tests and docs that currently assert legacy script paths/behavior.
  - Keep command examples and validation flow aligned with the typed Rust CLI contract.
- Out of scope:
  - Implement new features in `/Users/terry/Project/graysurf/nils-cli/crates/plan-issue-cli`.
  - Change GitHub policy/gates beyond what `plan-issue` already enforces.
  - Re-architect unrelated PR workflows outside this migration.

## Assumptions
1. `plan-issue` and `plan-issue-local` are installed on `PATH` in this repo environment.
2. `plan-tooling`, `pytest`, `git`, and `gh` remain available for validation.
3. Deleting legacy wrappers is acceptable as a breaking change for downstream references in this repo.
4. For plan orchestration, `plan-issue` is the canonical command contract; any legacy wrapper behavior not present in the Rust CLI will be removed, not reintroduced via new shell scripts.

## Sprint sequencing gates
1. Sprint 2 starts only after Sprint 1 is merged and accepted.
2. Sprint 3 starts only after Sprint 2 is merged and accepted.

## Success criteria
- Skill docs no longer require these deleted entrypoints:
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh`
  - `skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh`
  - `skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh`
- `plan-issue-delivery-loop` skill contract and command examples are fully binary-first (`plan-issue`, `plan-issue-local`).
- Related skills inventory is explicit and reflected in updated docs/tests.
- All affected tests pass after contract updates.

## Sprint 1: Inventory and contract rewrite
**Goal**: Freeze migration surface and rewrite top-level orchestration contracts to Rust CLI usage.
**PR Grouping Intent**: per-sprint
**Execution Profile**: parallel-x2 (intended width: 2)
**Sprint Scorecard**:
- `TotalComplexity`: 11
- `CriticalPathComplexity`: 7
- `MaxBatchWidth`: 2
- `OverlapHotspots`: `skills/automation/plan-issue-delivery-loop/SKILL.md`, `skills/automation/issue-delivery-loop/SKILL.md`
**Demo/Validation**:
- Command(s):
  - `plan-tooling validate --file docs/plans/plan-issue-cli-skill-migration-plan.md`
  - `plan-tooling to-json --file docs/plans/plan-issue-cli-skill-migration-plan.md --sprint 1`
  - `plan-tooling batches --file docs/plans/plan-issue-cli-skill-migration-plan.md --sprint 1`
  - `plan-tooling split-prs --file docs/plans/plan-issue-cli-skill-migration-plan.md --scope sprint --sprint 1 --pr-grouping per-sprint --strategy deterministic --format json`
- Verify:
  - Migration inventory includes every impacted skill, test, doc, and script path.
  - `plan-issue-delivery-loop` and `issue-delivery-loop` skills point to `plan-issue` command usage, not legacy wrappers.
**Parallelizable tasks**:
- `Task 1.2` and `Task 1.3` can run in parallel after `Task 1.1`.

### Task 1.1: Build migration inventory and command parity matrix
- **Location**:
  - `docs/migrations/plan-issue-cli-skill-mapping.md`
  - `skills/automation/plan-issue-delivery-loop/SKILL.md`
  - `skills/automation/issue-delivery-loop/SKILL.md`
  - `skills/workflows/issue/issue-subagent-pr/SKILL.md`
  - `skills/workflows/issue/issue-pr-review/SKILL.md`
  - `skills/automation/plan-issue-delivery-loop/tests/test_automation_plan_issue_delivery_loop.py`
  - `skills/automation/issue-delivery-loop/tests/test_automation_issue_delivery_loop.py`
  - `skills/workflows/issue/issue-subagent-pr/tests/test_workflows_issue_issue_subagent_pr.py`
  - `skills/workflows/issue/issue-pr-review/tests/test_workflows_issue_issue_pr_review.py`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
- **Description**: Produce a definitive migration matrix (`old script command -> new binary command`) and an explicit impacted-skills inventory to drive all subsequent edits.
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - Inventory lists all directly impacted skills and transitive dependencies.
  - Mapping covers each migrated command family (`start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`, `ready-plan`, `close-plan`, status/build commands).
- **Validation**:
  - `rg -n 'manage_issue_delivery_loop\.sh|manage_issue_subagent_pr\.sh|plan-issue-delivery-loop\.sh' skills docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `rg -n '^\\| Legacy Command \\| New Command \\| Scope \\|$|start-plan|start-sprint|ready-sprint|accept-sprint|ready-plan|close-plan' docs/migrations/plan-issue-cli-skill-mapping.md`

### Task 1.2: Rewrite plan-issue-delivery-loop skill contract to binary-first
- **Location**:
  - `skills/automation/plan-issue-delivery-loop/SKILL.md`
- **Description**: Replace legacy script prereqs/entrypoint sections with the Rust CLI contract (`plan-issue`, `plan-issue-local`), including dry-run/local rehearsal behavior and required grouping controls.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - SKILL contract references only `plan-issue`/`plan-issue-local` as orchestration entrypoints.
  - Workflow and completion policy keep existing gate semantics and role boundaries.
  - No references remain to `plan-issue-delivery-loop.sh` or inherited shell wrappers.
- **Validation**:
  - `rg -n 'plan-issue|plan-issue-local|start-plan|start-sprint|ready-sprint|accept-sprint|ready-plan|close-plan' skills/automation/plan-issue-delivery-loop/SKILL.md`
  - `rg -n 'plan-issue-delivery-loop\.sh|manage_issue_delivery_loop\.sh|manage_issue_subagent_pr\.sh' skills/automation/plan-issue-delivery-loop/SKILL.md && exit 1 || true`

### Task 1.3: Rewrite issue-delivery-loop skill to align with plan-issue orchestration boundary
- **Location**:
  - `skills/automation/issue-delivery-loop/SKILL.md`
- **Description**: Retire direct dependency on `manage_issue_delivery_loop.sh`; document orchestration through typed CLI flows and keep `issue-pr-review` as review decision path.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - SKILL no longer declares the deleted script as required entrypoint.
  - Main-agent orchestration-only contract remains explicit.
  - Command examples are executable with currently supported binaries/tools.
- **Validation**:
  - `rg -n 'plan-issue|plan-issue-local|status-plan|ready-plan|close-plan|issue-pr-review' skills/automation/issue-delivery-loop/SKILL.md`
  - `rg -n 'manage_issue_delivery_loop\.sh' skills/automation/issue-delivery-loop/SKILL.md && exit 1 || true`

## Sprint 2: Script removal and dependency rewiring
**Goal**: Delete legacy wrappers and remove hard runtime dependencies on those files.
**PR Grouping Intent**: per-sprint
**Start gate**: Sprint 1 merged and accepted.
**Execution Profile**: parallel-x2 (intended width: 2)
**Sprint Scorecard**:
- `TotalComplexity`: 16
- `CriticalPathComplexity`: 13
- `MaxBatchWidth`: 2
- `OverlapHotspots`: `skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh`, legacy script deletion paths, dependent tests
**Demo/Validation**:
- Command(s):
  - `plan-tooling to-json --file docs/plans/plan-issue-cli-skill-migration-plan.md --sprint 2`
  - `plan-tooling batches --file docs/plans/plan-issue-cli-skill-migration-plan.md --sprint 2`
  - `plan-tooling split-prs --file docs/plans/plan-issue-cli-skill-migration-plan.md --scope sprint --sprint 2 --pr-grouping per-sprint --strategy deterministic --format json`
- Verify:
  - Legacy script files are removed from the repository.
  - No remaining runtime path resolution points to deleted scripts.
  - Tests reflect the new command contract without script-content assertions.
**Parallelizable tasks**:
- `Task 2.2` and `Task 2.3` can run in parallel after `Task 2.1`.

### Task 2.1: Delete deprecated plan/issue shell wrappers
- **Location**:
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh`
  - `skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh`
  - `skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh`
- **Description**: Remove all legacy shell entrypoints that are superseded by the Rust `plan-issue` command contract.
- **Dependencies**: none
- **Complexity**: 4
- **Acceptance criteria**:
  - All three files are deleted from git tracking.
- **Validation**:
  - `test ! -f skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh`
  - `test ! -f skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh`
  - `test ! -f skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh`

### Task 2.2: Rewire issue-subagent-pr contract away from deleted script dependency
- **Location**:
  - `skills/workflows/issue/issue-subagent-pr/SKILL.md`
- **Description**: Convert `issue-subagent-pr` to a scriptless, explicit command-contract skill (native `git`/`gh` steps + `plan-issue` artifacts where applicable), and remove legacy entrypoint requirements from the skill contract.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 3
- **Acceptance criteria**:
  - `issue-subagent-pr` contract does not require a removed entrypoint.
- **Validation**:
  - `rg -n 'git|gh|plan-issue' skills/workflows/issue/issue-subagent-pr/SKILL.md`
  - `rg -n 'manage_issue_subagent_pr\.sh' skills/workflows/issue/issue-subagent-pr/SKILL.md && exit 1 || true`

### Task 2.3: Rewire issue-pr-review runtime gate away from deleted subagent script
- **Location**:
  - `skills/workflows/issue/issue-pr-review/SKILL.md`
  - `skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh`
- **Description**: Update `issue-pr-review` so PR body hygiene validation is self-contained and no longer shells out to `manage_issue_subagent_pr.sh`.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 4
- **Acceptance criteria**:
  - `issue-pr-review` skill contract reflects the new self-contained validation behavior.
  - `manage_issue_pr_review.sh` does not reference deleted script paths.
  - Runtime behavior for merge/close hygiene remains deterministic.
- **Validation**:
  - `rg -n 'manage_issue_subagent_pr\.sh' skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh && exit 1 || true`
  - `rg -n 'PR body|hygiene|validation' skills/workflows/issue/issue-pr-review/SKILL.md`

### Task 2.4: Update migration-affected tests for binary-first contracts
- **Location**:
  - `skills/automation/plan-issue-delivery-loop/tests/test_automation_plan_issue_delivery_loop.py`
  - `skills/automation/issue-delivery-loop/tests/test_automation_issue_delivery_loop.py`
  - `skills/workflows/issue/issue-subagent-pr/tests/test_workflows_issue_issue_subagent_pr.py`
  - `skills/workflows/issue/issue-pr-review/tests/test_workflows_issue_issue_pr_review.py`
- **Description**: Replace script-content assertions and script-entrypoint existence checks with binary-contract assertions and SKILL contract invariants.
- **Dependencies**:
  - Task 2.2
  - Task 2.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Tests no longer require removed script files.
  - Tests enforce `plan-issue`/`plan-issue-local` references where expected.
  - Updated tests pass locally.
- **Validation**:
  - `scripts/test.sh skills/automation/plan-issue-delivery-loop/tests/test_automation_plan_issue_delivery_loop.py skills/automation/issue-delivery-loop/tests/test_automation_issue_delivery_loop.py skills/workflows/issue/issue-subagent-pr/tests/test_workflows_issue_issue_subagent_pr.py skills/workflows/issue/issue-pr-review/tests/test_workflows_issue_issue_pr_review.py`

## Sprint 3: Documentation sync and local rehearsal hardening
**Goal**: Remove stale references, codify local-first rehearsal, and finish end-to-end validation.
**PR Grouping Intent**: per-sprint
**Start gate**: Sprint 2 merged and accepted.
**Execution Profile**: parallel-x2 (intended width: 2)
**Sprint Scorecard**:
- `TotalComplexity`: 11
- `CriticalPathComplexity`: 8
- `MaxBatchWidth`: 2
- `OverlapHotspots`: docs references under `docs/runbooks/skills/`, sprint-flow examples in `skills/automation/plan-issue-delivery-loop/SKILL.md`
**Demo/Validation**:
- Command(s):
  - `plan-tooling to-json --file docs/plans/plan-issue-cli-skill-migration-plan.md --sprint 3`
  - `plan-tooling batches --file docs/plans/plan-issue-cli-skill-migration-plan.md --sprint 3`
  - `plan-tooling split-prs --file docs/plans/plan-issue-cli-skill-migration-plan.md --scope sprint --sprint 3 --pr-grouping per-sprint --strategy deterministic --format json`
  - `plan-tooling split-prs --file docs/plans/plan-issue-cli-skill-migration-plan.md --scope sprint --sprint 3 --pr-grouping group --strategy deterministic --pr-group S3T1=s3-docs --pr-group S3T2=s3-guidance --pr-group S3T3=s3-validation --format json`
  - `plan-issue-local multi-sprint-guide --plan docs/plans/plan-issue-cli-skill-migration-plan.md --dry-run --format json`
- Verify:
  - Tooling index and sample plans no longer point to deleted scripts.
  - Local rehearsal flow can run without GitHub mutations.
  - End-state docs accurately describe live mode (`plan-issue`) and local mode (`plan-issue-local`).
**Parallelizable tasks**:
- `Task 3.1` and `Task 3.2` can run in parallel before `Task 3.3`.

### Task 3.1: Update tooling index and stale docs references
- **Location**:
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `docs/plans/duck-issue-loop-test-plan.md`
- **Description**: Replace stale script entrypoint references with binary-first command references and update command examples accordingly.
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - No deleted script paths remain in targeted docs.
  - Tooling index reflects `plan-issue` and `plan-issue-local` usage paths.
- **Validation**:
  - `rg -n 'plan-issue-delivery-loop\.sh|manage_issue_delivery_loop\.sh|manage_issue_subagent_pr\.sh' docs/runbooks/skills/TOOLING_INDEX_V2.md docs/plans/duck-issue-loop-test-plan.md && exit 1 || true`
  - `rg -n 'plan-issue|plan-issue-local' docs/runbooks/skills/TOOLING_INDEX_V2.md docs/plans/duck-issue-loop-test-plan.md`

### Task 3.2: Harden local rehearsal guidance in plan-issue-delivery-loop skill
- **Location**:
  - `skills/automation/plan-issue-delivery-loop/SKILL.md`
- **Description**: Make local-first practice explicit with `plan-issue-local` command sequence, required `--body-file` dry-run gates, and expected outputs for non-GitHub rehearsal.
- **Dependencies**: none
- **Complexity**: 4
- **Acceptance criteria**:
  - SKILL includes complete local rehearsal path from `start-plan` through `close-plan` dry-run semantics.
  - Distinction between live and local binaries is explicit and non-ambiguous.
- **Validation**:
  - `rg -n 'plan-issue-local|--body-file|--dry-run|start-plan|start-sprint|ready-sprint|accept-sprint|ready-plan|close-plan' skills/automation/plan-issue-delivery-loop/SKILL.md`

### Task 3.3: Final validation pass and migration closure checks
- **Location**:
  - `skills/automation/plan-issue-delivery-loop/SKILL.md`
  - `skills/automation/issue-delivery-loop/SKILL.md`
  - `skills/workflows/issue/issue-subagent-pr/SKILL.md`
  - `skills/workflows/issue/issue-pr-review/SKILL.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
- **Description**: Run final checks for contract validity, test pass status, and repository-wide removal of deprecated script references in migrated surface.
- **Dependencies**:
  - Task 3.1
  - Task 3.2
- **Complexity**: 4
- **Acceptance criteria**:
  - `validate_skill_contracts.sh` passes for edited skills.
  - Migration-target tests are green.
  - No stale references remain in migrated skill/doc scope.
- **Validation**:
  - `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/automation/plan-issue-delivery-loop/SKILL.md --file skills/automation/issue-delivery-loop/SKILL.md --file skills/workflows/issue/issue-subagent-pr/SKILL.md --file skills/workflows/issue/issue-pr-review/SKILL.md`
  - `scripts/test.sh skills/automation/plan-issue-delivery-loop/tests/test_automation_plan_issue_delivery_loop.py skills/automation/issue-delivery-loop/tests/test_automation_issue_delivery_loop.py skills/workflows/issue/issue-subagent-pr/tests/test_workflows_issue_issue_subagent_pr.py skills/workflows/issue/issue-pr-review/tests/test_workflows_issue_issue_pr_review.py`
  - `rg -n 'plan-issue-delivery-loop\.sh|manage_issue_delivery_loop\.sh|manage_issue_subagent_pr\.sh' skills/automation/plan-issue-delivery-loop skills/automation/issue-delivery-loop skills/workflows/issue/issue-subagent-pr skills/workflows/issue/issue-pr-review docs/runbooks/skills/TOOLING_INDEX_V2.md && exit 1 || true`

## Testing Strategy
- Unit:
  - Run focused skill tests for the four impacted skill directories.
- Integration:
  - Validate plan format and per-sprint split determinism via `plan-tooling validate|to-json|batches|split-prs`.
  - Validate `plan-issue-local` dry-run orchestration command flow for offline rehearsal.
- E2E/manual:
  - In a real repo, run one full sprint with `plan-issue` live mode and verify issue/task table updates, sprint gates, and review/acceptance flow.

## Risks & gotchas
- `issue-pr-review` currently calls the deleted `manage_issue_subagent_pr.sh` for PR-body validation; this must be replaced before script deletion lands.
- Removing script entrypoints is a breaking change for any undocumented external callers.
- If docs/tests are updated before dependency rewiring, CI may fail due to dangling runtime references.
- Grouping behavior (`--pr-grouping group`) must keep full task coverage via explicit `--pr-group` mappings in deterministic mode.

## Rollback plan
- Keep migration changes split by sprint/PR so each layer can be reverted independently.
- If script deletion causes unexpected runtime regressions, temporarily restore only the affected script(s) from the previous commit while preserving updated docs/tests in a separate revert PR.
- If `issue-pr-review` rewiring is unstable, disable merge/close automation changes first and keep review workflow read-only until validation is fixed.
- If the full migration must pause, keep `plan-issue-delivery-loop` skill in binary-first mode and mark other impacted skills as follow-up items in a tracked issue.
