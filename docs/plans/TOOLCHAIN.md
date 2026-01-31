# Plan Toolchain

## Quickstart

From repo root:

0) Scaffold a new plan file (optional)

```bash
$CODEX_COMMANDS_PATH/plan-tooling scaffold --slug <kebab-case> --title "<task name>"
```

1) Lint plans (format + “executable task” heuristics)

```bash
$CODEX_COMMANDS_PATH/plan-tooling validate
```

2) Parse plan → JSON

```bash
$CODEX_COMMANDS_PATH/plan-tooling to-json --file docs/plans/<name>-plan.md | python3 -m json.tool
```

3) Compute dependency layers (parallel batches) for a sprint

```bash
$CODEX_COMMANDS_PATH/plan-tooling batches --file docs/plans/<name>-plan.md --sprint 1 --format text
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

- Use `$CODEX_COMMANDS_PATH/plan-tooling batches` to identify unblocked tasks per batch.
- Spawn subagents per task in the batch (minimal scope).
- After integrating each batch, run the plan’s `Validation` commands (plus `scripts/check.sh --plans` as a quick guard).
