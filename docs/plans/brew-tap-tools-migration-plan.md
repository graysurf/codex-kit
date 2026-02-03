# Plan: Migrate codex-kit Tooling to Homebrew Tap (nils-cli) + Move project-resolve

## Overview
This plan removes the repo’s dependency on vendored binaries under `commands/` and the `CODEX_COMMANDS_PATH` env var.
Instead, required “binary tools” will be installed via Homebrew using the `graysurf/tap` tap (specifically the `nils-cli` formula),
and all docs/scripts/CI will invoke those tools from `PATH`.
Additionally, `commands/project-resolve` will be moved into `scripts/` as a repo-local helper (since it is not part of `nils-cli`).

## Scope
- In scope:
  - Move `commands/project-resolve` to `scripts/project-resolve` and update all call sites.
  - Update docs to describe install/upgrade via Homebrew tap (based on the `graysurf/homebrew-tap` README install method).
  - Update scripts/skills to stop using `CODEX_COMMANDS_PATH` and stop reaching into `commands/` for binaries.
  - Update CI to install required tools on macOS + Ubuntu and run the correct checks/tests.
  - Update local tests so `scripts/check.sh --all` works when tools are installed via Homebrew.
- Out of scope:
  - Changing/publishing Homebrew formulae (assume `graysurf/tap` + `nils-cli` already exist and stay the source of truth).
  - Removing the `commands/` directory entirely (can be a follow-up cleanup once everything is migrated).
  - Rewriting historical records (`CHANGELOG.md`, `docs/progress/archived/**`) just to remove `CODEX_COMMANDS_PATH` mentions.

## Assumptions
1. Homebrew tap `graysurf/tap` is the canonical distribution channel for the “codex-kit binary tools”.
2. Installing `nils-cli` provides these required binaries on both macOS and Ubuntu (Linuxbrew): `api-gql`, `api-rest`, `api-test`, `cli-template`, `fzf-cli`, `git-lock`, `git-scope`, `git-summary`, `image-processing`, `plan-tooling`, `semantic-commit`.
3. `project-resolve` remains a repo-local script (installed/used via `$CODEX_HOME/scripts/project-resolve`), not a Homebrew-installed binary.
4. CI is allowed to install Homebrew (Linuxbrew) on Ubuntu runners.

## Sprint 1: Decouple Runtime From `commands/` (Move project-resolve + PATH-Only Binaries)
**Goal**: No runtime script/workflow requires `CODEX_COMMANDS_PATH` or repo-local `commands/*` binaries to execute.
**Demo/Validation**:
- Command(s):
  - `brew tap graysurf/tap && brew install nils-cli`
  - `for t in api-test api-rest api-gql plan-tooling semantic-commit git-scope git-summary; do command -v \"$t\" >/dev/null && \"$t\" --help >/dev/null; done`
  - `plan-tooling validate --file docs/plans/brew-tap-tools-migration-plan.md`
- Verify:
  - `scripts/check.sh --plans` uses `plan-tooling` from `PATH`.
  - Release workflow scripts resolve via `scripts/project-resolve`.

### Task 1.1: Move `project-resolve` From `commands/` to `scripts/`
- **Location**:
  - `commands/project-resolve`
  - `scripts/project-resolve`
  - `scripts/README.md`
  - `scripts/build/README.md`
- **Description**: Move the bundled `project-resolve` executable script from `commands/project-resolve` to `scripts/project-resolve` (preserving behavior and CLI), and update any repo docs that still describe bundling/copying it into `commands/`.
- **Dependencies**:
  - none
- **Complexity**: 4
- **Acceptance criteria**:
  - `scripts/project-resolve --help` exits `0` and prints usage.
  - No repo docs instruct users to write to or run `commands/project-resolve`.
  - `commands/project-resolve` is no longer required for any workflow described in current docs.
- **Validation**:
  - `bash scripts/project-resolve --help >/dev/null`
  - `rg -n \"commands/project-resolve\" scripts docs | cat`

### Task 1.2: Update Release Workflow Scripts to Use `scripts/project-resolve`
- **Location**:
  - `skills/automation/release-workflow/scripts/release-resolve.sh`
  - `skills/automation/release-workflow/scripts/release-find-guide.sh`
  - `skills/automation/release-workflow/scripts/release-scaffold-entry.sh`
