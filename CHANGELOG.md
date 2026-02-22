# Changelog

All notable changes to this project will be documented in this file.

## v2.2.8 - 2026-02-19

### Changed
- Docker runtime defaults now point `CODEX_AUTH_FILE` to `$HOME/.codex/auth.json` in compose and workspace launch flows.

### Fixed
- `docker/agent-env/bin/entrypoint.sh` now falls back `CODEX_HOME` to `$HOME/.codex` and defaults `CODEX_AUTH_FILE` to `$CODEX_HOME/auth.json`.

## v2.2.7 - 2026-02-18

### Added
- `close-feature-pr`: automatically ready draft PRs before merge.
- `deliver-feature-pr`: add explicit preflight ambiguity bypass support.
- `create-project-skill`: auto-prefix generated skill names.
- Devex: add the `codex-notify` desktop notification wrapper.
- Scripts: add a `clean-untracked` helper command.

### Changed
- Environment/home-variable migration: standardize on `AGENT_HOME`/`agents_home` naming across docs and scripts, plus `agent-env` naming updates.
- Branding/docs: sync `codex-kit` references to `agent-kit` and refresh workspace-launcher guidance.
- Docker: simplify agent-environment path defaults and add an `agent-env` overview.
- Workflows: update env-var references and align preflight/release documentation.

### Fixed
- Env resolution: remove inconsistent `AGENTS_HOME` fallback usage in runtime scripts and skills.
- `agent-doc-init`: align home-resolution behavior with `AGENT_HOME`.
- `workspace-launcher`: normalize workspace container naming.
- Media tests: align screen-record test environment-variable handling.

## v2.2.6 - 2026-02-13

### Added
- `create-feature-pr`: support kickoff-first draft PR flow.
- `deliver-feature-pr`: add dirty preflight triage support.

### Changed
- Runbooks: document Codex Cloud setup for Ubuntu and ensure Linuxbrew path guidance.
- `handoff-progress-pr`: align handoff guidance with progress-derived PR flags.
- Docker: pin `zsh-kit` reference to `nils-cli` for image builds.

### Fixed
- `create-feature-pr`: remove legacy Status section and harden progress URL resolution checks.
- `close-feature-pr`: enforce paired progress metadata hygiene.
- `deliver-feature-pr`: handle empty arrays safely under `set -u`.
- CI/scripts: harden Homebrew install workflow and add install-homebrew help mode.
- Semgrep profile: allow scanning the `commands/` directory.
- Progress docs: correct archived plan path references.

## v2.2.5 - 2026-02-09

### Changed
- Align `screen-record` skill contract and guide with current CLI behavior: screenshot mode, selector/mode gates, diagnostics flags (`--metadata-out`, `--diagnostics-out`), and `--if-changed*`.
- Refresh `screen-record` assistant response template to distinguish recording vs screenshot completion details.
- Expand `macos-agent-ops` workflow docs with permission preflight (`preflight --include-probes`) and diff-aware screenshot triage patterns.

### Fixed
- Add doc-guard tests for `screen-record` and `macos-agent-ops` skills so key CLI usage examples do not drift.

## v2.2.4 - 2026-02-09

### Added
- New `deliver-feature-pr` workflow skill for create-PR -> CI-fix loop -> close-PR delivery.
- New `create-project-skill` workflow under skill-management.
- New `macos-agent-ops` skill for Homebrew `macos-agent` app automation routines.
- Browser tooling now includes `chrome-devtools-debug-companion` in place of site-search workflow.
- `create-skill` now updates the skill catalog during scaffolding.

### Changed
- Agent-doc dispatcher docs tightened strict preflight flow and baseline fallback handling.
- Playwright workflow now requires MCP output under `out/playwright`.
- Developer/docs updates for local executable workflow and README skill index clarifications.
- Legacy command binaries were removed from `commands/`.

