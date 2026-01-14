# Script Smoke Tests (pytest)

## TL;DR

1) Install dev deps:

```bash
.venv/bin/pip install -r requirements-dev.txt
```

2) Run smoke:

```bash
scripts/test.sh -m script_smoke
```

## What it does

- Runs selected script entrypoints through deeper smoke cases (beyond `--help`).
- Smoke cases are either:
  - Spec-driven (preferred): `tests/script_specs/<script_relpath>.json` includes a `smoke` list.
  - Fixture-driven: pytest builds temporary repos/files (used for scripts that mutate git state, etc.).
- Writes evidence (untracked) under:
  - `out/tests/script-smoke/summary.json`
  - `out/tests/script-smoke/logs/**`

## Authoring spec-driven smoke cases

Create or extend a per-script spec at:

`tests/script_specs/<script_relpath>.json`

Add a `smoke` array of cases:

- `name`: string (used in log filenames)
- `args`: list of CLI args (default: `[]`)
- `env`: env var overrides (values are strings; use `null` to unset)
- `timeout_sec`: number (default: `10`)
- `expect`:
  - `exit_codes`: list of allowed exit codes (default: `[0]`)
  - `stdout_regex`: optional regex (multiline)
  - `stderr_regex`: optional regex (multiline)
- `artifacts`: optional list of repo-relative paths that must exist after the case runs

## When to use fixture-driven smoke

Use pytest fixtures when a smoke case needs setup/teardown that must not touch the real repo state, e.g.:

- Temporary git repos (commits, staging, branching)
- Scripts that write files and require isolated working dirs
- Scripts that must run under a specific cwd

See: `tests/test_script_smoke.py`

## Related docs

- Regression suite (broad `--help` guardrail): `docs/testing/script-regression.md`
