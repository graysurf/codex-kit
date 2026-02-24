# Plan: Duck plan for plan issue delivery loop

## Overview
This plan creates disposable test deliverables under `tests/issues/duck-loop/` to validate `plan-issue-delivery-loop` orchestration. Each sprint explicitly includes one single-task PR path and one two-task shared-PR path so both grouping styles can be exercised repeatedly. The plan is execution-only for test fixtures and avoids production code changes, making cleanup straightforward after verification.

## Scope
- In scope:
  - Create sprint-scoped fixture content only under `tests/issues/duck-loop/`.
  - Validate `per-task` and `manual` PR grouping behavior for every sprint.
  - Generate task-spec artifacts in `$AGENT_HOME/out/plan-issue-delivery-loop/` during validation.
- Out of scope:
  - Any production logic changes outside `tests/issues/duck-loop/`.
  - Permanent docs updates outside this plan file.
  - Automating cleanup in this phase (manual cleanup is documented only).

## Assumptions (if any)
1. `plan-tooling` and `python3` are available on `PATH`.
2. `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh` is executable in this repo.
3. GitHub approval/merge gates are validated when the orchestration workflow runs, not in this planning step.

## Success criteria
- The plan has at least 3 sprints and every sprint contains:
  - one task intended for single-task single-PR delivery.
  - two tasks intended for shared-PR delivery.
- All implementation artifacts are isolated under `tests/issues/duck-loop/`.
- Sprint validation commands show:
  - `per-task` mode yields unique `pr_group` values per task.
  - `manual` mode can group two specified tasks into one `pr_group`.

## Sprint 1: Baseline fixture and grouping smoke
**Goal**: Establish disposable test area and validate grouping behavior on first sprint tasks.
**Demo/Validation**:
- Command(s):
  - `plan-tooling validate --file docs/plans/duck-issue-loop-test-plan.md`
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 1 --pr-grouping per-task --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s1-per-task.tsv"`
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 1 --pr-grouping manual --pr-group S1T3=s1-shared --pr-group S1T4=s1-shared --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s1-manual.tsv"`
  - `python3 - <<'PY'\nimport csv\nfrom pathlib import Path\nrows=list(csv.reader(Path(\"$AGENT_HOME/out/plan-issue-delivery-loop/duck-s1-manual.tsv\").open(), delimiter=\"\\t\"))\ndata=[r for r in rows if r and not r[0].startswith(\"#\")]\ngroups=[r[6] for r in data]\nassert groups.count(\"s1-shared\") == 2, groups\nprint(\"ok\")\nPY`
- Verify:
  - Sprint 1 task-spec files exist under `$AGENT_HOME/out/plan-issue-delivery-loop/`.
  - Manual grouping output contains exactly two tasks in `s1-shared`.
**Parallelizable tasks**:
- `Task 1.2` and `Task 1.3` can run in parallel after `Task 1.1`.
- `Task 1.4` depends on `Task 1.3`.

### Task 1.1: Create disposable duck-loop root and cleanup notes
- **Location**:
  - `tests/issues/duck-loop/README.md`
  - `tests/issues/duck-loop/CLEANUP.md`
- **Description**: Create the root fixture directory with purpose, execution notes, and a one-command cleanup instruction (`rm -rf tests/issues/duck-loop`).
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - Root README states this folder is test-only and disposable.
  - Cleanup doc includes explicit removal command.
- **Validation**:
  - `test -f tests/issues/duck-loop/README.md && test -f tests/issues/duck-loop/CLEANUP.md`
  - `rg -n 'rm -rf tests/issues/duck-loop' tests/issues/duck-loop/CLEANUP.md`

### Task 1.2: Sprint 1 single-task single-PR fixture
- **Location**:
  - `tests/issues/duck-loop/sprint1/single-pr/task.md`
- **Description**: Add a fixture representing the one-task one-PR path for Sprint 1, including a marker that this task should stay isolated from grouped PR tasks.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 2
- **Acceptance criteria**:
  - File content includes `mode: single-task-pr`.
  - File content references Sprint 1 single-task scenario.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint1/single-pr/task.md`
  - `rg -n 'mode: single-task-pr' tests/issues/duck-loop/sprint1/single-pr/task.md`

### Task 1.3: Sprint 1 grouped-PR fixture part A
- **Location**:
  - `tests/issues/duck-loop/sprint1/grouped-pr/task-a.md`
- **Description**: Add the first of two tasks that should be grouped into one PR for Sprint 1 grouped mode validation.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 2
- **Acceptance criteria**:
  - File content includes `mode: grouped-pr`.
  - File identifies itself as grouped pair part A.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint1/grouped-pr/task-a.md`
  - `rg -n 'mode: grouped-pr' tests/issues/duck-loop/sprint1/grouped-pr/task-a.md`