### Fixed
- `macos-agent-ops` guidance and rules now align with AX/input-source workflows.
- US input-source detection and empty-string initializer handling were hardened in macOS agent scripts.
- `deliver-feature-pr` skill metadata quoting was corrected.
- `deliver-feature-pr` script now uses shell-style single-quoted empty `local` initializers.

## v2.2.3 - 2026-02-07

### Fixed
- `release-workflow`: harden strict audit allow-dirty array handling under `set -u`.
- `release-workflow`: handle empty allow-dirty input safely in strict mode.

## v2.2.2 - 2026-02-07

### Added
- Agent docs: roll out core `startup` / `task-tools` / `project-dev` / `skill-dev` contexts and trial tooling.
- Tests: add missing smoke specs for previously uncovered scripts.

### Changed
- Docs: document the research workflow and update README media-skill platform support.
- Docs: align `gh-fix-ci` CI-watch command guidance with 10-second interval behavior.
- Tests: remove the orphan `image-processing` smoke spec.

### Fixed
- `agent-doc-init`: avoid `mapfile` usage in project required-file parsing for broader shell compatibility.
- `create-feature-pr`: omit optional PR sections when they resolve to `None`.
- `release-workflow`: allow strict release audit with changelog-only dirty state via `--allow-dirty-path`.
- `script-smoke`: align feature PR smoke cases with optional progress-section handling.

## v2.2.1 - 2026-02-06

### Added
- Browser automation: add the `playwright` skill and wrapper CLI help flow.
- Media capture: add `screen-record` and `screenshot` skills, including desktop screenshot mode.
- Testing: add `api-test-runner` local GraphQL fixture coverage in CI.

### Changed
- Skills/docs: align `screen-record` and `screenshot` contracts with Linux and desktop-target behavior.
- Automation: relocate `gh-fix-ci` under automation workflows and refresh CI/workflow naming/filters.
- Tooling: migrate script entrypoints to `nils-cli` command wrappers and remove deprecated helper wrappers.

### Fixed
- Worktree cleanup: handle worktree paths containing spaces.
- Screenshot flow: avoid unnecessary macOS permission prompt when running list/discovery modes.
- PR workflows/tests: normalize empty-string quote handling and progress-section cleanup behavior.

## v2.2.0 - 2026-01-28

### Added
- Skills: publish `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md` and `scripts/skills/audit_skill_md_format.py` for SKILL.md format enforcement.
- Tests: add script-spec smoke coverage for `scripts/skills/audit_skill_md_format.py`.

### Changed
- Skills: enforce `## Contract` placement (Contract-first, short preamble) and update `create-skill` to scaffold SKILL.md from a shared template.
- Docs: expand and reorganize `image-processing` SKILL.md guidance to follow the Contract-first format.
- `semantic-commit`: forbid extra repo inspection commands to keep commit generation strictly staged-context driven.

### Fixed
- Plan tooling: detect TODO/TBD placeholders in required plan fields.

## v2.1.1 - 2026-01-26

### Added
- Docs: add `docker/agent-workspace-launcher/README.md`.
- Tests: add script-spec smoke coverage for more commands and skill scripts.

### Changed
- Docs: consolidate progress templates and refresh progress PR workflow docs.
- Skills: rename assistant response template references.
- `git-scope`: re-bundle from zsh-kit.

### Fixed
- `git-scope`: exit 0 when no matches are found.

## v2.1.0 - 2026-01-25

### Added
- SQL skills: `sql-postgres`, `sql-mysql`, and `sql-mssql` (plus shared tooling under `skills/tools/sql/_shared`).
- Plan: `docs/plans/sql-skills-db-migration-plan.md` for migrating existing DB tooling.

### Changed
- Scripts: consolidate DB connect tooling under the SQL skills and remove legacy `scripts/db-connect/{psql,mysql,mssql}.zsh`.
- Docs: update SQL/testing and progress workflow documentation to match the new layout.

### Fixed
- SQL scripts: pass shell style checks.
- Docs: fix archived progress doc glossary links.

## v2.0.3 - 2026-01-25

