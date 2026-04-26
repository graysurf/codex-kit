# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **release**: new curator-only release entrypoint at
  `.agents/scripts/release.sh`. Runs preflight + `scripts/check.sh --all`,
  promotes `## [Unreleased]` into the versioned heading, updates the footer
  compare-link block, commits via `semantic-commit`, pushes main, and
  delegates the GitHub release publish to
  `skills/automation/release-workflow/scripts/release-publish-from-changelog.sh`.

### Changed

- **release-workflow**: align `CHANGELOG.md` to Keep a Changelog format —
  bracketed headings (`## [X.Y.Z] - YYYY-MM-DD` and `## [Unreleased]`),
  per-version footer compare-links, and removal of empty `- None.` placeholder
  bullets across the historical record (37 versions).
- **release-workflow**: `release-publish-from-changelog.sh` now accepts both
  legacy `## vX.Y.Z` and new bracketed `## [X.Y.Z]` headings, and stops at
  footer link references so trailing compare-links never leak into release
  notes. `RELEASE_TEMPLATE.md` and `DEFAULT_RELEASE_GUIDE.md` updated to match.
- **release-workflow**: GitHub release bodies now start with the release date
  only; the publish script strips the changelog version prefix from
  `## [X.Y.Z] - YYYY-MM-DD` while leaving `CHANGELOG.md` itself in Keep a
  Changelog format.
- **DEVELOPMENT.md**: document the CHANGELOG curator contract — authors keep
  `## [Unreleased]` populated as work lands, release tooling only promotes,
  and `.agents/scripts/release.sh` is the canonical release entrypoint.
- **Breaking — requires `nils-cli` ≥ 0.8.0.** `agent-docs` and `plan-issue` no
  longer auto-read `AGENT_HOME`. agent-docs runbooks (`AGENTS.md`,
  `DEVELOPMENT.md`, `RESEARCH_WORKFLOW.md`, `README.md`,
  `docs/runbooks/agent-docs/*`) now invoke
  `agent-docs --docs-home "$AGENT_HOME" ...`; the `plan-issue-delivery` skill
  and the main/subagent init prompts require `plan-issue --state-dir "$AGENT_HOME"`
  (or `PLAN_ISSUE_HOME="$AGENT_HOME"`) to keep runtime artefacts under
  `$AGENT_HOME/out/plan-issue-delivery/...`.
- `skills/tools/agent-doc-init/scripts/agent_doc_init.sh`: renamed
  `--agent-home` to `--docs-home` and now propagates `--docs-home` to
  `agent-docs`. Resolution precedence is `--docs-home` ->
  `AGENT_DOCS_HOME` -> `AGENT_HOME` -> `$HOME/.agents`.
- `scripts/install-homebrew-nils-cli.sh` now enforces a `nils-cli >= 0.8.0`
  floor by checking both `agent-docs --version` and `plan-issue --version`
  after install (and on the already-installed early-exit path).
- `docs/testing/docs-freshness-rules.md`: updated `REQUIRED_COMMAND` entries
  for the renamed `agent-docs` invocations.

## [2.4.1] - 2026-04-23

### Added

- Repository-level `AGENTS.md` policy and `AGENT_DOCS.toml` configuration now make repo-local agent-docs startup and development
  preflights explicit.
- New `google-sheets-cell-edit` skill under `skills/tools/computer-use/`, including its helper script and regression coverage.
- Agent-docs now includes a canonical zsh shell environment contract runbook.

### Changed

