# Script Regression Tests (pytest)

## TL;DR

1) Install dev deps:

```bash
.venv/bin/pip install -r requirements-dev.txt
```

2) Run:

```bash
.venv/bin/python -m pytest
```

Or:

```bash
scripts/test.sh
```

## What it does

- Discovers tracked script entrypoints via `git ls-files`:
  - `scripts/**`
  - `skills/**/scripts/**`
- Executes each script via its shebang interpreter (e.g. `bash`, `zsh -f`).
- Default invocation is safe-mode `--help` (override per script via JSON spec).
- Uses a hermetic-ish environment:
  - `HOME` and `XDG_*` redirected under `out/tests/script-regression/`
  - `PATH` prefixed with stub binaries under `tests/stubs/bin/` (e.g. blocks `gh`, `curl`, `wget`)
  - `NO_COLOR=1`, `GIT_PAGER=cat`, etc.
- Writes evidence (untracked) under:
  - `out/tests/script-regression/summary.json`
  - `out/tests/script-regression/logs/**`

## Per-script spec overrides

When a script cannot be safely validated via `--help` alone, add a JSON spec at:

`tests/script_specs/<script_relpath>.json`

Fields:

- `args`: list of CLI args (default: `["--help"]`)
- `env`: env var overrides (values are strings; use `null` to unset)
- `timeout_sec`: number (default: `5`)
- `expect`:
  - `exit_codes`: list of allowed exit codes (default: `[0]`)
  - `stdout_regex`: optional regex (multiline)
  - `stderr_regex`: optional regex (multiline)

Example:

`tests/script_specs/scripts/chrome-devtools-mcp.sh.json`

## Debugging failures

- Run a single script case:
  - `.venv/bin/python -m pytest -k chrome-devtools-mcp -m script_regression`
- Inspect evidence:
  - `out/tests/script-regression/logs/<script>.stderr.txt`
  - `out/tests/script-regression/logs/<script>.stdout.txt`
  - `out/tests/script-regression/summary.json`
