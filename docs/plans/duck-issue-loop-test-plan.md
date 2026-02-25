# Plan: Duck plan for plan issue delivery loop

## Overview
This plan creates disposable test deliverables under `tests/issues/duck-loop/` to validate `plan-issue` / `plan-issue-local` orchestration using three distinct execution profiles. The three sprints intentionally cover both supported grouping styles and avoid ambiguous naming between task summaries and grouping behavior.

## Scope
- In scope:
  - Create sprint-scoped fixture content only under `tests/issues/duck-loop/`.
  - Validate three explicit execution profiles:
    - Sprint 1: `per-sprint`.
    - Sprint 2: `group` with one shared pair.
    - Sprint 3: `group` with all tasks isolated.
  - Generate task-spec artifacts in `$AGENT_HOME/out/plan-issue-delivery-loop/` during validation.
- Out of scope:
  - Any production logic changes outside `tests/issues/duck-loop/`.
  - Permanent docs updates outside this plan file.
  - Automating cleanup in this phase (manual cleanup is documented only).

## Assumptions
1. `plan-tooling` and `python3` are available on `PATH`.
2. `plan-issue` and `plan-issue-local` are available on `PATH` in this repo.
3. GitHub approval/merge gates are validated when the orchestration workflow runs, not in this planning step.

## Success criteria
- The plan has 3 sprints and each sprint validates one explicit execution profile.
- Sprint 1 (`per-sprint`) produces exactly one `pr_group` value for all sprint tasks.
- Sprint 2 (`group`) produces one isolated task group plus one shared two-task group.
- Sprint 3 (`group`) produces all isolated groups (no shared group).
- Task summaries, task descriptions, and grouping commands are semantically aligned (no "single-task PR" wording inside a `per-sprint` sprint).
- All implementation artifacts are isolated under `tests/issues/duck-loop/`.

## Sprint 1: Per-sprint baseline
**Goal**: Validate pure `per-sprint` orchestration with naming/content explicitly aligned to per-sprint execution.
**Demo/Validation**:
- Command(s):
  - `plan-tooling validate --file docs/plans/duck-issue-loop-test-plan.md`
  - `plan-issue-local build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 1 --pr-grouping per-sprint --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s1-per-sprint.tsv" --dry-run`
  - `python3 - <<'PY'\nimport csv\nfrom pathlib import Path\nrows=list(csv.reader(Path("$AGENT_HOME/out/plan-issue-delivery-loop/duck-s1-per-sprint.tsv").open(), delimiter="\t"))\ndata=[r for r in rows if r and not r[0].startswith("#")]\ngroups={r[6] for r in data}\nassert len(groups)==1, groups\nprint("ok")\nPY`
- Verify:
  - Sprint 1 task-spec file exists under `$AGENT_HOME/out/plan-issue-delivery-loop/`.
  - All Sprint 1 rows share one `pr_group`.
**Parallelizable tasks**:
- `Task 1.2` and `Task 1.3` can run in parallel after `Task 1.1`.

### Task 1.1: Create disposable duck-loop root and execution matrix notes
- **Location**:
  - `tests/issues/duck-loop/README.md`
  - `tests/issues/duck-loop/CLEANUP.md`
- **Description**: Create the root fixture directory with purpose, execution-profile matrix (`per-sprint`, `group-shared`, `group-isolated`), and one-command cleanup instruction (`rm -rf tests/issues/duck-loop`).
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - Root README states this folder is test-only and disposable.
  - Root README lists the three execution profiles by name.
  - Cleanup doc includes explicit removal command.
- **Validation**:
  - `test -f tests/issues/duck-loop/README.md && test -f tests/issues/duck-loop/CLEANUP.md`
  - `rg -n 'per-sprint|group-shared|group-isolated' tests/issues/duck-loop/README.md`
  - `rg -n 'rm -rf tests/issues/duck-loop' tests/issues/duck-loop/CLEANUP.md`

### Task 1.2: Sprint 1 per-sprint fixture part A
- **Location**:
  - `tests/issues/duck-loop/sprint1/per-sprint/task-a.md`
