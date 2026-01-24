# Review: `execute-plan-parallel` skill (`skills/workflows/plan/execute-plan-parallel`)

## Current state

- `execute-plan-parallel` describes the workflow “read plan → split tasks → run subagents in parallel → integrate → validate”.
- Historically, plan structure assumptions were too loose, which often resulted in:
  - Parser drift (human interpretation diverging from tooling)
  - Incomplete task fields, leading to unclear subagent scope
  - Implicit dependencies, making batching unreliable

## Key issues

1. Plan parsing rules were not shared with repo tooling (high drift risk).
2. There was no “lint first” fail-fast step.
3. Batch semantics were underspecified (what can run together, and how to determine “unblocked”).
4. Merge-conflict prevention guidance was insufficient (especially when multiple agents touch the same files).

## Recommendations (implemented)

- Prefer repo tooling explicitly (avoid drift):
  - `scripts/validate_plans.sh --file <plan.md>`
  - `scripts/plan_to_json.sh --file <plan.md> [--sprint <n>]`
  - `scripts/plan_batches.sh --file <plan.md> --sprint <n>`
- Make dependency topological ordering an explicit workflow step:
  - Use `plan_batches.sh` output as the dispatch unit for each subagent batch
- Add merge-conflict minimization guidance:
  - `Location` should precisely list the files a task will touch
  - Avoid overlap within the same batch where possible (tooling can warn, but does not hard-block)

## Optional hardening (not enforced)

- Stronger “parallel conflict warnings”: tighten lint rules to disallow globs/directories in `Location` (or downgrade to warnings).
- More consistent validation: require each task’s `Validation` to include at least one command runnable from repo root via copy/paste.
