# Plan: Skills structure normalization (v2) + script migrations

## Overview

This plan formalizes a v2 directory anatomy for `skills/` (including shared code/docs and per-skill tests), then standardizes on canonical skill entrypoints under `skills/**/scripts/` and removes legacy entrypoints. It also updates docs, audits, and pytest coverage so “adding a new skill” is governed by enforceable rules rather than convention.

Primary success criteria: new and existing skills follow a single, auditable structure; plan tooling + E2E drivers live under `skills/`; and every tracked skill has tests.

## Scope

- In scope:
  - Tracked skills under `skills/workflows/`, `skills/tools/`, and `skills/automation/`.
  - Introduce shared directories:
    - Category shared: `skills/<category>/<area>/_shared/`
    - Global shared: `skills/_shared/`
  - Ensure plan tooling entrypoints live under `skills/workflows/plan/plan-tooling/scripts/`.
  - Ensure real-GitHub E2E drivers live under dedicated skills (e.g., `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/`).
  - Remove legacy entrypoints and update all runnable instructions to canonical `$CODEX_HOME/...` paths.
  - Add per-skill `tests/` for **all tracked skills** and enforce via audit + CI.
  - Update docs/tests to prefer `$CODEX_HOME/...` absolute paths for executable entrypoints.
- Out of scope:
  - Rewriting skill behavior beyond path/reference updates (no functional redesign unless required for safety).
  - Refactoring `.worktrees/` contents (local worktrees are treated as disposable).
  - Enforcing layout for ignored local skills under `skills/_projects/` and generated skills under `skills/.system/` (documented, best-effort only).

## Assumptions

1. Breaking change policy: canonical skill entrypoints only (no legacy script entrypoints).
2. Shared code policy: prefer category-level `_shared/` first; use `skills/_shared/` only for truly cross-category reuse.
3. Test policy: every tracked skill must have tests (minimal smoke tests are acceptable for doc-only skills).
4. Documentation policy: in `SKILL.md`, executable paths use `$CODEX_HOME/...` (repo-relative links are allowed for non-executables).

## Current inventory (2026-01-24 snapshot)

Tracked skills (git): 23  
Local-only skills (ignored by git): `skills/_projects/**` (project DB helpers) and `skills/.system/**` (generated system skills).

Canonical skill entrypoints (v2):

- Plan tooling:
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh`
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh`
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh`
- E2E driver:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
- Skill governance:
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh`
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`

## Sprint 1: Define v2 skill anatomy + shared layout

**Goal**: publish an enforceable v2 structure (including `_shared/` and per-skill tests), with a concrete migration map for existing skills and repo scripts.

**Demo/Validation**:
- Command(s):
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh --file docs/plans/skills-structure-reorg-plan.md`
- Verify:
  - Plan lints cleanly and contains a complete tooling index.

### Task 1.1: Write the v2 skills anatomy specification

- **Complexity**: 6
- **Location**:
  - `docs/skills/SKILLS_ANATOMY_V2.md`
- **Description**: Define the v2 directory rules for skills, shared code, and per-skill tests.
  - Specify allowed top-level entries inside a skill directory:
    - `SKILL.md` (required)
    - `scripts/` (entrypoints only; executable)
    - `lib/` (non-entrypoint code; not executable)
    - `tests/` (required for tracked skills)
    - `references/` (docs/guides)
    - `assets/` (scaffolds/templates)
  - Define shared directories (not “skills”):
    - `skills/_shared/` and `skills/**/_shared/` with allowed subtrees like `lib/`, `references/`, `assets/`, `python/`
    - Explicitly forbid `_shared/scripts/` (avoid treating libs as entrypoints).
  - Define path rules for `SKILL.md` (executables use `$CODEX_HOME/...`).
  - Define naming conventions for skills and shared folders (kebab-case; `_shared` reserved).
- **Dependencies**: none
- **Acceptance criteria**:
  - Doc clearly distinguishes skill entrypoints vs shared non-entrypoint code.
  - Doc includes at least one “golden path” example for a new skill and for shared code reuse.