### Added
- Plan workflows: shared Plan Format v1 template at `skills/workflows/plan/_shared/assets/plan-template.md`.
- Plan tooling: `plan-tooling scaffold` helper to generate `docs/plans/*-plan.md` from the shared template.

### Changed
- `create-plan` / `create-plan-rigorous`: reference the shared plan template and requirements.
- Progress PR tooling: centralize shared progress templates/glossary/PR template under `skills/workflows/pr/progress/_shared`.
- Docs: trim README skill governance and skill management sections.

### Fixed
- Tests: update progress-tooling smoke script paths after progress tooling refactor.

## v2.0.2 - 2026-01-25

### Added
- None.

### Changed
- Docs: backfill `v2.0.1` changelog entry.
- Docs: clarify credential instructions for `agent-env`.

### Fixed
- None.

## v2.0.1 - 2026-01-25

### Added
- None.

### Changed
- Docs: clarify workflow docs.
- Docs: document `image-processing` skill.

### Fixed
- None.

## v2.0.0 - 2026-01-25

### Added
- Skill lifecycle tooling: `create-skill` and `remove-skill` skills.
- Skill governance tooling: `skill-governance` skill with layout + contract validation scripts.
- Per-skill tests for tracked skills, enforced via audits + CI.
- `image-processing` skill for convert/resize/crop/optimize workflows via ImageMagick.

### Changed
- Breaking: skills structure reorg (v2). The v1 `skills/` layout and prior skill entrypoints are not backward compatible.
- Plan tooling and progress PR workflow E2E driver are now shipped under `skills/workflows/**`.

### Fixed
- Lint workflows: route checks through the v2 skill governance entrypoints.
- `image-processing`: add missing shebang for `image_processing.py`.
- Tests: ignore `.worktrees` to prevent noisy collection.

## v1.5.0 - 2026-01-24

### Added
- Progress PR workflows: `worktree-stacked-feature-pr` and hardened progress PR automation for worktrees.
- Plan toolchain: plan lint/parse/batches scripts and `scripts/check.sh --plans` to keep plans executable and parallelizable.

### Changed
- CI: consolidate publish workflows into a single pipeline.
- Scripts: set `AGENT_HOME` to repo root by default for more resilient runs.
- Plans: remove internal dogfood/review planning docs (keep format + toolchain docs).

### Fixed
- Progress PR workflows: worktree-safety and idempotency fixes across close/handoff flows.
- `bundle-wrapper`: improve parsing of array-style arguments.
- Tests: fix git commit ban regex enforcement.

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
- `agent-env`: `prefetch-zsh-plugins.sh` with retry/backoff for plugin installs.
- `agent-env`: `PREFETCH_ZSH_PLUGINS` build arg to skip plugin prefetch.
- `agent-env`: `ZSH_PLUGIN_FETCH_RETRIES` build arg to tune retry attempts.

### Changed
- Dockerfile: move image metadata ARGs to the top for consistency.
- `agent-env`: move `CODEX_AUTH_FILE` export into `entrypoint.sh`.

### Fixed
- `api-report`: resolve `--out`/`--response` paths relative to the derived project root.

## v1.3.2 - 2026-01-22

### Added
- `agent-workspace`: launcher contract for capability discovery + JSON output; wrapper migration docs.
- `agent-workspace`: `--no-clone` option for bringing up an existing workspace without cloning.
- `agent-env`: GitHub Actions workflows for GHCR/Docker Hub publishing, including multi-arch (arm64) support and OCI labels.
- Lint: pyright typechecking in the Python lint workflow.
- `script_smoke`: spec coverage for `audit-skill-layout.sh`.

### Changed
- `agent-env`: use `tini` as init; add `rsync`/linuxbrew directory; disable weather/quote on boot; and improve mount override flows.
- CI: set `AGENT_HOME` globally, optimize multi-arch builds, and refresh runner labels.
- Docs: canonicalize script references to `$AGENT_HOME` and use `$HOME/` in path examples.
- `find-and-fix-bugs`: add problem + reproduction sections to the skill and PR template.
- Workspace auth: remove token env vars from the container for safer Git authentication.

