# Review: `create-plan-rigorous` skill (`skills/workflows/plan/create-plan-rigorous`)

## Current state

- `create-plan-rigorous` is intended as a more rigorous version of `create-plan`: every task includes a Complexity score, dependencies are explicit, and a subagent review is performed.
- Historically it lacked an automated “validation gate”, which made reviews drift toward subjective commentary instead of actionable, verifiable improvements.

## Key issues

1. Plans were not required to pass lint first (plans could be unparseable or missing required fields).
2. The subagent review lacked a rubric (often resulting in vague feedback that did not translate into verifiable changes).
3. Complexity usage rules were unclear (when it is required and how it should guide risk management and task splitting).

## Recommendations (implemented)

- Add a lint gate before the subagent review:
  - `scripts/validate_plans.sh --file docs/plans/<slug>-plan.md`
- Add an explicit review rubric (no questions; only actionable improvements):
  - Required-field completeness
  - Placeholder leakage (e.g., angle-bracket placeholders, TODO/TBD-style markers)
  - Task atomicity and parallelization readiness (clear dependencies, minimal file overlap)
  - Validations are runnable and sufficient to prove acceptance criteria

## Automation and validation mapping

- Lint: `scripts/validate_plans.sh`
- Parse: `scripts/plan_to_json.sh`
- Batches: `scripts/plan_batches.sh`