### Task 1.4: Sprint 1 grouped-PR fixture part B
- **Location**:
  - `tests/issues/duck-loop/sprint1/grouped-pr/task-b.md`
- **Description**: Add the second grouped task and encode dependency metadata to preserve execution ordering for a shared PR path.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 2
- **Acceptance criteria**:
  - File content includes grouped mode marker.
  - File content records dependency on `Task 1.3`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint1/grouped-pr/task-b.md`
  - `rg -n 'depends-on: Task 1.3' tests/issues/duck-loop/sprint1/grouped-pr/task-b.md`

## Sprint 2: Repeatability with second fixture set
**Goal**: Re-run the same two PR-delivery styles with a new sprint fixture set to verify repeatability across `next-sprint` orchestration.
**Demo/Validation**:
- Command(s):
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 2 --pr-grouping per-task --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s2-per-task.tsv"`
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 2 --pr-grouping manual --pr-group S2T2=s2-shared --pr-group S2T3=s2-shared --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s2-manual.tsv"`
  - `python3 - <<'PY'\nimport csv\nfrom pathlib import Path\nrows=list(csv.reader(Path(\"$AGENT_HOME/out/plan-issue-delivery-loop/duck-s2-manual.tsv\").open(), delimiter=\"\\t\"))\ndata=[r for r in rows if r and not r[0].startswith(\"#\")]\ngroups=[r[6] for r in data]\nassert groups.count(\"s2-shared\") == 2, groups\nprint(\"ok\")\nPY`
- Verify:
  - Sprint 2 per-task output has one `pr_group` per task.
  - Sprint 2 manual output groups exactly two tasks into `s2-shared`.
**Parallelizable tasks**:
- `Task 2.1` and `Task 2.2` can run in parallel.
- `Task 2.3` depends on `Task 2.2`.

### Task 2.1: Sprint 2 single-task single-PR fixture
- **Location**:
  - `tests/issues/duck-loop/sprint2/single-pr/task.md`
- **Description**: Create Sprint 2 single-task PR fixture content with unique sprint marker.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists and includes `mode: single-task-pr`.
  - File includes `sprint: 2`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint2/single-pr/task.md`
  - `rg -n 'sprint: 2' tests/issues/duck-loop/sprint2/single-pr/task.md`

### Task 2.2: Sprint 2 grouped-PR fixture part A
- **Location**:
  - `tests/issues/duck-loop/sprint2/grouped-pr/task-a.md`
- **Description**: Create grouped fixture part A for Sprint 2 shared PR test.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with grouped mode marker.
  - File identifies itself as part A.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint2/grouped-pr/task-a.md`
  - `rg -n 'part: A' tests/issues/duck-loop/sprint2/grouped-pr/task-a.md`

### Task 2.3: Sprint 2 grouped-PR fixture part B
- **Location**:
  - `tests/issues/duck-loop/sprint2/grouped-pr/task-b.md`
- **Description**: Create grouped fixture part B for Sprint 2 and keep dependency on grouped part A.
- **Dependencies**:
  - Task 2.2
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with grouped mode marker.
  - File includes `depends-on: Task 2.2`.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint2/grouped-pr/task-b.md`
  - `rg -n 'depends-on: Task 2.2' tests/issues/duck-loop/sprint2/grouped-pr/task-b.md`

## Sprint 3: Final sprint and cleanup readiness
**Goal**: Validate both PR styles one more time and prepare explicit cleanup metadata for post-test teardown.
**Demo/Validation**:
- Command(s):
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 3 --pr-grouping per-task --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s3-per-task.tsv"`
  - `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec --plan docs/plans/duck-issue-loop-test-plan.md --sprint 3 --pr-grouping manual --pr-group S3T2=s3-shared --pr-group S3T3=s3-shared --task-spec-out "$AGENT_HOME/out/plan-issue-delivery-loop/duck-s3-manual.tsv"`
  - `python3 - <<'PY'\nimport csv\nfrom pathlib import Path\nrows=list(csv.reader(Path(\"$AGENT_HOME/out/plan-issue-delivery-loop/duck-s3-manual.tsv\").open(), delimiter=\"\\t\"))\ndata=[r for r in rows if r and not r[0].startswith(\"#\")]\ngroups=[r[6] for r in data]\nassert groups.count(\"s3-shared\") == 2, groups\nprint(\"ok\")\nPY`
