# Plan Toolchain

## Quickstart

From repo root:

Install tooling via `brew install nils-cli` to get `plan-tooling`, `api-*`, and `semantic-commit` on PATH.

0) Scaffold a new plan file (optional)

```bash
plan-tooling scaffold --slug <kebab-case> --title "<task name>"
```

1) Lint plans (format + “executable task” heuristics)

```bash
plan-tooling validate
```

2) Parse plan → JSON

```bash
plan-tooling to-json --file docs/plans/<name>-plan.md | python3 -m json.tool
```

3) Compute dependency layers (parallel batches) for a sprint

```bash
plan-tooling batches --file docs/plans/<name>-plan.md --sprint 1 --format text
```

## CI / local checks

Run plan lint via the repo check runner:

```bash
scripts/check.sh --plans
```

Or include it in the full suite:

```bash
scripts/check.sh --all
```

## How `/execute-plan-parallel` should use this

- Use `plan-tooling batches` to identify unblocked tasks per batch.
- Spawn subagents per task in the batch (minimal scope).
- After integrating each batch, run the plan’s `Validation` commands (plus `scripts/check.sh --plans` as a quick guard).