- **Description**: Replace `commands_dir`/`CODEX_COMMANDS_PATH` resolution with a direct call to `$CODEX_HOME/scripts/project-resolve` (with a repo-relative fallback when `CODEX_HOME` is unset) and remove dependency on `commands/project-resolve`.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Release workflow scripts no longer reference `CODEX_COMMANDS_PATH` or `commands/project-resolve`.
  - When run inside this repo with `CODEX_HOME` unset, scripts still locate and execute `scripts/project-resolve`.
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH|commands_dir|commands/project-resolve\" skills/automation/release-workflow/scripts | cat`
  - `bash skills/automation/release-workflow/scripts/release-resolve.sh --help >/dev/null`
  - `unset CODEX_COMMANDS_PATH; bash skills/automation/release-workflow/scripts/release-resolve.sh --repo . --format env >/dev/null`

### Task 1.3: Make Core Scripts/Workflows Use PATH for nils-cli Binaries
- **Location**:
  - `scripts/check.sh`
  - `skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh`
  - `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
- **Description**: Remove `CODEX_COMMANDS_PATH` and `CODEX_HOME/commands` fallback lookup for `plan-tooling`, `semantic-commit`, and `git-scope`; require them via `command -v`/`PATH` (installed by `brew install nils-cli`) and emit clear install instructions when missing.
- **Dependencies**:
  - none
- **Complexity**: 6
- **Acceptance criteria**:
  - `scripts/check.sh --plans` uses `plan-tooling` from `PATH` (no `commands_dir` logic).
  - Progress PR workflow scripts locate `semantic-commit` and `git-scope` via `PATH` only.
  - Error messages include the canonical install snippet: `brew tap graysurf/tap && brew install nils-cli`.
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH|/commands/\" scripts/check.sh skills/workflows/pr/progress | cat`
  - `bash scripts/check.sh --plans`
  - `PATH=\"/usr/bin:/bin\" bash scripts/check.sh --plans 2>&1 | grep -F \"brew tap graysurf/tap && brew install nils-cli\"`

## Sprint 2: Documentation + Skills (Brew Install/Upgrade, No `CODEX_COMMANDS_PATH`)
**Goal**: All user-facing docs and skill references describe Homebrew-based installation and PATH-based invocation.
**Demo/Validation**:
- Command(s):
  - `brew tap graysurf/tap && brew install nils-cli`
  - `api-test --help >/dev/null`
- Verify:
  - Docs no longer mention `CODEX_COMMANDS_PATH` for end users.

### Task 2.1: Rewrite Root README Setup to Use Homebrew Tap
- **Location**:
  - `README.md`
- **Description**: Rewrite the “Setup” section to document installing required binary tools via Homebrew tap (`brew tap graysurf/tap` + `brew install nils-cli`) and upgrading via `brew upgrade nils-cli`; remove any suggestion to set `CODEX_COMMANDS_PATH` or run binaries from `commands/`.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 4
- **Acceptance criteria**:
  - README includes explicit install + upgrade commands matching the `graysurf/homebrew-tap` README.
  - README contains no references to `CODEX_COMMANDS_PATH`.
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH\" README.md || true`
  - `python3 -c 'import pathlib; print(pathlib.Path(\"README.md\").read_text())' >/dev/null`

### Task 2.2: Update Runbooks/Docs to Use PATH-Based Commands
- **Location**:
  - `skills/automation/README.md`
  - `scripts/README.md`
  - `docs/plans/FORMAT.md`
  - `docs/plans/TOOLCHAIN.md`
  - `docs/runbooks/plan-workflow.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
- **Description**: Replace runnable examples that use repo-local command paths (for example `$CODEX_COMMANDS_PATH/plan-tooling` or `$CODEX_HOME/commands/plan-tooling`) with PATH-based invocations (`plan-tooling`, `api-test`, `api-rest`, `api-gql`, `semantic-commit`, etc.), and add a brief note that these come from `brew install nils-cli`.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Docs/runnable snippets no longer require `CODEX_COMMANDS_PATH`.
  - Plan tooling examples run as `plan-tooling ...` (no hardcoded repo paths).
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH\" skills/automation/README.md scripts/README.md docs/plans docs/runbooks | cat`
  - `plan-tooling validate --file docs/plans/brew-tap-tools-migration-plan.md`

