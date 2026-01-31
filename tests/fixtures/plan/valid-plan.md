# Plan: Fixture valid plan

## Sprint 1: Fixture sprint

### Task 1.1: First task
- **Location**:
  - `docs/plans/README.md`
- **Description**: Write a small docs update.
- **Dependencies**: none
- **Acceptance criteria**:
  - A doc file is updated.
- **Validation**:
  - `$CODEX_COMMANDS_PATH/plan-tooling validate --file tests/fixtures/plan/valid-plan.md`

### Task 1.2: Second task depends on first
- **Location**:
  - `scripts/README.md`
- **Description**: Add a note after the docs update exists.
- **Dependencies**:
  - Task 1.1
- **Acceptance criteria**:
  - The dependency relationship is explicit.
- **Validation**:
  - `$CODEX_COMMANDS_PATH/plan-tooling batches --file tests/fixtures/plan/valid-plan.md --sprint 1`

### Task 1.3: Third task depends on first
- **Location**:
  - `scripts/check.sh`
- **Description**: Another task that can run in parallel with Task 1.2 after Task 1.1.
- **Dependencies**:
  - Task 1.1
- **Acceptance criteria**:
  - Batch computation produces a parallel layer.
- **Validation**:
  - `$CODEX_COMMANDS_PATH/plan-tooling batches --file tests/fixtures/plan/valid-plan.md --sprint 1`