- **Validation**:
  - `test -f docs/skills/SKILLS_ANATOMY_V2.md`

### Task 1.2: Add a tooling index (canonical entrypoints)

- **Complexity**: 5
- **Location**:
  - `docs/skills/TOOLING_INDEX_V2.md`
- **Description**: Document canonical executable entrypoints under `skills/**/scripts/` (single source of truth).
  - Include at least:
    - skill governance entrypoints
    - plan tooling entrypoints
    - real-GitHub E2E driver entrypoints
- **Dependencies**: Task 1.1
- **Acceptance criteria**:
  - Index includes plan tooling scripts and the progress workflow E2E driver.
  - Index only lists canonical `$CODEX_HOME/...` executable paths.
- **Validation**:
  - `test -f docs/skills/TOOLING_INDEX_V2.md`

### Task 1.3: Create shared directory skeletons (category + global)

- **Complexity**: 4
- **Location**:
  - `skills/_shared/README.md`
  - `skills/workflows/plan/_shared/README.md`
  - `skills/workflows/pr/progress/_shared/README.md`
- **Description**: Add `_shared/` directories with README contracts for allowed contents and intended reuse patterns.
- **Dependencies**: Task 1.1
- **Acceptance criteria**:
  - Each `_shared/README.md` documents what can live there and what is forbidden.
  - `_shared/` directories contain no `scripts/` subdirectory.
- **Validation**:
  - `test -f skills/_shared/README.md`

## Sprint 2: Skill governance v2 (audits + path rules)

**Goal**: enforce v2 anatomy mechanically (including required `tests/`) and validate runnable path rules in `SKILL.md`.

**Demo/Validation**:
- Command(s):
  - `scripts/check.sh --contracts --skills-layout --tests -- -m script_smoke`
- Verify:
  - Layout audit and contract checks pass.
  - No regressions in existing smoke tests.

### Task 2.1: Introduce a tracked governance skill for audits

- **Complexity**: 7
- **Location**:
  - `skills/tools/devex/skill-governance/SKILL.md`
  - `skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`
  - `skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh`
- **Description**: Move skill-governance scripts into a dedicated skill folder with `$CODEX_HOME/...` canonical paths.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
- **Acceptance criteria**:
  - Canonical scripts live under `skills/tools/devex/skill-governance/scripts/`.
- **Validation**:
  - `bash -n skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`
  - `bash -n skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh`

### Task 2.2: Update the layout audit to v2 (tests + lib allowed)

- **Complexity**: 6
- **Location**:
  - `skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`
- **Description**: Extend the skill layout audit to allow v2 top-level entries and require `tests/` for tracked skills.
- **Dependencies**: Task 2.1
- **Acceptance criteria**:
  - Audit allows `tests/` and `lib/` inside a tracked skill folder.
  - Audit fails if a tracked skill has no `tests/` directory (or no tests inside it).
- **Validation**:
  - `scripts/check.sh --skills-layout`

### Task 2.3: Add a validator for SKILL.md executable path rules

- **Complexity**: 5
- **Location**:
  - `skills/tools/devex/skill-governance/scripts/validate_skill_paths.sh`
  - `tests/test_audit_scripts.py`
- **Description**: Add a repo check that enforces `$CODEX_HOME/...` absolute paths for executable entrypoints referenced in `SKILL.md`.
- **Dependencies**: Task 2.1
- **Acceptance criteria**:
  - Validator detects common footguns (e.g., `scripts/...` in runnable instructions inside `SKILL.md`).
  - Validator is wired into `scripts/check.sh --all`.
- **Validation**:
  - `scripts/check.sh --lint --contracts --skills-layout`

### Task 2.4: Update top-level docs to reflect v2 governance entrypoints

- **Complexity**: 4
- **Location**:
  - `README.md`
  - `DEVELOPMENT.md`