### Task 2.3: Update Tool Skill Prereqs/Examples to Prefer PATH (brew `nils-cli`)
- **Location**:
  - `skills/tools/devex/semantic-commit/SKILL.md`
  - `skills/automation/semantic-commit-autostage/SKILL.md`
  - `skills/tools/testing/api-test-runner/SKILL.md`
  - `skills/tools/testing/rest-api-testing/SKILL.md`
  - `skills/tools/testing/graphql-api-testing/SKILL.md`
  - `skills/tools/media/image-processing/SKILL.md`
  - `skills/workflows/plan/create-plan/SKILL.md`
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
  - `skills/workflows/plan/execute-plan-parallel/SKILL.md`
- **Description**: Update skill prerequisites and examples to avoid `$CODEX_COMMANDS_PATH` and instead rely on tools being available on `PATH` after `brew install nils-cli`.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Skill docs no longer recommend `$CODEX_COMMANDS_PATH/...` as the primary invocation path.
  - Example commands shown in SKILL.md work when `nils-cli` is installed via Homebrew.
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH\" skills/tools skills/workflows skills/automation | cat`
  - `brew list nils-cli >/dev/null`

### Task 2.4: Update Tool Reference Guides + Report Templates (Prefer PATH)
- **Location**:
  - `skills/tools/testing/api-test-runner/references/API_TEST_RUNNER_GUIDE.md`
  - `skills/tools/testing/rest-api-testing/references/REST_API_TESTING_GUIDE.md`
  - `skills/tools/testing/rest-api-testing/references/REST_API_TEST_REPORT_TEMPLATE.md`
  - `skills/tools/testing/rest-api-testing/references/REST_API_TEST_REPORT_CONTRACT.md`
  - `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`
  - `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_TEMPLATE.md`
  - `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_CONTRACT.md`
- **Description**: Update the longer-form guides/templates/contracts to avoid `$CODEX_COMMANDS_PATH` and show PATH-based invocations (`api-test`, `api-rest`, `api-gql`, `plan-tooling`, etc.) aligned with `brew install nils-cli`.
- **Dependencies**:
  - Task 2.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Guides/templates/contracts no longer require `CODEX_COMMANDS_PATH` for the “happy path”.
  - Commands in these docs work when tools are installed via `brew install nils-cli`.
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH\" skills/tools/testing | cat`

### Task 2.5: Update Scaffolded Env File Comments (Prefer PATH)
- **Location**:
  - `skills/tools/testing/rest-api-testing/assets/scaffold/setup/rest/endpoints.env`
  - `skills/tools/testing/rest-api-testing/assets/scaffold/setup/rest/tokens.env`
  - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/endpoints.env`
  - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/jwts.env`
  - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/schema.env`
- **Description**: Update scaffolded comment examples to avoid `$CODEX_COMMANDS_PATH` and show PATH-based invocations aligned with `brew install nils-cli`.
- **Dependencies**:
  - Task 2.3
- **Complexity**: 3
- **Acceptance criteria**:
  - Scaffold comments no longer mention `CODEX_COMMANDS_PATH`.
  - Scaffold comments match the updated SKILL.md command examples.
- **Validation**:
  - `rg -n \"CODEX_COMMANDS_PATH\" skills/tools/testing/*/assets/scaffold | cat`

## Sprint 3: CI + Tests (macOS + Ubuntu) and Local Verification
**Goal**: CI installs nils-cli via Homebrew on both macOS and Ubuntu; tests and workflows no longer depend on vendored `commands/` binaries.
**Demo/Validation**:
- Command(s):
  - `brew tap graysurf/tap && brew install nils-cli`
  - `scripts/check.sh --all`
- Verify:
  - GitHub Actions green on `macos-latest` and `ubuntu-latest`.

