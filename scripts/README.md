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
├── verify.sh                             Runs lint.sh then test.sh (pytest).
└── validate_skill_contracts.sh           Lints `skills/**/SKILL.md` contracts.
```

## Bundling wrappers

Use `build/bundle-wrapper.zsh` to inline a wrapper (and its `source` files)
into a single executable script. This is helpful when you want a portable,
repo-local command without external dependencies on wrapper paths.

Example (git-tools):

```zsh
zsh -f scripts/build/bundle-wrapper.zsh \
  --input $HOME/.config/zsh/cache/wrappers/bin/git-tools \
  --output commands/git-tools \
  --entry git-tools
```

Notes:

- Only simple `source` lines and the `typeset -a sources=(...)` / `typeset -a exec_sources=(...)`
  patterns are supported.
- The bundler writes a shebang + minimal env exports into the output file.
- If the wrapper relies on side effects (PATH, cache dirs, etc.), you may
  need to expand the bundler to inline those sections too.

## Validation

### Skill contract lint

`scripts/validate_skill_contracts.sh` enforces a minimal skill contract format across `skills/**/SKILL.md`.

Requirements (inside `## Contract`, in order):

- `Prereqs:`
- `Inputs:`
- `Outputs:`
- `Exit codes:`
- `Failure modes:`

Usage:

- Validate all tracked skills: `scripts/validate_skill_contracts.sh`
- Validate a specific file: `scripts/validate_skill_contracts.sh --file skills/<path>/SKILL.md`

Exit codes:

- `0`: all validated files are compliant
- non-zero: validation/usage errors (prints `error:` lines to stderr)

### Lint + syntax checks

`scripts/lint.sh` runs:

- Shell: `shellcheck` (bash) + `bash -n` + `zsh -n` (shebang-based)
- Python: `ruff` + `mypy`

Usage:

- Lint everything: `scripts/lint.sh`
- Shell only: `scripts/lint.sh --shell`
- Python only: `scripts/lint.sh --python`

## Semgrep

Use `semgrep-scan.sh` to run `.semgrep.yaml` plus curated Semgrep Registry packs.

Examples:

- Shell scripts only: `scripts/semgrep-scan.sh --profile shell`