- **Description**: Update docs to reflect new canonical governance paths.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
- **Acceptance criteria**:
  - Docs reference `$CODEX_HOME/skills/tools/devex/skill-governance/...` as canonical.
- **Validation**:
  - `rg -n \"skill-governance\" README.md DEVELOPMENT.md`

### Task 2.5: Sweep and fix executable path references (SKILLs + docs)

- **Complexity**: 6
- **Location**:
  - `skills/workflows/plan/create-plan/SKILL.md`
  - `docs/workflows/progress-pr-workflow.md`
- **Description**: Do a repo-wide scan for runnable instructions and rewrite them to canonical `$CODEX_HOME/...` paths.
- **Dependencies**:
  - Task 2.3
  - Task 2.4
- **Acceptance criteria**:
  - Tracked `SKILL.md` files contain no runnable instructions that depend on the current working directory.
- **Validation**:
  - `rg -n \"scripts/(validate_plans|plan_to_json|plan_batches|audit-skill-layout|validate_skill_contracts)\\.sh|scripts/e2e/progress_pr_workflow\\.sh\" -S skills docs tests`

## Sprint 3: Plan tooling migration into `skills/workflows/plan`

**Goal**: standardize plan tooling under `skills/workflows/plan/plan-tooling/scripts/` and update planning skills/docs accordingly.

**Demo/Validation**:
- Command(s):
  - `scripts/test.sh -m script_smoke -k plan`
- Verify:
  - Plan tooling scripts work via the canonical entrypoints.

### Task 3.1: Create a plan-tooling skill and move the scripts

- **Complexity**: 7
- **Location**:
  - `skills/workflows/plan/plan-tooling/SKILL.md`
  - `skills/workflows/plan/plan-tooling/scripts/validate_plans.sh`
  - `skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh`
  - `skills/workflows/plan/plan-tooling/scripts/plan_batches.sh`
- **Description**: Make plan tooling canonical under `skills/workflows/plan/plan-tooling/scripts/`.
- **Dependencies**:
  - Task 1.2
  - Task 2.1
- **Acceptance criteria**:
  - Canonical scripts run from any CWD when `CODEX_HOME` is set.
- **Validation**:
  - `scripts/test.sh -m script_smoke -k plan_to_json`

### Task 3.2: Update planning skills to use canonical `$CODEX_HOME/...` tooling

- **Complexity**: 4
- **Location**:
  - `skills/workflows/plan/create-plan/SKILL.md`
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
  - `skills/workflows/plan/execute-plan-parallel/SKILL.md`
- **Description**: Replace runnable instructions that reference `scripts/...` with canonical `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/...`.
- **Dependencies**: Task 3.1
- **Acceptance criteria**:
  - SKILL.md runnable commands use `$CODEX_HOME/...` absolute paths for executables.
  - The docs still describe the same workflow; only paths change.
- **Validation**:
  - `scripts/check.sh --contracts`

### Task 3.3: Add per-skill tests for the new plan-tooling skill

- **Complexity**: 6
- **Location**:
  - `skills/workflows/plan/plan-tooling/tests/test_plan_tooling_smoke.py`
  - `tests/fixtures/plan/valid-plan.md`
- **Description**: Add tests under the skill to validate canonical paths, outputs, and failure modes.
- **Dependencies**: Task 3.1
- **Acceptance criteria**:
  - `pytest` discovers and runs the skill-local tests.
  - Tests cover `--help`, valid fixture parse, and invalid fixture failure.
- **Validation**:
  - `scripts/test.sh -k plan_tooling_smoke`

## Sprint 4: E2E drivers under skills (progress workflow)

**Goal**: move real-GitHub E2E scripts under `skills/` and document their usage.

**Demo/Validation**:
- Command(s):
  - `scripts/test.sh -m script_regression -k progress_pr_workflow`
- Verify:
  - The E2E driver is callable via the canonical skill entrypoint.

### Task 4.1: Create an E2E skill for the progress PR workflow driver

