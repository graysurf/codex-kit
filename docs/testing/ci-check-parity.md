# CI Check Parity

## Purpose

`tests/test_ci_check_parity.py` enforces parity between local check entrypoints (`scripts/check.sh`) and the CI phases in `.github/workflows/lint.yml`.

The guardrail is designed to fail fast when a required `scripts/check.sh` mode is removed, renamed, or no longer invoked by lint workflow phases.

## Required phase mapping

Lint workflow phases must run these `scripts/check.sh` modes:

- `--lint-shell`
- `--lint-python`
- `--markdown`
- `--third-party`
- `--contracts`
- `--skills-layout`
- `--plans`
- `--env-bools`
- `--tests`

Lint workflow also runs the docs freshness gate:

- `--docs`

## Run parity checks

```bash
scripts/check.sh --tests -- -k parity -m script_regression
```

This command is also required in lint CI (parity guard step) and is included by
`scripts/check.sh --all` because `--all` runs the full pytest suite.

## Remediation workflow

1. If a parity test fails for a missing workflow mode, update `.github/workflows/lint.yml` so that phase calls `scripts/check.sh <mode>` directly.
2. If a check mode is renamed, update both `scripts/check.sh` and `tests/test_ci_check_parity.py` in the same change.
3. Re-run:

```bash
scripts/check.sh --lint
scripts/check.sh --plans
scripts/check.sh --env-bools
scripts/check.sh --docs
scripts/check.sh --tests -- -k parity -m script_regression
scripts/check.sh --all
```

## Docs completion checklist (refactor follow-up)

When a refactor changes check entrypoints, CI phases, script paths, or artifact locations:

- Update affected docs in the same PR (`README.md`, `DEVELOPMENT.md`, `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`, and relevant
  `docs/testing/*.md`).
- Verify docs command/path freshness:

```bash
scripts/check.sh --docs
```

- Verify markdown quality and parity behavior:

```bash
scripts/check.sh --markdown
scripts/check.sh --tests -- -k parity -m script_regression
```
