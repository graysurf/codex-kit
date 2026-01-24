---
name: plan-tooling
description: Parse and lint Plan Format v1 markdown and compute parallel batches.
---

# Plan Tooling

## Contract

Prereqs:

- `bash` and `python3` available on `PATH`.
- `git` available on `PATH` for `validate_plans.sh`.
- Plan markdown follows Plan Format v1.
- `CODEX_HOME` set if running from outside the repo (optional).

Inputs:

- Plan file path via `--file`.
- Optional sprint selector via `--sprint` (plan_to_json, plan_batches).
- Output format via `--format` (plan_batches).

Outputs:

- `plan_to_json.sh`: JSON to stdout.
- `validate_plans.sh`: validation errors to stderr (none on success).
- `plan_batches.sh`: JSON or text batches to stdout.

Exit codes:

- `0`: success
- `1`: validation/parse error
- `2`: usage error

Failure modes:

- Missing plan file, invalid format, or dependency cycles.
- Missing `python3`/`git` dependencies.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh`
- `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh`
- `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh`

## Compatibility

- Legacy wrappers remain at `scripts/validate_plans.sh`, `scripts/plan_to_json.sh`, `scripts/plan_batches.sh`.