- **Complexity**: 6
- **Location**:
  - `skills/workflows/pr/progress/progress-pr-workflow-e2e/SKILL.md`
  - `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
- **Description**: Move the canonical E2E driver into a dedicated skill.
- **Dependencies**:
  - Task 1.2
  - Task 2.1
- **Acceptance criteria**:
  - Script keeps existing safety gates (never runs in CI by default).
- **Validation**:
  - `scripts/test.sh -m script_regression -k progress_pr_workflow`

### Task 4.2: Add per-skill tests for the E2E skill (static + stubbed)

- **Complexity**: 5
- **Location**:
  - `skills/workflows/pr/progress/progress-pr-workflow-e2e/tests/test_progress_pr_workflow_driver.py`
  - `tests/test_sprint4_regressions.py`
- **Description**: Add a skill-local test that verifies argument parsing and that `gh pr create` usage includes `--head` (via existing stubs).
- **Dependencies**: Task 4.1
- **Acceptance criteria**:
  - Tests pass without requiring real GitHub access.
  - The existing regression test continues to protect the canonical driver path.
- **Validation**:
  - `scripts/test.sh -k progress_pr_workflow_driver`

## Sprint 5: Per-skill tests for all tracked skills + enforcement

**Goal**: add required `tests/` to every tracked skill and enforce “no skill without tests”.

**Demo/Validation**:
- Command(s):
  - `scripts/check.sh --all`
- Verify:
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh` enforces tests and passes.
  - Skill-local tests run in CI and locally.

### Task 5.1: Add a shared pytest helper for skill-local tests

- **Complexity**: 6
- **Location**:
  - `skills/_shared/python/skill_testing/__init__.py`
  - `skills/_shared/python/skill_testing/assertions.py`
- **Description**: Provide reusable test helpers (contract lint, executable existence) for skill-local tests.
- **Dependencies**:
  - Task 2.3
- **Acceptance criteria**:
  - Helper functions can be imported by tests under `skills/**/tests/` without custom sys.path hacks.
  - Helpers keep tests minimal (each skill test file is small and declarative).
- **Validation**:
  - `python3 -c \"import skills._shared.python.skill_testing.assertions\"`

### Task 5.2: Make `skills/` importable for skill-local tests

- **Complexity**: 5
- **Location**:
  - `skills/__init__.py`
  - `skills/_shared/__init__.py`
  - `skills/_shared/python/__init__.py`
- **Description**: Ensure a stable Python import strategy for `skills/**/tests/` (so tests can import `skills._shared.python.*`).
- **Dependencies**: Task 1.3
- **Acceptance criteria**:
  - `python3 -c \"import skills\"` succeeds when executed from the repo root.
  - Skill-local tests can import shared helpers via `skills._shared.python...`.
- **Validation**:
  - `python3 -c \"import skills._shared\"`

### Task 5.3: Add `tests/` to workflow skills (docs-only and script-based)

- **Complexity**: 8
- **Location**:
  - `skills/workflows/conversation/ask-questions-if-underspecified/tests/test_skill.py`
  - `skills/workflows/plan/create-plan/tests/test_skill.py`
  - `skills/workflows/pr/feature/create-feature-pr/tests/test_skill.py`
  - `skills/workflows/pr/progress/create-progress-pr/tests/test_skill.py`
- **Description**: Add skill-local tests for all workflow skills, using the shared helper to validate contracts and key entrypoints.
- **Dependencies**:
  - Task 5.1
  - Task 5.2
- **Acceptance criteria**:
  - Every workflow skill folder contains `tests/` with at least one passing test.
  - Tests for doc-only skills validate SKILL.md contract + path rules.
- **Validation**:
  - `scripts/test.sh skills/workflows/plan/create-plan/tests/test_skill.py`

### Task 5.4: Add `tests/` to tools skills

