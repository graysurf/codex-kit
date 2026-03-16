# scripts

Repo-local helper scripts used by local development and CI in `agent-kit`.
Use these entrypoints to keep local checks aligned with CI behavior.

## Quick start

- Full local gate (recommended before commit):
  - `scripts/check.sh --pre-commit`
- Canonical single-command gate:
  - `scripts/check.sh --all`
- Targeted runs:
  - `scripts/check.sh --docs`
  - `scripts/check.sh --entrypoint-ownership`
  - `scripts/check.sh --tests -- -m script_smoke`

## Directory layout

```text
scripts/
├── build/
│   ├── README.md
│   └── bundle-wrapper.zsh
├── ci/
│   ├── generate-lint-workflow-phases.py
│   ├── docs-freshness-audit.sh
│   ├── markdownlint-audit.sh
│   ├── stale-skill-scripts-audit.sh
│   └── third-party-artifacts-audit.sh
├── check.sh
├── check_plan_issue_worktree_cleanup.sh
├── chrome-devtools-mcp.sh
├── fix-shell-style.zsh
├── fix-typeset-empty-string-quotes.zsh
├── fix-zsh-typeset-initializers.zsh
├── generate-third-party-artifacts.sh
├── install-homebrew-nils-cli.sh
├── lib/
│   ├── check/
│   │   ├── dispatch.sh
│   │   └── tasks.sh
│   ├── lint/
│   │   ├── common.sh
│   │   ├── dispatch.sh
│   │   ├── python.sh
│   │   └── shell.sh
│   └── zsh-common.zsh
├── lint.sh
├── plan-issue-adapter
├── project-resolve
├── semgrep-scan.sh
└── test.sh
```

## Script index

### Core validation entrypoints

- `scripts/check.sh`
  - Main validation router (mode/subcommand dispatch) for lint, docs audits, Semgrep, and pytest.
  - `--pre-commit` runs the full gate plus:
    - `bash scripts/ci/stale-skill-scripts-audit.sh --check`
    - `scripts/check.sh --entrypoint-ownership`
- `scripts/lint.sh`
  - Shell + Python lint/type/syntax checks via subcommand dispatch (`all|shell|python`).
- `scripts/test.sh`
  - Pytest runner (uses `.venv` python when available).
- `scripts/semgrep-scan.sh`
  - Semgrep scan with local rules and curated profiles.

### CI and docs/artifact audits

- `scripts/ci/markdownlint-audit.sh`
  - Markdown lint wrapper (`markdownlint-cli2`).
- `scripts/ci/third-party-artifacts-audit.sh`
  - Verifies required third-party artifacts and drift.
- `scripts/ci/docs-freshness-audit.sh`
  - Verifies required docs commands/paths are still accurate.
- `scripts/ci/generate-lint-workflow-phases.py`
  - Generates/validates `.github/workflows/lint.yml` check-phase blocks from `scripts/lib/check/ci_phase_map.json`.
- `scripts/ci/stale-skill-scripts-audit.sh`
  - Classifies skill scripts as `ACTIVE` / `TRANSITIONAL` / `REMOVABLE`.
- `scripts/generate-third-party-artifacts.sh`
  - Generates `THIRD_PARTY_LICENSES.md` and `THIRD_PARTY_NOTICES.md`.

### Shell maintenance utilities

- `scripts/fix-shell-style.zsh`
  - Runs shell style auto-fixers/checkers.
- `scripts/fix-typeset-empty-string-quotes.zsh`
  - Normalizes `typeset/local foo=""` to `foo=''`.
- `scripts/fix-zsh-typeset-initializers.zsh`
  - Adds missing initializers for zsh `typeset/local` declarations.
- `scripts/audit-env-bools.zsh`
  - Audits boolean env var naming conventions.
- `scripts/lib/zsh-common.zsh`
  - Shared zsh helpers for repo-root resolution.
- `scripts/lib/check/*.sh`
  - `check.sh` dispatch and task modules.
- `scripts/lib/lint/*.sh`
  - `lint.sh` dispatch and language-specific lint modules.

### Workflow-specific utilities

- `scripts/check_plan_issue_worktree_cleanup.sh`
  - Checks leftover `plan-issue-delivery` worktree directories.
- `scripts/plan-issue-adapter`
  - Explicit installer/sync/status entrypoint for optional `plan-issue-delivery`
    runtime adapters (`codex|claude|opencode`).
- `scripts/chrome-devtools-mcp.sh`
  - Launcher for chrome-devtools MCP server with repo env handling.
- `scripts/project-resolve`
  - Bundled deterministic project path resolver.

### Environment/bootstrap helpers

- `scripts/install-homebrew-nils-cli.sh`
  - CI bootstrap helper to install Homebrew + `nils-cli`.

## Bundling wrappers

Use `scripts/build/bundle-wrapper.zsh` to inline a wrapper plus sourced files into a single executable.
Details and examples live in:

- `scripts/build/README.md`
