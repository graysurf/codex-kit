# Review: `create-plan` skill (`skills/workflows/plan/create-plan`)

## Current state

- `create-plan` provides a basic sprint/task template, but it historically did not strongly enforce constraints that make plans machine-parseable, automatically verifiable, and easy to split into parallel subagent work. Common failure modes included:
  - Missing or incomplete task fields (especially `Location` / `Dependencies` / `Validation`)
  - Dependencies expressed in natural language (not usable for topological ordering and batching)
  - Non-executable validation steps (no concrete commands or expected outcomes)

## Key issues

1. Task field structure was not enforced (especially `Location` / `Dependencies`).
2. There was no plan lint step, so plans could not fail fast before execution.
3. Tasks were not explicitly required to be independently assignable to subagents (clear scope, file boundaries, and validation).

## Recommendations (implemented)

- Introduce Plan Format v1 (see `docs/plans/FORMAT.md`):
  - `## Sprint N: ...` / `### Task N.M: ...`
  - Each task must include: `Location` / `Description` / `Dependencies` / `Acceptance criteria` / `Validation`
- Add an explicit lint step to the `create-plan` workflow:
  - `scripts/validate_plans.sh --file docs/plans/<slug>-plan.md`
- Update the template so `Location` / `Dependencies` are expressed as lists, avoiding fragile “multiple values on one line” formatting.

## Automation and validation mapping

- Plan output validation (CI-friendly):
  - `scripts/validate_plans.sh` (format + required fields + placeholder bans + dependency existence)
- Plan parsing (shared by tooling and `execute-plan-parallel`):
  - `scripts/plan_to_json.sh`
- Parallel batch computation (dependency topological ordering + overlap risk hints):
  - `scripts/plan_batches.sh`
