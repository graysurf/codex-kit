# Development Guide

## Purpose

- Setup local environment for this repository.
- Provide a clear local testing flow for agents and developers.
- Define commit-time validation steps that match CI expectations.

## Prerequisites

- Python 3 + venv
  - `python3 -m venv .venv`
  - `.venv/bin/python -m pip install -r requirements-dev.txt`
  - `requirements-dev.txt` includes `pytest`, `semgrep`, `ruff`, `mypy`, and `pyright`
- System tools
  - `git` (required by lint scripts for tracked-file discovery)
  - `node`/`npx` (required by markdown lint)
  - `zsh` and `shellcheck` (macOS: `brew install shellcheck`; Ubuntu: `sudo apt-get install -y shellcheck zsh`)
  - `nils-cli` (Homebrew: `brew tap sympoies/tap && brew install nils-cli`; provides `plan-tooling`, `api-*`, `semantic-commit`)

## Quick Setup (Repository Root)

1. `python3 -m venv .venv`
2. `.venv/bin/python -m pip install -r requirements-dev.txt`
3. `export AGENT_HOME="$(pwd)"`
4. `scripts/check.sh --all`

`scripts/...` commands are executable directly from the repo root.

## Local Test Workflow

Use these commands during implementation:

- Fast lint loop: `scripts/check.sh --lint`
- Docs gate only: `scripts/check.sh --docs`
- Smoke-only tests: `scripts/check.sh --tests -- -m script_smoke`
- Direct smoke via repo test entrypoint: `$AGENT_HOME/scripts/test.sh -m script_smoke`
- Targeted parity guard: `scripts/check.sh --tests -- -k parity -m script_regression`
- Full local gate: `scripts/check.sh --all`

`scripts/check.sh --all` currently runs:

- `scripts/lint.sh` (shell + python)
  - shell: shebang-based routing, `shellcheck` (bash) + `bash -n` + `zsh -n`
  - python: `ruff check tests` + `mypy` + `pyright` + syntax-compile for tracked `.py`
- `scripts/ci/markdownlint-audit.sh --strict`
- `scripts/ci/third-party-artifacts-audit.sh --strict`
- `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- `zsh -f scripts/audit-env-bools.zsh --check`
- `bash scripts/ci/docs-freshness-audit.sh --check`
- `scripts/semgrep-scan.sh`
- `scripts/test.sh` (full pytest; prefers `.venv/bin/python`)

## Required Before Commit

Canonical minimum gate:

- `scripts/check.sh --all`

Recommended one-command wrapper (canonical gate + skill entrypoint checks):

- `scripts/check-pre-commit.sh`

Manual equivalent:

- `bash scripts/ci/stale-skill-scripts-audit.sh --check`
- `scripts/check.sh --entrypoint-ownership`

Notes:

- `scripts/check-pre-commit.sh` always includes skill entrypoint checks to avoid conditional misses.
- If you run only the canonical minimum gate (`scripts/check.sh --all`), remember that `stale-skill-scripts-audit` and
  `--entrypoint-ownership` are still required whenever skill entrypoint scripts are added/removed.
- When workflow/tool entrypoint scripts change, update the matching
  `tests/script_specs/skills/**/scripts/*.json` smoke specs in the same PR to
  keep spec coverage aligned with retained entrypoints.

## CI Notes

- Lint/test checks are split in `.github/workflows/lint.yml` using `scripts/check.sh` modes.
- Additional API demo suites run in `.github/workflows/api-test-runner.yml` and are CI coverage, not required for standard local commits.

## Direct Entrypoints

- `scripts/lint.sh --shell|--python|--all`
- `scripts/ci/markdownlint-audit.sh --strict`
- `scripts/ci/third-party-artifacts-audit.sh --strict`
- `scripts/ci/stale-skill-scripts-audit.sh --check`
- `scripts/ci/docs-freshness-audit.sh --check`
- `scripts/generate-third-party-artifacts.sh --write`
- `scripts/generate-third-party-artifacts.sh --check`
- `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- `scripts/test.sh -m script_smoke`
- `scripts/test.sh -m script_regression`
- `scripts/semgrep-scan.sh --profile shell`

Test artifacts:

- `scripts/test.sh` writes script coverage summaries under `out/tests/script-coverage/` when available.

## Agent-Docs Preflight (Write Actions)

Before implementation work that edits files, resolve required docs:

- `agent-docs resolve --context startup --strict --format checklist`
- `agent-docs resolve --context project-dev --strict --format checklist`

If strict resolve fails, run:

- `agent-docs baseline --check --target all --strict --format text`

## Shell Script Conventions (Shell / zsh)

- `stdout`/`stderr`: scripts are non-interactive; keep `stdout` machine/LLM-parseable and send debug/progress/warnings to `stderr`
  (`print -u2 -r -- ...` in zsh, `echo ... >&2` in bash).
- Avoid accidental output (`typeset`/`local` in zsh): do not repeatedly declare uninitialized variables inside loops (for example
  `typeset key file`), because zsh can emit old values to `stdout`.
  - Preferred: declare once outside loop (`typeset key='' file=''`) and only assign inside loop.
  - Alternative: if declaring inside loop, always initialize (`typeset key='' file=''`).
- Quoting rules (zsh; same idea in bash):
  - Literal strings (no expansion): single quotes (`typeset homebrew_path=''`).
  - Expansion required: double quotes (`typeset repo_root="$PWD"`, `print -r -- "$msg"`).
  - Escape sequences required: `$'...'`.
- Path rules:
  - Prefer absolute paths in docs/examples via `$AGENT_HOME/...`.
  - Prefer `$HOME/...` over `~/...` to avoid shell-specific tilde expansion edge cases.
- Auto-fixes:
  - `scripts/fix-typeset-empty-string-quotes.zsh --check|--write` normalizes `typeset/local ...=""` to `''`.
  - `scripts/fix-zsh-typeset-initializers.zsh --check|--write` adds missing initializers to bare zsh `typeset/local` declarations.