### Fixed
- `api-report`: expand tilde paths and guard stdin response clashes.
- `git-scope`: handle `mktemp` fallback on macOS.
- `agent-workspace`: handle long container names when computing hostnames.
- Progress templates: repair the progress template symlink.
- Docs and tooling: fix duplicated `codex_home` references and clarify desktop notification word limit guidance.

## v1.3.1 - 2026-01-18

### Added
- Docker agent env (Ubuntu 24.04): root `Dockerfile` + compose, tool install scripts, and compose overlays for secrets/SSH/local overrides.
- Workspace launcher: `docker/agent-env/bin/agent-workspace` (`up/ls/shell/tunnel/rm`) with `--secrets-mount` support and improved auth/mount flows.
- Docker agent env docs: `docker/agent-env/README.md` and `docker/agent-env/WORKSPACE_QUICKSTART.md` (plus root README link).
- Git commit context JSON: new `commands/git-commit-context-json` wrapper and `git-tools` JSON output support.
- `close-progress-pr`: auto-defer unchecked checklist items and enforce deferred checklist formatting.

### Changed
- Docker env: clean up environment variables; add `CODEX_AUTH_FILE` config; default `CODEX_COMMANDS_PATH` and `ZSH_FEATURES`.
- `semantic-commit`: staged context now outputs a JSON + patch bundle and falls back to `git diff --staged` when wrappers are unavailable.
- Progress templates: clarify that unchecked Step 0–3 items must be struck with `Reason:` (Step 4 excluded).

### Fixed
- Shell style fixer: preserve initializer handling in `$AGENT_HOME/scripts/fix-zsh-typeset-initializers.zsh`.

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
- Semgrep tooling: `.semgrep.yaml`, `.semgrepignore`, and `$AGENT_HOME/scripts/semgrep-scan.sh` with curated defaults.
- `semgrep-find-and-fix` automation skill, including local config and PR/report templates.
- Repo verification tooling: `$AGENT_HOME/scripts/check.sh` and `$AGENT_HOME/scripts/lint.sh` (shellcheck/bash -n/zsh -n, ruff, mypy) plus dev configs (`ruff.toml`, `mypy.ini`, `requirements-dev.txt`).
- Shell style fixers: `$AGENT_HOME/scripts/fix-shell-style.zsh`, `$AGENT_HOME/scripts/fix-typeset-empty-string-quotes.zsh`, `$AGENT_HOME/scripts/fix-zsh-typeset-initializers.zsh`.
- API test report templates/metadata plus `api-gql`/`api-rest report-from-cmd` workflow helpers (REST + GraphQL).

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
- Standardized commands path resolution via `CODEX_COMMANDS_PATH` / `$AGENT_HOME/commands`.
- Release workflow moved into automation, resolves guides/templates deterministically, and audits the changelog pre-publish.
- PR workflows reduce redundant `gh` metadata lookups.
- `close-progress-pr` now auto-wraps deferred checklist items.
- Docs: commit workflow, automation commit guidance, and find-and-fix-bugs classification updates.
- Prompts: remove obsolete openspec prompt files.
- `.gitignore`: ignore `tmp/` directory.

### Fixed
- `git-tools`: clean up commit context temp file.
- `chrome-devtools-mcp`: use `AGENT_HOME` for default paths and expand tilde paths.
- `graphql-api-testing`: quote `AGENT_HOME` during script path rewrites.
- Shell scripts: address minor shellcheck warnings.
- Progress flow now caches PR body lookups.
- Git helper scripts load the progress bar lazily.

## v1.0.2 - 2026-01-14

### Added
- `script_smoke` pytest suite with spec-driven + fixture-based coverage across agent-kit scripts.
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
- Initial release of agent-kit (prompts, skills, scripts, and docs).
- Release workflow fallback template and helper scripts for changelog-driven GitHub releases.

### Changed
- None (initial release).

### Fixed
- None (initial release).
