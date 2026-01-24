# Plan: Dogfood plan tooling (example)

## Overview

This plan is a small end-to-end dogfood run for the plan toolchain: create a new plan, lint it, compute parallel batches, then execute tasks in parallel via subagents and run the listed validations.

## Scope

- In scope:
  - Add smoke specs for the new plan scripts
  - Add a short runbook doc for the plan workflow
  - Link the runbook from docs/plans
- Out of scope:
  - Changing core plan tooling behavior (this plan is about usage + coverage)

## Sprint 1: Smoke coverage + docs

**Goal**: Prove tasks are concrete and parallelizable.

**Demo/Validation**:

- Command(s):
  - `scripts/validate_plans.sh --file docs/plans/plan-dogfood-example-plan.md`
  - `scripts/plan_batches.sh --file docs/plans/plan-dogfood-example-plan.md --sprint 1 --format text`
  - `scripts/test.sh -q -m script_smoke`
- Verify:
  - `plan_batches.sh` shows all tasks in the same batch (no dependencies).
  - Script smoke suite passes.

### Task 1.1: Add script_smoke specs for plan scripts

- **Location**:
  - `tests/script_specs/scripts/plan_to_json.sh.json`
  - `tests/script_specs/scripts/validate_plans.sh.json`
  - `tests/script_specs/scripts/plan_batches.sh.json`
- **Description**: Add minimal smoke specs to exercise the new plan scripts on the fixture plan under `tests/fixtures/plan/valid-plan.md`.
- **Dependencies**: none
- **Acceptance criteria**:
  - `pytest -m script_smoke` runs the three new specs successfully.
- **Validation**:
  - `scripts/test.sh -q -m script_smoke`

### Task 1.2: Add a runbook for the plan workflow

- **Location**:
  - `docs/runbooks/plan-workflow.md`
- **Description**: Document how to create a plan, lint it, compute parallel batches, and run `/execute-plan-parallel` using the repo plan toolchain scripts.
- **Dependencies**: none
- **Acceptance criteria**:
  - The runbook includes copy/paste commands for lint, JSON export, and batch computation.
- **Validation**:
  - `rg -n "plan_batches\\.sh" docs/runbooks/plan-workflow.md >/dev/null`

### Task 1.3: Link the runbook from docs/plans

- **Location**:
  - `docs/plans/README.md`
- **Description**: Add a link to `docs/runbooks/plan-workflow.md` so the workflow is discoverable from the plans index.
- **Dependencies**: none
- **Acceptance criteria**:
  - `docs/plans/README.md` links to `docs/runbooks/plan-workflow.md`.
- **Validation**:
  - `rg -n "plan-workflow\\.md" docs/plans/README.md >/dev/null`

## Risks & gotchas

- Script smoke tests assume a working python+pytest environment.
