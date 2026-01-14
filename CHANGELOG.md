# Changelog

All notable changes to this project will be documented in this file.

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
