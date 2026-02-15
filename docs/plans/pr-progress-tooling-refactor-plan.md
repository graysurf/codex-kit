# Plan: PR progress tooling + shared templates refactor

## Overview

This plan refactors the PR progress workflow so shared templates do not live inside a single skill directory, and so reusable helper scripts become a dedicated “tooling” skill (mirroring `plan-tooling`). The goal is to reduce coupling, make reuse explicit, and keep canonical entrypoints stable via `$AGENTS_HOME/...` paths.

## Scope

- In scope:
  - `skills/workflows/pr/progress/` templates and helper scripts.
  - `docs/templates/PROGRESS_TEMPLATE.md` and `docs/templates/PROGRESS_GLOSSARY.md` symlink targets.
  - Update docs/skill references to point at canonical entrypoints.
- Out of scope:
  - Refactoring automation skills’ PR/report templates (keep per-skill templates as-is).
  - Consolidating feature PR templates across unrelated workflows (future work).

## Assumptions

1. This repo’s canonical shared location for a workflow family is `skills/workflows/<area>/<family>/_shared/{assets,references,lib,python}` (example: `skills/workflows/pr/progress/_shared/...`).
2. “Tooling skills” are appropriate when scripts are used across multiple skills or by non-interactive tooling.
3. It is acceptable for `docs/templates/*.md` to remain symlinks, as long as their targets are stable and owned by `_shared/`.

## Sprint 1: Extract progress shared templates

**Goal**: Move progress templates (progress file template, glossary, PR body, output format) into `skills/workflows/pr/progress/_shared/` and update all references to use the shared copies.

**Demo/Validation**:
- Command(s):
  - `$AGENTS_HOME/scripts/lint.sh --shell`
  - `$AGENTS_HOME/scripts/test.sh -k workflows_pr_progress_create_progress_pr`
- Verify:
  - `docs/templates/PROGRESS_TEMPLATE.md` and `docs/templates/PROGRESS_GLOSSARY.md` resolve to the new shared template files.

### Task 1.1: Move progress templates into `progress/_shared`
- **Location**:
  - `skills/workflows/pr/progress/_shared/assets/templates/PROGRESS_TEMPLATE.md`
  - `skills/workflows/pr/progress/_shared/references/PROGRESS_GLOSSARY.md`
  - `skills/workflows/pr/progress/_shared/references/PR_TEMPLATE.md`
  - `skills/workflows/pr/progress/_shared/references/ASSISTANT_RESPONSE_TEMPLATE.md`
  - `docs/templates/PROGRESS_TEMPLATE.md`
  - `docs/templates/PROGRESS_GLOSSARY.md`
  - `skills/workflows/pr/progress/create-progress-pr/assets/templates/PROGRESS_TEMPLATE.md`
  - `skills/workflows/pr/progress/create-progress-pr/references/PROGRESS_GLOSSARY.md`
  - `skills/workflows/pr/progress/create-progress-pr/references/PR_TEMPLATE.md`
  - `skills/workflows/pr/progress/create-progress-pr/references/ASSISTANT_RESPONSE_TEMPLATE.md`
- **Description**: Relocate progress workflow templates from `create-progress-pr/` into `skills/workflows/pr/progress/_shared/`. Update `docs/templates/PROGRESS_TEMPLATE.md` and `docs/templates/PROGRESS_GLOSSARY.md` symlinks so they target the new shared paths. Keep the content identical after the move.
- **Dependencies**: none
- **Complexity**: 6
- **Acceptance criteria**:
  - The shared templates exist under `skills/workflows/pr/progress/_shared/` and contain the same content as before the move.
  - `docs/templates/PROGRESS_TEMPLATE.md` resolves to `skills/workflows/pr/progress/_shared/assets/templates/PROGRESS_TEMPLATE.md`.
  - `docs/templates/PROGRESS_GLOSSARY.md` resolves to `skills/workflows/pr/progress/_shared/references/PROGRESS_GLOSSARY.md`.
- **Validation**:
  - `$AGENTS_HOME/scripts/lint.sh --shell`
  - `test -f skills/workflows/pr/progress/_shared/assets/templates/PROGRESS_TEMPLATE.md`
  - `test -f skills/workflows/pr/progress/_shared/references/PROGRESS_GLOSSARY.md`
  - `readlink docs/templates/PROGRESS_TEMPLATE.md`
  - `readlink docs/templates/PROGRESS_GLOSSARY.md`
  - `test -L docs/templates/PROGRESS_TEMPLATE.md`
  - `test -L docs/templates/PROGRESS_GLOSSARY.md`

