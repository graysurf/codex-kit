# Script Regression Tests (pytest)

## TL;DR

1. Install dev deps:

```bash
.venv/bin/pip install -r requirements-dev.txt
```

1. Run:

```bash
.venv/bin/python -m pytest
```

Or:

```bash
$AGENT_HOME/scripts/test.sh
```

Or via consolidated check wrapper:

```bash
scripts/check.sh --tests -- -m script_regression
```

1. Run only smoke (deeper coverage for a small subset):

```bash
$AGENT_HOME/scripts/test.sh -m script_smoke
```

## What it does

- Discovers tracked script entrypoints via `git ls-files`:
  - `scripts/**`
  - `skills/**/scripts/**`
  - `commands/**`
- Executes each script via its shebang interpreter (e.g. `bash`, `zsh -f`).
- Default invocation is safe-mode `--help` (override per script via JSON spec).
- Script smoke/regression tests pin `AGENT_HOME` to the active checkout root so worktree runs do not mix coverage with another repo copy.
- Uses a hermetic-ish environment:
  - `HOME` and `XDG_*` redirected under `out/tests/script-regression/`
  - `PATH` prefixed with stub binaries under `tests/stubs/bin/` (e.g. blocks `gh`, `curl`, `wget`)
  - `NO_COLOR=1`, `GIT_PAGER=cat`, etc.
- Writes evidence (untracked) under:
  - `out/tests/script-regression/summary.json`
  - `out/tests/script-regression/logs/**`
  - `out/tests/script-coverage/summary.md`
  - `out/tests/script-coverage/summary.json`

## CI artifact conventions

- Pytest workflow uploads script evidence from `out/tests/**`:
  - `out/tests/script-regression/summary.json`
  - `out/tests/script-regression/logs/**`
  - `out/tests/script-smoke/summary.json`
  - `out/tests/script-smoke/logs/**`
  - `out/tests/script-coverage/summary.json`
  - `out/tests/script-coverage/summary.md`
- API test runner workflow uploads suite evidence from `out/api-test-runner/<suite>/`.
- Each API suite directory includes `results.json`, `junit.xml`, and `summary.md` (plus fixture logs when present).
- API workflow summary steps append each suite `summary.md` to `GITHUB_STEP_SUMMARY` and point to the suite artifact path.

## Related verification gates

- Docs freshness gate (for command/path drift):
  - `scripts/check.sh --docs`
- CI parity guardrail:
  - `scripts/check.sh --tests -- -k parity -m script_regression`
- Skill entrypoint drift guard (required when entrypoint scripts or smoke specs change):
  - `bash scripts/ci/stale-skill-scripts-audit.sh --check`
  - `scripts/check.sh --entrypoint-ownership`
- Release-workflow migration guard:
  - deprecated helpers removed in PR #221 must stay removed (`audit-changelog.zsh`, `release-audit.sh`,
    `release-find-guide.sh`, `release-notes-from-changelog.sh`, `release-scaffold-entry.sh`)
  - replace old release helper usage with:
    - `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .`
    - `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>`

## Script smoke tests

Smoke tests are a separate pytest marker intended for deeper, hermetic-ish execution of selected scripts.

- Run:
  - `$AGENT_HOME/scripts/test.sh -m script_smoke`
- Evidence:
  - `out/tests/script-smoke/summary.json`
  - `out/tests/script-smoke/logs/**`
- Docs:
  - `docs/testing/script-smoke.md`

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

### Smoke cases

Specs can also include an optional `smoke` section (list of cases, or `{ "cases": [...] }`) which powers the `script_smoke` marker.

Each smoke case supports the same fields as regression (`args`, `env`, `timeout_sec`, `expect`) plus:

- `command`: optional full argv list (cannot be combined with `args`)
- `artifacts`: list of repo-relative paths that must exist after the case runs

Example:

`tests/script_specs/scripts/chrome-devtools-mcp.sh.json`

## Debugging failures

- Run a single script case:
  - `.venv/bin/python -m pytest -k chrome-devtools-mcp -m script_regression`
- Inspect evidence:
  - `out/tests/script-regression/logs/<script>.stderr.txt`
  - `out/tests/script-regression/logs/<script>.stdout.txt`
  - `out/tests/script-regression/summary.json`
  - `out/tests/script-smoke/summary.json`
