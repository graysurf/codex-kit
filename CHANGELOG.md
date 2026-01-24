# Changelog

All notable changes to this project will be documented in this file.

## v1.4.0 - 2026-01-23

### Added
- Planning workflows: `create-plan`, `create-plan-rigorous`, and `execute-plan-parallel` skills (plus `docs/plans/` convention).

### Changed
- None.

### Fixed
- `git-scope`: use literal prefix matching for tracked filters.
- `graphql-api-testing`: prevent xh/HTTPie from reading stdin in non-interactive runs.

## v1.3.3 - 2026-01-22

### Added
- `codex-env`: `prefetch-zsh-plugins.sh` with retry/backoff for plugin installs.
- `codex-env`: `PREFETCH_ZSH_PLUGINS` build arg to skip plugin prefetch.
- `codex-env`: `ZSH_PLUGIN_FETCH_RETRIES` build arg to tune retry attempts.

### Changed
- Dockerfile: move image metadata ARGs to the top for consistency.
- `codex-env`: move `CODEX_AUTH_FILE` export into `entrypoint.sh`.

### Fixed
- `api-report`: resolve `--out`/`--response` paths relative to the derived project root.

## v1.3.2 - 2026-01-22

### Added
- `codex-workspace`: launcher contract for capability discovery + JSON output; wrapper migration docs.
- `codex-workspace`: `--no-clone` option for bringing up an existing workspace without cloning.
- `codex-env`: GitHub Actions workflows for GHCR/Docker Hub publishing, including multi-arch (arm64) support and OCI labels.
- Lint: pyright typechecking in the Python lint workflow.
- `script_smoke`: spec coverage for `audit-skill-layout.sh`.

### Changed
- `codex-env`: use `tini` as init; add `rsync`/linuxbrew directory; disable weather/quote on boot; and improve mount override flows.
- CI: set `CODEX_HOME` globally, optimize multi-arch builds, and refresh runner labels.
- Docs: canonicalize script references to `$CODEX_HOME` and use `$HOME/` in path examples.
- `find-and-fix-bugs`: add problem + reproduction sections to the skill and PR template.
- Workspace auth: remove token env vars from the container for safer Git authentication.

### Fixed
- `api-report`: expand tilde paths and guard stdin response clashes.
- `git-scope`: handle `mktemp` fallback on macOS.
- `codex-workspace`: handle long container names when computing hostnames.
- Progress templates: repair the progress template symlink.
- Docs and tooling: fix duplicated `codex_home` references and clarify desktop notification word limit guidance.

## v1.3.1 - 2026-01-18

### Added
- Docker codex env (Ubuntu 24.04): root `Dockerfile` + compose, tool install scripts, and compose overlays for secrets/SSH/local overrides.
- Workspace launcher: `docker/codex-env/bin/codex-workspace` (`up/ls/shell/tunnel/rm`) with `--secrets-mount` support and improved auth/mount flows.
- Docker codex env docs: `docker/codex-env/README.md` and `docker/codex-env/WORKSPACE_QUICKSTART.md` (plus root README link).
- Git commit context JSON: new `commands/git-commit-context-json` wrapper and `git-tools` JSON output support.
- `close-progress-pr`: auto-defer unchecked checklist items and enforce deferred checklist formatting.

### Changed
- Docker env: clean up environment variables; add `CODEX_AUTH_FILE` config; default `CODEX_COMMANDS_PATH` and `ZSH_FEATURES`.
- `semantic-commit`: staged context now outputs a JSON + patch bundle and falls back to `git diff --staged` when wrappers are unavailable.
- Progress templates: clarify that unchecked Step 0–3 items must be struck with `Reason:` (Step 4 excluded).

### Fixed
- Shell style fixer: preserve initializer handling in `$CODEX_HOME/scripts/fix-zsh-typeset-initializers.zsh`.

## v1.3.0 - 2026-01-17

### Added
- Skill layout audit now enforces `TEMPLATE` markdown placement under `references/` or `assets/templates/`.

### Changed
- `create-progress-pr` defaults now source the progress template from `assets/templates/`.
- Progress docs updated to reflect template placement guidance.