### Task 1.2: Update progress skill references to use shared templates
- **Location**:
  - `skills/workflows/pr/progress/create-progress-pr/SKILL.md`
  - `skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh`
  - `skills/workflows/pr/progress/create-progress-pr/scripts/render_progress_pr.sh`
  - `skills/workflows/pr/progress/create-progress-pr/assets/templates/PROGRESS_TEMPLATE.md`
  - `skills/workflows/pr/progress/create-progress-pr/references/PROGRESS_GLOSSARY.md`
  - `skills/workflows/pr/progress/create-progress-pr/references/PR_TEMPLATE.md`
  - `skills/workflows/pr/progress/create-progress-pr/references/ASSISTANT_RESPONSE_TEMPLATE.md`
- **Description**: Update `create-progress-pr` docs and helper scripts so default (non-project) template reads come from `skills/workflows/pr/progress/_shared/...` rather than local copies. Remove the old local template files (or replace them with non-authoritative shims) and ensure no in-scope code/docs still references the old paths.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 6
- **Acceptance criteria**:
  - `create_progress_file.sh` and `render_progress_pr.sh` read templates from `progress/_shared/` when using default (non-project) templates.
  - `create-progress-pr/SKILL.md` lists the shared template locations as the default.
  - Repo scan shows no references to `create-progress-pr/(assets|references)/` template paths under `skills/` and documentation files, excluding `docs/progress/archived/` and `docs/plans/`.
- **Validation**:
  - `$AGENTS_HOME/scripts/lint.sh --shell`
  - `$AGENTS_HOME/scripts/test.sh -k workflows_pr_progress_create_progress_pr`
  - `rg -n \"create-progress-pr/(assets|references)/\" skills docs -S --glob '!docs/progress/archived/**' --glob '!docs/plans/**'`

## Sprint 2: Introduce `progress-tooling` skill

**Goal**: Extract reusable helper scripts out of `create-progress-pr` into a dedicated tooling skill with stable entrypoints, and update all call sites.

**Demo/Validation**:
- Command(s):
  - `$AGENTS_HOME/scripts/lint.sh --shell`
  - `$AGENTS_HOME/scripts/test.sh -k workflows_pr_progress`
- Verify:
  - All progress workflow scripts reference the new tooling entrypoints under `progress-tooling/scripts/`.

### Task 2.1: Create `progress-tooling` and move helper scripts
- **Location**:
  - `skills/workflows/pr/progress/progress-tooling/SKILL.md`
  - `skills/workflows/pr/progress/progress-tooling/scripts/create_progress_file.sh`
  - `skills/workflows/pr/progress/progress-tooling/scripts/render_progress_pr.sh`
  - `skills/workflows/pr/progress/progress-tooling/scripts/validate_progress_index.sh`
  - `skills/workflows/pr/progress/progress-tooling/tests/test_workflows_pr_progress_progress_tooling.py`
  - `skills/workflows/pr/progress/create-progress-pr/SKILL.md`
  - `skills/workflows/pr/progress/create-progress-pr/tests/test_workflows_pr_progress_create_progress_pr.py`
  - `skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh`
  - `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
- **Description**: Add a new `progress-tooling` skill that owns the progress helper scripts (scaffold, render, validate). Move the scripts from `create-progress-pr/scripts/` into `progress-tooling/scripts/` and update all references (including E2E and addendum scripts) to use the new canonical `$AGENTS_HOME/.../progress-tooling/scripts/...` paths. Update tests so entrypoint assertions match the new layout, and register the new tooling entrypoints in `docs/runbooks/skills/TOOLING_INDEX_V2.md`.
- **Dependencies**:
  - Task 1.2
- **Complexity**: 7
- **Acceptance criteria**:
  - `progress-tooling` has a valid `SKILL.md` contract and tests verifying its scripts exist.
  - `create-progress-pr` no longer owns shared helper scripts; its documentation points to `progress-tooling` entrypoints.
  - `progress_addendum.sh` and the progress E2E driver reference the new tooling script paths.
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md` includes the new progress tooling entrypoints.
- **Validation**:
  - `$AGENTS_HOME/scripts/lint.sh --shell`
  - `$AGENTS_HOME/scripts/test.sh -k workflows_pr_progress`
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/workflows/pr/progress/progress-tooling/SKILL.md`
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/workflows/pr/progress/create-progress-pr/SKILL.md`
  - `rg -n \"create-progress-pr/scripts/(create_progress_file|render_progress_pr|validate_progress_index)\\.sh\" skills docs -S --glob '!docs/progress/archived/**' --glob '!docs/plans/**'`

## Future work (not in this plan)

- Consider a `skills/workflows/pr/_shared/` layer if multiple PR workflow families start sharing identical PR body templates and output formats.
- Inventory automation skills’ PR/report templates and only consolidate when there is clear duplication and shared maintenance cost.