### Task 3.1: Update Test Harness to Stop Using `CODEX_COMMANDS_PATH`
- **Location**:
  - `tests/conftest.py`
  - `tests/script_specs/commands/image-processing.json`
  - `tests/script_specs/commands/project-resolve.json`
  - `tests/test_script_smoke.py`
  - `tests/test_script_smoke_semantic_commit.py`
  - `tests/test_plan_scripts.py`
  - `skills/tools/devex/semantic-commit/tests/test_tools_devex_semantic_commit.py`
  - `tests/fixtures/plan/valid-plan.md`
  - `skills/_shared/python/skill_testing/assertions.py`
- **Description**: Remove test-time injection of `CODEX_COMMANDS_PATH` pointing at the repo `commands/` directory; update assertions to accept tools installed on `PATH` (via `nils-cli`) and update fixtures that mention `$CODEX_COMMANDS_PATH`.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 7
- **Acceptance criteria**:
  - Pytest passes locally with `nils-cli` installed and without setting `CODEX_COMMANDS_PATH`.
  - Script smoke tests resolve required tools via `PATH` (and fail with clear guidance when missing).
- **Validation**:
  - `unset CODEX_COMMANDS_PATH; brew tap graysurf/tap && brew install nils-cli`
  - `scripts/test.sh`

### Task 3.2: Update GitHub Actions to Install `nils-cli` (macOS + Ubuntu)
- **Location**:
  - `.github/workflows/lint.yml`
  - `.github/workflows/api-test-runner.yml`
- **Description**: Update workflows to install Homebrew + `graysurf/tap/nils-cli` on both macOS and Ubuntu runners, ensure Homebrew is on `PATH`, and update workflow commands to invoke `api-test`/`plan-tooling` from `PATH` (not `$CODEX_HOME/commands/...`).
- **Dependencies**:
  - Task 3.1
- **Complexity**: 8
- **Acceptance criteria**:
  - CI installs `nils-cli` successfully on `macos-latest` and `ubuntu-latest`.
  - `api-test-runner.yml` uses `api-test` from `PATH` and passes on both OSes (or documents OS-specific constraints explicitly in the workflow).
- **Validation**:
  - `rg -n \"\\$CODEX_HOME/commands/|CODEX_COMMANDS_PATH\" .github/workflows | cat`
  - Run the updated workflows on a PR (GitHub Actions).

### Task 3.3: Ensure Local “One Command” Verification Works With Brew Tooling
- **Location**:
  - `DEVELOPMENT.md`
  - `scripts/check.sh`
- **Description**: Update local dev docs and `scripts/check.sh` messaging so contributors can run `scripts/check.sh --all` after installing `nils-cli` via Homebrew; include a short “tooling prereqs” snippet and ensure failures point to the correct brew install commands.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 5
- **Acceptance criteria**:
  - `DEVELOPMENT.md` documents the Homebrew install command for required binaries.
  - `scripts/check.sh --all` passes on macOS and Ubuntu when prereqs are installed.
- **Validation**:
  - `scripts/check.sh --all`

## Testing Strategy
- Unit:
  - Keep existing pytest coverage; update tests to resolve tools via `PATH` instead of repo-local `commands/`.
- Integration:
  - Run `scripts/check.sh --all` locally with `brew install nils-cli`.
  - Run workflow entrypoint scripts (`close_progress_pr.sh`, `progress_pr_workflow.sh`, release-workflow scripts) with `--help` and minimal fixtures to ensure tool resolution works.
- E2E/manual:
  - On a fresh Ubuntu environment, install via Homebrew (Linuxbrew) and confirm `api-test --help`, `plan-tooling validate`, and `semantic-commit --help` run without needing this repo’s `commands/` directory.

## Risks & gotchas
- Ubuntu runners need Homebrew initialized correctly (shell env / PATH); otherwise binaries are installed but not found.
- Shell functions/aliases may shadow Homebrew-installed binaries (e.g. `git-scope`); scripts should prefer `command -v` and may need `unset -f` guidance if users have shadowing.
- Some tools may be macOS-only outside of `nils-cli`; keep the required set strictly to what `nils-cli` ships cross-platform.

## Rollback plan
- Keep changes as a sequence of small commits so reverting is easy.
- If CI is blocked by Homebrew issues on Ubuntu, temporarily pin CI to macOS while keeping PATH-based invocation, and add a follow-up to restore Ubuntu once brew installation is reliable.