- Verify:
  - Sprint 3 manual spec groups the targeted two tasks.
  - Cleanup manifest includes all sprint fixture paths.
**Parallelizable tasks**:
- `Task 3.1` and `Task 3.2` can run in parallel.
- `Task 3.3` depends on `Task 3.2`.

### Task 3.1: Sprint 3 single-task single-PR fixture
- **Location**:
  - `tests/issues/duck-loop/sprint3/single-pr/task.md`
- **Description**: Create Sprint 3 single-task fixture used to validate independent PR creation in final sprint.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists and includes single-task PR marker.
  - File includes sprint index marker.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint3/single-pr/task.md`
  - `rg -n 'mode: single-task-pr' tests/issues/duck-loop/sprint3/single-pr/task.md`

### Task 3.2: Sprint 3 grouped-PR fixture part A
- **Location**:
  - `tests/issues/duck-loop/sprint3/grouped-pr/task-a.md`
- **Description**: Create grouped task A for final sprint shared PR validation.
- **Dependencies**: none
- **Complexity**: 2
- **Acceptance criteria**:
  - File exists with grouped mode marker.
  - File identifies itself as grouped part A.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint3/grouped-pr/task-a.md`
  - `rg -n 'mode: grouped-pr' tests/issues/duck-loop/sprint3/grouped-pr/task-a.md`

### Task 3.3: Sprint 3 grouped-PR fixture part B and cleanup index
- **Location**:
  - `tests/issues/duck-loop/sprint3/grouped-pr/task-b.md`
  - `tests/issues/duck-loop/CLEANUP.md`
- **Description**: Create grouped task B for final sprint and update cleanup notes with all sprint directories for one-shot teardown.
- **Dependencies**:
  - Task 3.2
- **Complexity**: 3
- **Acceptance criteria**:
  - `task-b.md` exists and references dependency on `Task 3.2`.
  - Cleanup notes list Sprint 1-3 directories and root delete command.
- **Validation**:
  - `test -f tests/issues/duck-loop/sprint3/grouped-pr/task-b.md`
  - `rg -n 'depends-on: Task 3.2' tests/issues/duck-loop/sprint3/grouped-pr/task-b.md`
  - `rg -n 'sprint1|sprint2|sprint3' tests/issues/duck-loop/CLEANUP.md`

## Testing Strategy
- Unit:
  - Not applicable (fixture-content plan only).
- Integration:
  - For each sprint, run `build-task-spec` in `per-task` and `manual` modes and inspect `pr_group` column behavior.
  - Run `plan-tooling validate --file docs/plans/duck-issue-loop-test-plan.md` before orchestration.
- E2E/manual:
  - Execute `start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`, and `next-sprint` using this plan.
  - Confirm subagent dispatch hints include one isolated task and one shared group of two tasks in each sprint.
  - After final verification, remove `tests/issues/duck-loop/` in one command.

## Risks & gotchas
- Manual grouping keys must match generated task IDs (`SxTy`) or plan task IDs exactly; mismatches fail command execution.
- `per-task` mode intentionally never groups tasks; grouped scenario must use `manual` (or `auto` with strict dependency chain behavior).
- If tasks are renumbered during plan edits, `--pr-group` mappings in run commands must be updated.
- Fixture files are disposable by design; avoid using them as persistent docs or examples outside this test.
- GitHub approval URL gates are required for acceptance/close operations and cannot be bypassed in normal flow.

## Rollback plan
- Keep each sprint delivered via separate PR(s) so any failed experiment can be reverted sprint-by-sprint.
- If grouped PR behavior is incorrect, revert only the affected sprint PR and regenerate task-spec with corrected `--pr-group` mappings.
- If the full test becomes invalid, delete `tests/issues/duck-loop/` and close the plan issue with an explicit not-done reason.
