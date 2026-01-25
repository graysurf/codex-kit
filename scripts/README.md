# scripts

Repo-local helpers for codex-kit (command entrypoints live in `commands/` at the repo root).

## Structure

```text
commands/                                 Standalone command entrypoints used by skills and docs.
scripts/
├── build/                                Tooling to generate bundled commands.
├── db-connect/                           DB connection helpers (psql/mysql/mssql wrappers).
├── env.zsh                               Environment defaults shared by repo scripts.
├── fix-typeset-empty-string-quotes.zsh   Normalizes `local/typeset foo=\"\"` to `foo=''`.
├── fix-zsh-typeset-initializers.zsh      Adds initializers to bare zsh `typeset/local` declarations.
├── fix-shell-style.zsh                   Runs shell style fixers (check/write).
├── lint.sh                               Runs shell + python lint/syntax checks.
├── semgrep-scan.sh                       Runs Semgrep with local rules + curated Registry packs.
├── test.sh                               Dev test runner (repo-only).
├── check.sh                              Runs selected checks (lint/contracts/semgrep/tests).
└── audit-env-bools.zsh                   Audits boolean env var conventions (zsh).
```

## Bundling wrappers

Use `build/bundle-wrapper.zsh` to inline a wrapper (and its `source` files)
into a single executable script. This is helpful when you want a portable,
repo-local command without external dependencies on wrapper paths.

Example (git-commit-context-json):

```zsh
zsh -f $CODEX_HOME/scripts/build/bundle-wrapper.zsh \
  --input $HOME/.config/zsh/cache/wrappers/bin/git-commit-context-json \
  --output commands/git-commit-context-json \
  --entry git-commit-context-json
```

Notes:

- Only simple `source` lines and the `typeset -a sources=(...)` / `typeset -a exec_sources=(...)`
  patterns are supported.
- The bundler writes a shebang + minimal env exports into the output file.
- If the wrapper relies on side effects (PATH, cache dirs, etc.), you may
  need to expand the bundler to inline those sections too.

## Validation

### Skill contract lint

`$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh` enforces a minimal skill contract format across `skills/**/SKILL.md`.

Requirements (inside `## Contract`, in order):

- `Prereqs:`
- `Inputs:`
- `Outputs:`
- `Exit codes:`
- `Failure modes:`

Usage:

- Validate all tracked skills: `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Validate a specific file: `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/<path>/SKILL.md`

Exit codes:

- `0`: all validated files are compliant
- non-zero: validation/usage errors (prints `error:` lines to stderr)

### Skill layout audit

`$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh` enforces a consistent tracked skill directory layout:

- `SKILL.md` at the skill root
- Required: `tests/`
- Optional: `scripts/`, `references/`, `assets/`
- No other tracked top-level entries
- Markdown files with `TEMPLATE` in the filename must live under `references/` or `assets/templates/` within the skill

### Lint + syntax checks

`$CODEX_HOME/scripts/lint.sh` runs:

- Shell: `shellcheck` (bash) + `bash -n` + `zsh -n` (shebang-based)
- Python: `ruff` + `mypy` + `pyright`

Usage:

- Lint everything: `$CODEX_HOME/scripts/lint.sh`
- Shell only: `$CODEX_HOME/scripts/lint.sh --shell`
- Python only: `$CODEX_HOME/scripts/lint.sh --python`

## Semgrep

Use `semgrep-scan.sh` to run `.semgrep.yaml` plus curated Semgrep Registry packs.

Examples:

- Default (scripting profile): `$CODEX_HOME/scripts/semgrep-scan.sh`
- Shell scripts only: `$CODEX_HOME/scripts/semgrep-scan.sh --profile shell`

## Plans

Plan tooling helps keep implementation plans concrete (executable + verifiable) and easy to split into parallel subagent tasks.

### Plan lint

`$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh` enforces a minimal Plan Format v1 across `docs/plans/*-plan.md`:

- Sprints: `## Sprint N: <name>`
- Tasks: `### Task N.M: <name>`
- Required per-task fields:
  - `Location` (non-empty list)
  - `Description`
  - `Dependencies` (`none` or list of `Task N.M`)
  - `Acceptance criteria` (non-empty list)
  - `Validation` (non-empty list)

Usage:

- Lint all tracked plans: `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh`
- Lint a specific plan: `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh --file docs/plans/<name>-plan.md`

### Plan JSON export

`$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh` parses a plan into JSON for tooling to consume:

- `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh --file docs/plans/<name>-plan.md | python3 -m json.tool`

### Parallel batches

`$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh` computes dependency layers (parallel batches) for a sprint:

- `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh --file docs/plans/<name>-plan.md --sprint 1 --format text`
