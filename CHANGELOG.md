# Changelog

All notable changes to this project will be documented in this file.

## v1.3.1 - 2026-01-18

### Added
- Docker codex env docs: root Dockerfile/compose usage, publish guide, and local override compose.
- Root README link to the Docker environment docs.

### Changed
- None.

### Fixed
- None.

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
- Semgrep tooling: `.semgrep.yaml`, `.semgrepignore`, and `scripts/semgrep-scan.sh` with curated defaults.
- `semgrep-find-and-fix` automation skill, including local config and PR/report templates.
- Repo verification tooling: `scripts/check.sh` and `scripts/lint.sh` (shellcheck/bash -n/zsh -n, ruff, mypy) plus dev configs (`ruff.toml`, `mypy.ini`, `requirements-dev.txt`).
- Shell style fixers: `scripts/fix-shell-style.zsh`, `scripts/fix-typeset-empty-string-quotes.zsh`, `scripts/fix-zsh-typeset-initializers.zsh`.
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