- **Complexity**: 7
- **Location**:
  - `skills/tools/browser/chrome-devtools-site-search/tests/test_skill.py`
  - `skills/tools/devex/semantic-commit/tests/test_skill.py`
  - `skills/tools/testing/rest-api-testing/tests/test_skill.py`
- **Description**: Add skill-local tests for tools skills, focusing on script entrypoints, `--help` behavior, and deterministic outputs.
- **Dependencies**:
  - Task 5.1
  - Task 5.2
- **Acceptance criteria**:
  - Every tools skill folder contains `tests/` with at least one passing test.
  - Tool scripts referenced in SKILL.md exist and are executable.
- **Validation**:
  - `scripts/test.sh skills/tools/devex/semantic-commit/tests/test_skill.py`

### Task 5.5: Add `tests/` to automation skills

- **Complexity**: 6
- **Location**:
  - `skills/automation/find-and-fix-bugs/tests/test_skill.py`
  - `skills/automation/semgrep-find-and-fix/tests/test_skill.py`
  - `skills/automation/release-workflow/tests/test_skill.py`
- **Description**: Add skill-local tests for automation skills, focusing on contract + “dry-run” safety and script presence.
- **Dependencies**:
  - Task 5.1
  - Task 5.2
- **Acceptance criteria**:
  - Every automation skill folder contains `tests/` with at least one passing test.
  - Automation tests never require real external services by default.
- **Validation**:
  - `scripts/test.sh skills/automation/release-workflow/tests/test_skill.py`

### Task 5.6: Backfill tests for any remaining tracked skills

- **Complexity**: 7
- **Location**:
  - `skills/tools/devex/desktop-notify/tests/test_skill.py`
  - `skills/workflows/pr/feature/close-feature-pr/tests/test_skill.py`
- **Description**: Use the v2 layout audit output to identify any tracked skills missing `tests/`, then add the missing test folders/files.
- **Dependencies**:
  - Task 2.2
  - Task 5.3
  - Task 5.4
  - Task 5.5
- **Acceptance criteria**:
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh` reports no tracked skills missing tests.
  - The added tests are minimal and use the shared helper (no duplicated harness logic).
- **Validation**:
  - `scripts/check.sh --skills-layout`

### Task 5.7: Wire enforcement into repo checks + CI

- **Complexity**: 5
- **Location**:
  - `scripts/check.sh`
  - `.github/workflows/lint.yml`
- **Description**: Ensure v2 audits and skill-local tests are run in CI and in `scripts/check.sh --all`.
- **Dependencies**:
  - Task 2.2
  - Task 2.3
  - Task 5.3
  - Task 5.4
  - Task 5.5
  - Task 5.6
- **Acceptance criteria**:
  - CI fails when a tracked skill is added without `tests/`.
  - `scripts/check.sh --all` runs the new governance validators.
- **Validation**:
  - `scripts/check.sh --all`

## Testing Strategy

- Unit (Python): skill-local tests under `skills/**/tests/` using a shared helper under `skills/_shared/python/`.
- Integration (scripts): keep existing script regression/smoke harness in `tests/` and add canonical-path coverage for key entrypoints.
- E2E (real GitHub): keep E2E drivers guarded (`CI=true` refusal + explicit opt-in env var) and write artifacts under `out/e2e/`.

## Risks & gotchas

- Tooling discovery: repo tests treat any `skills/**/scripts/**` as runnable entrypoints, so shared code must not live under a `scripts/` directory.
- Python import paths: adding `skills/_shared/python/` requires a stable import strategy (documented and tested).
- Local-only skills: ignored folders (`skills/_projects/`, `skills/.system/`) cannot be enforced via git-based audits; document best-effort guidance.

## Rollback plan

- Revert the entrypoint standardization changes (restore the previous file layout and runnable instructions).
- Disable v2 enforcement in CI and `scripts/check.sh` (restore the previous audit behavior and remove new validators from `--all`).
- Remove or quarantine newly-added `skills/**/tests/` if the per-skill testing model proves too heavy for CI time budgets.
- Keep the v2 docs as informational until the migration is retried.
