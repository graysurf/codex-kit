# Development Guide

## Quick Start (Repository Root)

1. `python3 -m venv .venv`
2. `.venv/bin/python -m pip install -r requirements-dev.txt`
3. `scripts/check.sh --all`

`scripts/...` commands are executable directly from the repo root.
For absolute-path docs/examples, set `export CODEX_HOME="$(pwd)"` in the current shell.

## Required Before Commit

- Run: `scripts/check.sh --all`
- `scripts/check.sh --all` currently runs:
  - `scripts/lint.sh` (shell + python)
    - shell: shebang-based routing, `shellcheck` (bash) + `bash -n` + `zsh -n`
    - python: `ruff check tests` + `mypy` + `pyright` + syntax-compile for tracked `.py`
  - `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
  - `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
  - `plan-tooling validate` (from `nils-cli`)
  - `zsh -f scripts/audit-env-bools.zsh --check`
  - `scripts/semgrep-scan.sh`
  - `scripts/test.sh` (pytest; prefers `.venv/bin/python`)

## Common Commands

- `scripts/check.sh --lint` (lint only; faster loop)
- `scripts/check.sh --contracts` (skill contract validation only)
- `scripts/check.sh --skills-layout` (skill layout audit only)
- `scripts/check.sh --plans` (plan format validation only)
- `scripts/check.sh --env-bools` (boolean env naming/value audit only)
- `scripts/check.sh --tests -- -m script_smoke` (passes args through to pytest)
- `scripts/check.sh --semgrep` (Semgrep only)
- `scripts/check.sh --all` (full check suite)

Direct entry points:

- `scripts/lint.sh --shell|--python|--all`
- `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- `scripts/test.sh -m script_smoke`
- `scripts/test.sh -m script_regression`
- `scripts/semgrep-scan.sh --profile shell`

Test artifacts:

- `scripts/test.sh` writes script coverage summaries under `out/tests/script-coverage/` when available.

## Prerequisites

- Python 3 + venv
  - `python3 -m venv .venv`
  - `.venv/bin/python -m pip install -r requirements-dev.txt`
  - `requirements-dev.txt` includes `pytest`, `semgrep`, `ruff`, `mypy`, and `pyright`
- System tools
  - `git` (required by lint scripts for tracked-file discovery)
  - `zsh` and `shellcheck` (macOS: `brew install shellcheck`; Ubuntu: `sudo apt-get install -y shellcheck zsh`)
  - `nils-cli` (Homebrew: `brew tap graysurf/tap && brew install nils-cli`; provides `plan-tooling`, `api-*`, `semantic-commit`)

## Shell Script Conventions (Shell / zsh)

- `stdout`/`stderr`: scripts are non-interactive; keep `stdout` machine/LLM-parseable and send debug/progress/warnings to `stderr` (`print -u2 -r -- ...` in zsh, `echo ... >&2` in bash).
- Avoid accidental output (`typeset`/`local` in zsh): do not repeatedly declare uninitialized variables inside loops (for example `typeset key file`), because zsh can emit old values to `stdout`.
  - Preferred: declare once outside loop (`typeset key='' file=''`) and only assign inside loop.
  - Alternative: if declaring inside loop, always initialize (`typeset key='' file=''`).
- Quoting rules (zsh; same idea in bash):
  - Literal strings (no expansion): single quotes (`typeset homebrew_path=''`).
  - Expansion required: double quotes (`typeset repo_root="$PWD"`, `print -r -- "$msg"`).
  - Escape sequences required: `$'...'`.
- Path rules:
  - Prefer absolute paths in docs/examples via `$CODEX_HOME/...`.
  - Prefer `$HOME/...` over `~/...` to avoid shell-specific tilde expansion edge cases.
- Auto-fixes:
  - `scripts/fix-typeset-empty-string-quotes.zsh --check|--write` normalizes `typeset/local ...=""` to `''`.
  - `scripts/fix-zsh-typeset-initializers.zsh --check|--write` adds missing initializers to bare zsh `typeset/local` declarations.
