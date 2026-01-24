# Development Guide

## Development (Shell / zsh)

- `stdout`/`stderr`: These scripts are designed for non-interactive use. Keep `stdout` for machine/LLM-parsable output only; send everything else (debug/progress/warn) to `stderr` (zsh: `print -u2 -r -- ...`; bash: `echo ... >&2`).
- Avoid accidental output (zsh `typeset`/`local`): don't repeatedly declare variables without initial values inside loops (e.g. `typeset key file`). With `unsetopt typeset_silent` (including the default), zsh may print existing values to `stdout` (e.g. `key=''`), creating noise.
  - Option A (preferred): declare once outside the loop -> `typeset key='' file=''`; inside the loop, only assign (`key=...`).
  - Option B: if you must declare inside the loop -> always provide an initial value (`typeset key='' file=''`).
- Quoting rules (zsh; same idea in bash)
  - Literal strings (no `$var`/`$(cmd)` expansion) -> single quotes: `typeset homebrew_path=''`
  - Needs expansion -> double quotes and keep quoting: `typeset repo_root="$PWD"`, `print -r -- "$msg"`
  - Needs escape sequences (e.g. `\n`) -> use `$'...'`
- Path rules
  - Prefer absolute paths in docs/examples; use `$CODEX_HOME/...` for repo-local tools (avoid `scripts/...` / `./scripts/...`).
  - Use `$HOME/...` instead of `~/...` to avoid shell-specific tilde expansion edge cases.
- Auto-fix (empty strings only): `$CODEX_HOME/scripts/fix-typeset-empty-string-quotes.zsh --check|--write` normalizes `typeset/local ...=""` to `''`.

## Testing

### Required before committing

- Run: `$CODEX_HOME/scripts/check.sh --all`
- `$CODEX_HOME/scripts/check.sh --all` runs:
  - `$CODEX_HOME/scripts/lint.sh` (shell + python)
    - Shell: route by shebang and run `shellcheck` (bash) + `bash -n` + `zsh -n`
    - Python: `ruff check tests` + `mypy --config-file mypy.ini tests` + `pyright` + syntax-check for tracked `.py` files
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh` (wrapper: `$CODEX_HOME/scripts/validate_skill_contracts.sh`)
  - `$CODEX_HOME/scripts/semgrep-scan.sh`
  - `$CODEX_HOME/scripts/test.sh` (pytest; prefers `.venv/bin/python`)

### Tooling / setup (as needed)

- Prereqs
  - Python
    - `python3 -m venv .venv`
    - `.venv/bin/pip install -r requirements-dev.txt`
  - System tools
    - `shellcheck`, `zsh` (macOS: `brew install shellcheck`; Ubuntu: `sudo apt-get install -y shellcheck zsh`)
- Quick entry points
  - `$CODEX_HOME/scripts/lint.sh` (defaults to shell + python)
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh` (canonical; wrapper: `$CODEX_HOME/scripts/validate_skill_contracts.sh`)
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh` (canonical; wrapper: `$CODEX_HOME/scripts/audit-skill-layout.sh`)
  - `$CODEX_HOME/scripts/check.sh --lint` (lint only; faster iteration)
  - `$CODEX_HOME/scripts/check.sh --contracts` (skill-contract validation only)
  - `$CODEX_HOME/scripts/check.sh --tests -- -m script_smoke` (passes args through to pytest)
  - `$CODEX_HOME/scripts/check.sh --semgrep` (Semgrep only)
  - `$CODEX_HOME/scripts/check.sh --all` (full check)
- `pytest`
  - Prefer the wrapper: `$CODEX_HOME/scripts/test.sh` (passes args through to pytest)
  - Common: `$CODEX_HOME/scripts/test.sh -m script_smoke`, `$CODEX_HOME/scripts/test.sh -m script_regression`
  - Artifacts: written to `out/tests/` (e.g. `out/tests/script-coverage/summary.md`)
- `ruff` (Python lint; config: `ruff.toml`)
  - `source .venv/bin/activate && ruff check tests`
  - Safe autofix: `source .venv/bin/activate && ruff check --fix tests`
  - Or via: `$CODEX_HOME/scripts/lint.sh --python`
- `mypy` (typecheck; config: `mypy.ini`)
  - `source .venv/bin/activate && mypy --config-file mypy.ini tests`
  - Or via: `$CODEX_HOME/scripts/lint.sh --python`
- `pyright` (typecheck; config: `pyrightconfig.json`)
  - `source .venv/bin/activate && pyright --project pyrightconfig.json`
  - Or via: `$CODEX_HOME/scripts/lint.sh --python`
- Shell (bash/zsh)
  - `$CODEX_HOME/scripts/lint.sh --shell` (requires `shellcheck` and `zsh`)