### Fixed
- None.

## v1.2.0 - 2026-01-16

### Added
- Semgrep tooling: `.semgrep.yaml`, `.semgrepignore`, and `$CODEX_HOME/scripts/semgrep-scan.sh` with curated defaults.
- `semgrep-find-and-fix` automation skill, including local config and PR/report templates.
- Repo verification tooling: `$CODEX_HOME/scripts/check.sh` and `$CODEX_HOME/scripts/lint.sh` (shellcheck/bash -n/zsh -n, ruff, mypy) plus dev configs (`ruff.toml`, `mypy.ini`, `requirements-dev.txt`).
- Shell style fixers: `$CODEX_HOME/scripts/fix-shell-style.zsh`, `$CODEX_HOME/scripts/fix-typeset-empty-string-quotes.zsh`, `$CODEX_HOME/scripts/fix-zsh-typeset-initializers.zsh`.
- `commands/api-report-from-cmd` helper and API test report templates/metadata (REST + GraphQL).

### Changed
- CI: lint workflow now validates skill contracts and runs stricter Python type checks.
- Repo checks: rename `verify.sh` to `check.sh` and split checks into modular flags.
- GraphQL/REST helpers: improve report formatting, quoting, and metadata.

### Fixed
- Workflows: remove `eval` usage and parse `project-resolve` JSON safely during releases.
- Semgrep: sanitize test fixtures for stable scans.
- `api-test-runner`: fix quoting for `ACCESS_TOKEN` in the docs snippet.

## v1.1.0 - 2026-01-15

### Added
- Top-level `commands/` directory exposing reusable primitives (`git-scope`, `git-tools`, `project-resolve`).
- Functional script coverage reporting for smoke tests.
- Auto-strikethrough test cases for `close-progress-pr`.
- `open-changed-files-review` code-path override option.

### Changed
- Command wrappers are now shipped via `commands/` (instead of a `scripts/` loader).
- Standardized commands path resolution via `CODEX_COMMANDS_PATH` / `$CODEX_HOME/commands`.
- Release workflow moved into automation, resolves guides/templates deterministically, and audits the changelog pre-publish.
- PR workflows reduce redundant `gh` metadata lookups.
- `close-progress-pr` now auto-wraps deferred checklist items.
- Docs: commit workflow, automation commit guidance, and find-and-fix-bugs classification updates.
- Prompts: remove obsolete openspec prompt files.
- `.gitignore`: ignore `tmp/` directory.

### Fixed
- `git-tools`: clean up commit context temp file.
- `chrome-devtools-mcp`: use `CODEX_HOME` for default paths and expand tilde paths.
- `graphql-api-testing`: quote `CODEX_HOME` during script path rewrites.
- Shell scripts: address minor shellcheck warnings.
- Progress flow now caches PR body lookups.
- Git helper scripts load the progress bar lazily.

## v1.0.2 - 2026-01-14

### Added
- `script_smoke` pytest suite with spec-driven + fixture-based coverage across codex-kit scripts.
- Hermetic stubs under `tests/stubs/bin/**` (DB clients, HTTP clients, `gh`, and misc tools) for CI-friendly runs.
- Docs and helpers for managing the smoke test expansion plan.

### Changed
- CI: upload `script_smoke` artifacts and add API test runner workflows for demos/fixtures.
- Smoke coverage expanded via Step 2 planned PRs (per progress inventory).

### Fixed
- `close-progress-pr`: avoid hard `rg` dependency.
- `git-scope` smoke spec now tracks the archived progress file path.

## v1.0.1 - 2026-01-13

### Added
- Pytest-based script regression suite and docs.
- MIT license.

### Changed
- CI: run pytest in lint workflow.
- PR workflows: standardize planning PR references and reduce `gh` calls.

### Fixed
- PR merge script now avoids unsupported `gh pr merge --yes` flag.

## v1.0.0 - 2026-01-13

### Added
- Initial release of codex-kit (prompts, skills, scripts, and docs).
- Release workflow fallback template and helper scripts for changelog-driven GitHub releases.

### Changed
- None (initial release).

### Fixed
- None (initial release).