- **Description**: Add Sprint 1 fixture content for `per-sprint` mode, including an explicit `execution-profile: per-sprint` marker.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists and includes `execution-profile: per-sprint`.
  - File references Sprint 1 per-sprint baseline.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint1/per-sprint/task-a.md`
  - `rg -n 'execution-profile: per-sprint' tests/issues/duck-loop/sprint1/per-sprint/task-a.md`

### Task 1.3: Sprint 1 per-sprint fixture part B
- **Location**:
  - `tests/issues/duck-loop/sprint1/per-sprint/task-b.md`
- **Description**: Add second Sprint 1 per-sprint fixture file to verify same-group multi-task delivery under one sprint-level PR group.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists and includes `execution-profile: per-sprint`.
  - File identifies itself as Sprint 1 per-sprint part B.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint1/per-sprint/task-b.md`
  - `rg -n 'part: B|execution-profile: per-sprint' tests/issues/duck-loop/sprint1/per-sprint/task-b.md`

## Sprint 2: Group mode with shared pair
**Goal**: Validate `group` mode with one isolated task plus one shared two-task group.
**Demo/Validation**:
- Command(s):
  - `plan-issue-local build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 2 --pr-grouping group --pr-group S2T1=s2-isolated --pr-group S2T2=s2-shared --pr-group S2T3=s2-shared --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s2-group-shared.tsv" --dry-run`
  - `python3 - <<'PY'\nimport csv\nfrom pathlib import Path\nrows=list(csv.reader(Path("$AGENT_HOME/out/plan-issue-delivery-loop/duck-s2-group-shared.tsv").open(), delimiter="\t"))\ndata=[r for r in rows if r and not r[0].startswith("#")]\ngroups=[r[6] for r in data]\nassert groups.count("s2-shared")==2, groups\nassert groups.count("s2-isolated")==1, groups\nprint("ok")\nPY`
- Verify:
  - Sprint 2 group output has one isolated group (`s2-isolated`) and one shared pair (`s2-shared`).
**Parallelizable tasks**:
- `Task 2.1` and `Task 2.2` can run in parallel.
- `Task 2.3` depends on `Task 2.2`.

### Task 2.1: Sprint 2 group isolated fixture
- **Location**:
  - `tests/issues/duck-loop/sprint2/group-shared/isolated/task.md`
- **Description**: Create the Sprint 2 fixture that is intentionally mapped to an isolated group (`s2-isolated`) in `group` mode.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with `execution-profile: group`.
  - File includes `planned-pr-group: s2-isolated`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint2/group-shared/isolated/task.md`
  - `rg -n 'execution-profile: group|planned-pr-group: s2-isolated' tests/issues/duck-loop/sprint2/group-shared/isolated/task.md`

### Task 2.2: Sprint 2 group shared fixture part A
- **Location**:
  - `tests/issues/duck-loop/sprint2/group-shared/shared/task-a.md`
- **Description**: Create part A of the shared pair that must be mapped to `s2-shared` under `group` mode.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with `execution-profile: group`.
  - File includes `planned-pr-group: s2-shared` and `part: A`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint2/group-shared/shared/task-a.md`
  - `rg -n 'planned-pr-group: s2-shared|part: A' tests/issues/duck-loop/sprint2/group-shared/shared/task-a.md`

### Task 2.3: Sprint 2 group shared fixture part B
- **Location**:
  - `tests/issues/duck-loop/sprint2/group-shared/shared/task-b.md`
- **Description**: Create part B of the shared pair and encode dependency on Task 2.2 to preserve ordered execution within the shared group.
- **Dependencies**:
  - Task 2.2
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with `execution-profile: group`.
  - File includes `planned-pr-group: s2-shared` and `depends-on: Task 2.2`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint2/group-shared/shared/task-b.md`
  - `rg -n 'planned-pr-group: s2-shared|depends-on: Task 2.2' tests/issues/duck-loop/sprint2/group-shared/shared/task-b.md`

## Sprint 3: Group mode with all isolated tasks
**Goal**: Validate `group` mode where every task is explicitly isolated (no shared pair), and finalize cleanup manifest indexing.
**Demo/Validation**:
- Command(s):
  - `plan-issue-local build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 3 --pr-grouping group --pr-group S3T1=s3-a --pr-group S3T2=s3-b --pr-group S3T3=s3-c --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s3-group-isolated.tsv" --dry-run`
  - `python3 - <<'PY'\nimport csv\nfrom pathlib import Path\nrows=list(csv.reader(Path("$AGENT_HOME/out/plan-issue-delivery-loop/duck-s3-group-isolated.tsv").open(), delimiter="\t"))\ndata=[r for r in rows if r and not r[0].startswith("#")]\ngroups=[r[6] for r in data]\nassert len(set(groups))==3, groups\nprint("ok")\nPY`
- Verify:
  - Sprint 3 group output has three unique groups (`s3-a`, `s3-b`, `s3-c`).
  - Cleanup manifest includes all profile directories.