- `release-workflow` publish tooling now guards against unsynced upstream state and supports pushing the current branch through the
  fallback release publish entrypoint (#236).
- Agent-docs and issue-workflow documentation now use environment-resolved home paths instead of hardcoded local paths.

### Fixed

- Skill entrypoint ownership checks now scope parity validation to tracked files.
- Markdown lint wrapping was corrected for the Google Sheets cell-edit skill guidance and zsh shell environment contract.

## [2.4.0] - 2026-04-01

### Added

- `plan-issue-delivery` now ships explicit runtime adapter install/sync/status tooling plus adapter templates for Codex, Claude Code,
  and OpenCode via `scripts/plan-issue-adapter` (#233).

### Changed

- Markdown linting now uses `rumdl` behind the existing audit/check entrypoints, with related prompt/docs cleanup and refreshed
  third-party artifact metadata (#234).
- The `image-processing` skill/docs now align with the current multi-format `convert --in` CLI, including raster inputs, `jpg` output,
  and current report artifacts (#235).

### Fixed

- `plan-issue-delivery` now tracks the Codex adapter config template as part of the runtime adapter rollout (#233).

## [2.3.9] - 2026-03-08

### Added

- Shared `create-plan`/`create-plan-rigorous` plan-authoring baseline reference at
  `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md` and shared pytest helpers under
  `skills/workflows/plan/_shared/python/` (#232).

### Changed

- `create-plan` now points to a single shared baseline for plan authoring, executability, and grouping rules while keeping only base-skill
  deltas locally (#231, #232).
- `create-plan-rigorous` now builds on the same shared baseline and keeps only rigorous-specific sizing, scorecard, and review guidance
  locally (#231, #232).
- The shared plan template now includes optional execution metadata and rigorous scorecard placeholders so the scaffold matches the actual
  workflow contract more closely (#232).

## [2.3.8] - 2026-03-04

### Added

- Final outcomes artifact at `docs/plans/skills-review-final-outcomes.md` with auditable keep/remove decisions and explicit migration mapping
  for removed entrypoints.

### Changed

- Repo-level docs were aligned to the finalized skill/check surface, including canonical `scripts/check.sh` gates and entrypoint-drift guards
  in `PROJECT_DEV_WORKFLOW.md`.
- `README.md` structure notes now reflect current tracked directories and remove stale progress-log wording.
- `docs/testing/script-smoke.md` plan-issue cleanup example now uses the current `<owner__repo>` workspace slug convention.
- Obsolete `docs/plans` artifacts were removed, and legacy simplification notes were dropped from issue workflow script help text.
- `scripts/README.md` was refreshed to match the current script inventory and remove outdated sections.

## [2.3.7] - 2026-03-04

### Added

- Docs freshness audit coverage, including a dedicated helper and lint/local workflow integration (#214, #215).
- CI ownership/stale-script guardrails with refreshed regression smoke coverage for script specs (#212, #213).
- Local pre-commit check wrapper and updated developer command guidance (#219).

### Changed

- CI phase orchestration now centralizes bootstrap/setup and adds parity guardrails for check flows (#210, #211).
- `plan-issue-delivery` merge behavior now prefers squash, with merge fallback guidance for protected workflows (#220).
- Repository plan-doc artifacts and related plan checks were pruned as part of CI cleanup/refactor work (#219).

### Fixed

- CI stability issues across docs/ownership/lint/pytest lanes were resolved to unblock runner-safe execution (#217, #218).

## [2.3.6] - 2026-03-02

### Added

- Deterministic third-party artifact generation via `scripts/generate-third-party-artifacts.sh` for `THIRD_PARTY_LICENSES.md` and
  `THIRD_PARTY_NOTICES.md` (#205).
- Third-party artifact regression coverage, including dedicated pytest cases and smoke-spec entries for generator/audit script help flows
  (#205).

### Changed

- Local/CI required checks now enforce strict third-party artifact freshness through `scripts/ci/third-party-artifacts-audit.sh` in
  `scripts/check.sh --all` and the lint workflow (#205).
- Developer docs (`DEVELOPMENT.md`, `scripts/README.md`) now document the third-party artifact generation/audit workflow and command
  entrypoints (#205).

## [2.3.5] - 2026-03-02

### Changed

- `plan-issue-delivery` now enforces plan-branch integration and sync gates across task-lane flows (#204).

### Fixed

- `release-workflow` now enforces plain issue/PR references in release guidance and audits (#204).

## [2.3.4] - 2026-03-02

### Added

- `issue-pr-review` now ships a reusable review-evidence template to document decision rationale and merge/follow-up outcomes (#203).

### Changed

- Issue delivery workflows now standardize task-lane continuity and post-review sync expectations across main-agent/subagent handoffs (#200).
- `plan-issue-delivery` now requires main-agent init snapshot artifacts before dispatching sprint work (#202).
- `issue-pr-review` merge/request-followup/close flows now require evidence-gated decision inputs and validation hooks (#203).

### Fixed

- `scripts/project-resolve` now fails fast when required option values are missing, with updated smoke coverage (#201).

## [2.3.2] - 2026-02-27

### Added

- `plan-issue-delivery` now includes a worktree cleanup helper and associated smoke docs (#198).
- `plan-issue` now requires dispatch snapshot artifacts for run traceability.
- `plan-issue-delivery` test coverage now includes sprint1/sprint2 fixture artifact and PR normalization checks (#195, #196).

### Changed

- Plan-issue prompt/runbook guidance now clarifies worktree usage, approval flow, and sprint close-gate checklists (#197, #199).
- `plan-issue-delivery` now documents runtime workspace policy and resolves prompt paths via `AGENT_HOME`.
- Skill/docs metadata were normalized with strict markdown linting and updated issue-delivery automation slug naming.

### Fixed

- `issue-subagent-pr` now asserts dispatch snapshot environment variable names.
- README automation-skill listings now remove duplicate entries and restore missing plan-issue prompt preset references.

## [2.3.0] - 2026-02-25

### Added

- New bug PR workflows: `create-bug-pr`, `deliver-bug-pr`, and `close-bug-pr`.
- New issue workflows: `issue-lifecycle`, `issue-pr-review`, and `issue-subagent-pr`.
- New issue-delivery automation flows: `issue-delivery` and `plan-issue-delivery`.
- Plan-issue delivery prompts now support rendered subagent prompt enforcement.

### Changed

- Issue-delivery flows now use plan-issue CLI binaries and updated prompt/checklist guidance.
- `create-plan-rigorous` now includes split-PR sizing guidance and sprint scorecard guardrails.
- Legacy progress PR workflows were removed, with feature tooling simplified around issue/bug delivery paths.

### Fixed

- Issue workflows now enforce `pr-isolated` execution mode.
- `plan-issue-delivery` now returns clearer usage errors.
- Issue workflow smoke scripts now support Bash 3.2 compatibility.

## [2.2.9] - 2026-02-24

### Added

- New `docs-plan-cleanup` workflow skill to prune outdated `docs/plans` content and reconcile plan-related docs safely.

### Changed

- `docs-plan-cleanup` output now renders as markdown tables, with a bundled response template and test coverage.
- Documentation cleanup removed obsolete plan/runbook docs and refreshed progress index references.
- `find-and-fix-bugs` guidance now clarifies GitHub issue triage behavior.

### Fixed

- Feature PR close-cleanup scripts now handle git worktrees safely.
- `image-processing` skill docs/tests now align with the SVG-first CLI flow.
- Docker auth/home-path defaults are aligned for runtime tooling.

## [2.2.8] - 2026-02-19

### Changed

- Docker runtime defaults now point `CODEX_AUTH_FILE` to `$HOME/.codex/auth.json` in compose and workspace launch flows.

### Fixed

- `docker/agent-env/bin/entrypoint.sh` now falls back `CODEX_HOME` to `$HOME/.codex` and defaults `CODEX_AUTH_FILE` to
  `$CODEX_HOME/auth.json`.

## [2.2.7] - 2026-02-18

### Added

- `close-feature-pr`: automatically ready draft PRs before merge.
- `deliver-feature-pr`: add explicit preflight ambiguity bypass support.
- `create-project-skill`: auto-prefix generated skill names.
- Devex: add the `codex-notify` desktop notification wrapper.
- Scripts: add a `clean-untracked` helper command.

### Changed

- Environment/home-variable migration: standardize on `AGENT_HOME`/`agents_home` naming across docs and scripts, plus `agent-env` naming
  updates.
- Branding/docs: sync `codex-kit` references to `agent-kit` and refresh workspace-launcher guidance.
- Docker: simplify agent-environment path defaults and add an `agent-env` overview.
- Workflows: update env-var references and align preflight/release documentation.

### Fixed

- Env resolution: remove inconsistent `AGENTS_HOME` fallback usage in runtime scripts and skills.
- `agent-doc-init`: align home-resolution behavior with `AGENT_HOME`.
- `workspace-launcher`: normalize workspace container naming.
- Media tests: align screen-record test environment-variable handling.

## [2.2.6] - 2026-02-13

### Added

- `create-feature-pr`: support kickoff-first draft PR flow.
- `deliver-feature-pr`: add dirty preflight triage support.

### Changed

- Runbooks: document Codex Cloud setup for Ubuntu and ensure Linuxbrew path guidance.
- Docker: pin `zsh-kit` reference to `nils-cli` for image builds.

### Fixed

- `create-feature-pr`: remove legacy Status section and harden progress URL resolution checks.
- `deliver-feature-pr`: handle empty arrays safely under `set -u`.
- CI/scripts: harden Homebrew install workflow and add install-homebrew help mode.
- Semgrep profile: allow scanning the `commands/` directory.

## [2.2.5] - 2026-02-09

### Changed

- Align `screen-record` skill contract and guide with current CLI behavior: screenshot mode, selector/mode gates, diagnostics flags
  (`--metadata-out`, `--diagnostics-out`), and `--if-changed*`.
- Refresh `screen-record` assistant response template to distinguish recording vs screenshot completion details.
- Expand `macos-agent-ops` workflow docs with permission preflight (`preflight --include-probes`) and diff-aware screenshot triage patterns.

### Fixed

- Add doc-guard tests for `screen-record` and `macos-agent-ops` skills so key CLI usage examples do not drift.

## [2.2.4] - 2026-02-09

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

## [2.2.3] - 2026-02-07

### Fixed

- `release-workflow`: harden strict audit allow-dirty array handling under `set -u`.
- `release-workflow`: handle empty allow-dirty input safely in strict mode.

## [2.2.2] - 2026-02-07

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

## [2.2.1] - 2026-02-06

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

## [2.2.0] - 2026-01-28

### Added

- Skills: publish `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md` and `scripts/skills/audit_skill_md_format.py` for SKILL.md format
  enforcement.
- Tests: add script-spec smoke coverage for `scripts/skills/audit_skill_md_format.py`.

### Changed

- Skills: enforce `## Contract` placement (Contract-first, short preamble) and update `create-skill` to scaffold SKILL.md from a shared
  template.
- Docs: expand and reorganize `image-processing` SKILL.md guidance to follow the Contract-first format.
- `semantic-commit`: forbid extra repo inspection commands to keep commit generation strictly staged-context driven.

### Fixed

- Plan tooling: detect TODO/TBD placeholders in required plan fields.

## [2.1.1] - 2026-01-26

### Added

- Docs: add `docker/agent-workspace-launcher/README.md`.
- Tests: add script-spec smoke coverage for more commands and skill scripts.

### Changed

- Docs: consolidate progress templates and refresh progress PR workflow docs.
- Skills: rename assistant response template references.
- `git-scope`: re-bundle from zsh-kit.

### Fixed

- `git-scope`: exit 0 when no matches are found.

## [2.1.0] - 2026-01-25

### Added

- SQL skills: `sql-postgres`, `sql-mysql`, and `sql-mssql` (plus shared tooling under `skills/tools/sql/_shared`).
- Plan: `docs/plans/sql-skills-db-migration-plan.md` for migrating existing DB tooling.

### Changed

- Scripts: consolidate DB connect tooling under the SQL skills and remove legacy `scripts/db-connect/{psql,mysql,mssql}.zsh`.
- Docs: update SQL/testing documentation to match the new layout.

### Fixed

- SQL scripts: pass shell style checks.

## [2.0.3] - 2026-01-25

### Added

- Plan workflows: shared Plan Format v1 template at `skills/workflows/plan/_shared/assets/plan-template.md`.
- Plan tooling: `plan-tooling scaffold` helper to generate `docs/plans/*-plan.md` from the shared template.

### Changed

- `create-plan` / `create-plan-rigorous`: reference the shared plan template and requirements.
- Docs: trim README skill governance and skill management sections.

### Fixed

- Tests: update plan-tooling smoke script paths after plan tooling refactor.

## [2.0.2] - 2026-01-25

### Changed

- Docs: backfill `v2.0.1` changelog entry.
- Docs: clarify credential instructions for `agent-env`.

## [2.0.1] - 2026-01-25

### Changed

- Docs: clarify workflow docs.
- Docs: document `image-processing` skill.

## [2.0.0] - 2026-01-25

### Added

- Skill lifecycle tooling: `create-skill` and `remove-skill` skills.
- Skill governance tooling: `skill-governance` skill with layout + contract validation scripts.
- Per-skill tests for tracked skills, enforced via audits + CI.
- `image-processing` skill for convert/resize/crop/optimize workflows via ImageMagick.

### Changed

- Breaking: skills structure reorg (v2). The v1 `skills/` layout and prior skill entrypoints are not backward compatible.
- Plan tooling is now shipped under `skills/workflows/**`.

### Fixed

- Lint workflows: route checks through the v2 skill governance entrypoints.
- `image-processing`: add missing shebang for `image_processing.py`.
- Tests: ignore `.worktrees` to prevent noisy collection.

## [1.5.0] - 2026-01-24

### Added

- Plan toolchain: plan lint/parse/batches scripts and `scripts/check.sh --plans` to keep plans executable and parallelizable.

### Changed

- CI: consolidate publish workflows into a single pipeline.
- Scripts: set `AGENT_HOME` to repo root by default for more resilient runs.
- Plans: remove internal dogfood/review planning docs (keep format + toolchain docs).

### Fixed

- `bundle-wrapper`: improve parsing of array-style arguments.
- Tests: fix git commit ban regex enforcement.

## [1.4.0] - 2026-01-23

### Added

- Planning workflows: `create-plan`, `create-plan-rigorous`, and `execute-plan-parallel` skills (plus `docs/plans/` convention).

### Fixed

- `git-scope`: use literal prefix matching for tracked filters.
- `graphql-api-testing`: prevent xh/HTTPie from reading stdin in non-interactive runs.

## [1.3.3] - 2026-01-22

### Added

- `agent-env`: `prefetch-zsh-plugins.sh` with retry/backoff for plugin installs.
- `agent-env`: `PREFETCH_ZSH_PLUGINS` build arg to skip plugin prefetch.
- `agent-env`: `ZSH_PLUGIN_FETCH_RETRIES` build arg to tune retry attempts.

### Changed

- Dockerfile: move image metadata ARGs to the top for consistency.
- `agent-env`: move `CODEX_AUTH_FILE` export into `entrypoint.sh`.

### Fixed

- `api-report`: resolve `--out`/`--response` paths relative to the derived project root.

## [1.3.2] - 2026-01-22

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

## [1.3.1] - 2026-01-18

### Added

- Docker agent env (Ubuntu 24.04): root `Dockerfile` + compose, tool install scripts, and compose overlays for secrets/SSH/local overrides.
- Workspace launcher: `docker/agent-env/bin/agent-workspace` (`up/ls/shell/tunnel/rm`) with `--secrets-mount` support and improved
  auth/mount flows.
- Docker agent env docs: `docker/agent-env/README.md` and `docker/agent-env/WORKSPACE_QUICKSTART.md` (plus root README link).
- Git commit context JSON: new `commands/git-commit-context-json` wrapper and `git-tools` JSON output support.

### Changed

- Docker env: clean up environment variables; add `CODEX_AUTH_FILE` config; default `CODEX_COMMANDS_PATH` and `ZSH_FEATURES`.
- `semantic-commit`: staged context now outputs a JSON + patch bundle and falls back to `git diff --staged` when wrappers are unavailable.

### Fixed

- Shell style fixer: preserve initializer handling in `$AGENT_HOME/scripts/fix-zsh-typeset-initializers.zsh`.

## [1.3.0] - 2026-01-17

### Added

- Skill layout audit now enforces `TEMPLATE` markdown placement under `references/` or `assets/templates/`.

### Changed

- Docs: update template placement guidance.

## [1.2.0] - 2026-01-16

### Added

- Semgrep tooling: `.semgrep.yaml`, `.semgrepignore`, and `$AGENT_HOME/scripts/semgrep-scan.sh` with curated defaults.
- `semgrep-find-and-fix` automation skill, including local config and PR/report templates.
- Repo verification tooling: `$AGENT_HOME/scripts/check.sh` and `$AGENT_HOME/scripts/lint.sh` (shellcheck/bash -n/zsh -n, ruff, mypy) plus
  dev configs (`ruff.toml`, `mypy.ini`, `requirements-dev.txt`).
- Shell style fixers: `$AGENT_HOME/scripts/fix-shell-style.zsh`, `$AGENT_HOME/scripts/fix-typeset-empty-string-quotes.zsh`,
  `$AGENT_HOME/scripts/fix-zsh-typeset-initializers.zsh`.
- API test report templates/metadata plus `api-gql`/`api-rest report-from-cmd` workflow helpers (REST + GraphQL).

### Changed

- CI: lint workflow now validates skill contracts and runs stricter Python type checks.
- Repo checks: rename `verify.sh` to `check.sh` and split checks into modular flags.
- GraphQL/REST helpers: improve report formatting, quoting, and metadata.

### Fixed

- Workflows: remove `eval` usage and parse `project-resolve` JSON safely during releases.
- Semgrep: sanitize test fixtures for stable scans.
- `api-test-runner`: fix quoting for `ACCESS_TOKEN` in the docs snippet.

## [1.1.0] - 2026-01-15

### Added

- Top-level `commands/` directory exposing reusable primitives (`git-scope`, `git-tools`, `project-resolve`).
- Functional script coverage reporting for smoke tests.
- `open-changed-files-review` code-path override option.

### Changed

- Command wrappers are now shipped via `commands/` (instead of a `scripts/` loader).
- Standardized commands path resolution via `CODEX_COMMANDS_PATH` / `$AGENT_HOME/commands`.
- Release workflow moved into automation, resolves guides/templates deterministically, and audits the changelog pre-publish.
- PR workflows reduce redundant `gh` metadata lookups.
- Docs: commit workflow, automation commit guidance, and find-and-fix-bugs classification updates.
- Prompts: remove obsolete openspec prompt files.
- `.gitignore`: ignore `tmp/` directory.

### Fixed

- `git-tools`: clean up commit context temp file.
- `chrome-devtools-mcp`: use `AGENT_HOME` for default paths and expand tilde paths.
- `graphql-api-testing`: quote `AGENT_HOME` during script path rewrites.
- Shell scripts: address minor shellcheck warnings.

## [1.0.2] - 2026-01-14

### Added

- `script_smoke` pytest suite with spec-driven + fixture-based coverage across agent-kit scripts.
- Hermetic stubs under `tests/stubs/bin/**` (DB clients, HTTP clients, `gh`, and misc tools) for CI-friendly runs.
- Docs and helpers for managing the smoke test expansion plan.

### Changed

- CI: upload `script_smoke` artifacts and add API test runner workflows for demos/fixtures.
- Smoke coverage expanded via Step 2 planned PRs.

### Fixed

- `git-scope` smoke spec now tracks the archived plan file path.

## [1.0.1] - 2026-01-13

### Added

- Pytest-based script regression suite and docs.
- MIT license.

### Changed

- CI: run pytest in lint workflow.
- PR workflows: standardize planning PR references and reduce `gh` calls.

### Fixed

- PR merge script now avoids unsupported `gh pr merge --yes` flag.

## [1.0.0] - 2026-01-13

### Added

- Initial release of agent-kit (prompts, skills, scripts, and docs).
- Release workflow fallback template and helper scripts for changelog-driven GitHub releases.

[unreleased]: https://github.com/graysurf/agent-kit/compare/v2.4.1...HEAD
[2.4.1]: https://github.com/graysurf/agent-kit/releases/tag/v2.4.1
[2.4.0]: https://github.com/graysurf/agent-kit/releases/tag/v2.4.0
[2.3.9]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.9
[2.3.8]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.8
[2.3.7]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.7
[2.3.6]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.6
[2.3.5]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.5
[2.3.4]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.4
[2.3.2]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.2
[2.3.0]: https://github.com/graysurf/agent-kit/releases/tag/v2.3.0
[2.2.9]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.9
[2.2.8]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.8
[2.2.7]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.7
[2.2.6]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.6
[2.2.5]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.5
[2.2.4]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.4
[2.2.3]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.3
[2.2.2]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.2
[2.2.1]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.1
[2.2.0]: https://github.com/graysurf/agent-kit/releases/tag/v2.2.0
[2.1.1]: https://github.com/graysurf/agent-kit/releases/tag/v2.1.1
[2.1.0]: https://github.com/graysurf/agent-kit/releases/tag/v2.1.0
[2.0.3]: https://github.com/graysurf/agent-kit/releases/tag/v2.0.3
[2.0.2]: https://github.com/graysurf/agent-kit/releases/tag/v2.0.2
[2.0.1]: https://github.com/graysurf/agent-kit/releases/tag/v2.0.1
[2.0.0]: https://github.com/graysurf/agent-kit/releases/tag/v2.0.0
[1.5.0]: https://github.com/graysurf/agent-kit/releases/tag/v1.5.0
[1.4.0]: https://github.com/graysurf/agent-kit/releases/tag/v1.4.0
[1.3.3]: https://github.com/graysurf/agent-kit/releases/tag/v1.3.3
[1.3.2]: https://github.com/graysurf/agent-kit/releases/tag/v1.3.2
[1.3.1]: https://github.com/graysurf/agent-kit/releases/tag/v1.3.1
[1.3.0]: https://github.com/graysurf/agent-kit/releases/tag/v1.3.0
[1.2.0]: https://github.com/graysurf/agent-kit/releases/tag/v1.2.0
[1.1.0]: https://github.com/graysurf/agent-kit/releases/tag/v1.1.0
[1.0.2]: https://github.com/graysurf/agent-kit/releases/tag/v1.0.2
[1.0.1]: https://github.com/graysurf/agent-kit/releases/tag/v1.0.1
[1.0.0]: https://github.com/graysurf/agent-kit/releases/tag/v1.0.0