**Parallelizable tasks**:
- `Task 3.1` and `Task 3.2` can run in parallel.
- `Task 3.3` depends on both `Task 3.1` and `Task 3.2`.

### Task 3.1: Sprint 3 isolated group fixture A
- **Location**:
  - `tests/issues/duck-loop/sprint3/group-isolated/task-a.md`
- **Description**: Create isolated group fixture A for Sprint 3, mapped to `s3-a`.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with `execution-profile: group`.
  - File includes `planned-pr-group: s3-a`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint3/group-isolated/task-a.md`
  - `rg -n 'execution-profile: group|planned-pr-group: s3-a' tests/issues/duck-loop/sprint3/group-isolated/task-a.md`

### Task 3.2: Sprint 3 isolated group fixture B
- **Location**:
  - `tests/issues/duck-loop/sprint3/group-isolated/task-b.md`
- **Description**: Create isolated group fixture B for Sprint 3, mapped to `s3-b`.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with `execution-profile: group`.
  - File includes `planned-pr-group: s3-b`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint3/group-isolated/task-b.md`
  - `rg -n 'execution-profile: group|planned-pr-group: s3-b' tests/issues/duck-loop/sprint3/group-isolated/task-b.md`

### Task 3.3: Sprint 3 isolated group fixture C and cleanup index
- **Location**:
  - `tests/issues/duck-loop/sprint3/group-isolated/task-c.md`
  - `tests/issues/duck-loop/CLEANUP.md`
- **Description**: Create isolated group fixture C for Sprint 3, mapped to `s3-c`, and update cleanup notes with all profile directories for one-shot teardown.
- **Dependencies**:
  - Task 3.1
  - Task 3.2
- **Complexity**: 3
- **Acceptance criteria**:
  - `task-c.md` exists and includes `planned-pr-group: s3-c`.
  - Cleanup notes list `sprint1/per-sprint`, `sprint2/group-shared`, and `sprint3/group-isolated` plus root delete command.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint3/group-isolated/task-c.md`
  - `rg -n 'planned-pr-group: s3-c' tests/issues/duck-loop/sprint3/group-isolated/task-c.md`
  - `rg -n 'sprint1/per-sprint|sprint2/group-shared|sprint3/group-isolated' tests/issues/duck-loop/CLEANUP.md`

## Testing Strategy
- Unit:
  - Not applicable (fixture-content plan only).
- Integration:
  - Sprint 1: run `build-task-spec` with `per-sprint` and assert single group.
  - Sprint 2: run `build-task-spec` with `group` and assert one shared pair + one isolated task.
  - Sprint 3: run `build-task-spec` with `group` and assert all tasks isolated.
  - Run `plan-tooling validate --file docs/plans/duck-issue-loop-test-plan.md` before orchestration.
- E2E/manual:
  - Execute full issue loop with mode transitions by sprint:
    - Sprint 1 with `--pr-grouping per-sprint`.
    - Sprint 2 with `--pr-grouping group` + Sprint 2 `--pr-group` mappings.
    - Sprint 3 with `--pr-grouping group` + Sprint 3 isolated `--pr-group` mappings.
  - Main-agent must review sprint PR content, approve, merge sprint PRs, then run sprint acceptance; do not start sprint N+1 before sprint N is merged and marked done.
  - Confirm issue table `Execution Mode` reflects:
    - `per-sprint` for Sprint 1.
    - `pr-shared` for shared-group rows and `pr-isolated` for isolated-group rows in Sprint 2/3.
  - After final verification, remove `tests/issues/duck-loop/` in one command.

## Risks & gotchas
- Grouping keys must match generated task IDs (`SxTy`) or plan task IDs exactly; mismatches fail command execution.
- `group` mode requires explicit `--pr-group` mappings for every task in scope.
- If tasks are renumbered during plan edits, `--pr-group` mappings in run commands must be updated.
- In issue task rows, `group` mode is displayed as `pr-shared` or `pr-isolated`; treat `pr_group` mappings as the source of truth for grouped behavior.
- Fixture files are disposable by design; avoid using them as persistent docs or examples outside this test.
- GitHub approval URL gates are required for acceptance/close operations and cannot be bypassed in normal flow.

## Rollback plan
- Keep each sprint delivered via separate PR(s) so any failed experiment can be reverted sprint-by-sprint.
- If grouping behavior is incorrect, revert only the affected sprint PR and regenerate task-spec with corrected `--pr-group` mappings.
- If the full test becomes invalid, delete `tests/issues/duck-loop/` and close the plan issue with an explicit not-done reason.
