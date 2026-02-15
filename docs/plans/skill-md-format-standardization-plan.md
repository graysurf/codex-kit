# Plan: SKILL.md format standardization

## Overview

This plan standardizes the structure of every `skills/**/SKILL.md` so that:

- `## Contract` is consistently placed at the top (right after a short title/preamble).
- `## Contract` stays the canonical, machine-validated interface (Prereqs/Inputs/Outputs/Exit codes/Failure modes).
- Optional sections like `## Setup` are de-duplicated and have clear semantics (how to satisfy prereqs, not re-stating them).
- Outlier skills (notably `image-processing`) are refactored to move “how to use” content under post-Contract headings.

The outcome is a documented SKILL.md design plus governance checks that prevent regressions.

## Scope

- In scope:
  - All tracked `skills/**/SKILL.md` files (including `skills/_projects/` and `skills/.system/`).
  - Skill governance tooling that validates SKILL.md (`skills/tools/skill-management/skill-governance/`).
  - Skill scaffolding defaults (`skills/tools/skill-management/create-skill/`).
  - A single, canonical style guide under `docs/runbooks/skills/`.
- Out of scope:
  - Changing runtime behavior of skill scripts (formatting-only effort).
  - Large editorial rewrites of skill content beyond what is needed for structure/duplication fixes.

## Assumptions

1. `SKILL.md` ordering: YAML front matter → `# Title` → up to 2 non-empty preamble lines → `## Contract` as the first H2.
2. `## Contract` remains the only required section; everything else is optional but must not weaken the contract.
3. `## Setup` is optional; when present it focuses on “how to satisfy/verify prereqs” and avoids duplicating the Prereqs list verbatim.
4. Common section names should be consistent where they are semantically the same:
   - `## Contract` (required)
   - `## Setup` (optional)
   - `## Scripts (only entrypoints)` (required when the skill has scripts)
   - `## Workflow` (recommended for operational skills)
   - `## References` (optional)
5. Non-common content may use additional H2s, but it should live after `## Contract` (no long free-floating content before the contract).

## Sprint 1: Define the format and templates

**Goal**: write a clear SKILL.md format spec, add a reusable SKILL.md template, and produce an audit report to guide migration.

**Demo/Validation**:
- Command(s):
  - `python3 scripts/skills/audit_skill_md_format.py --format summary`
- Verify:
  - Output lists current violations and is stable enough to use in PR review.

### Task 1.1: Write the SKILL.md format spec (v1)
- **Location**:
  - `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
- **Description**: Add a concise, normative style guide that defines required ordering (including the “preamble then Contract” rule), the intended semantics of `Contract` vs `Setup`, which information should live only in `Contract`, and recommended section names with examples (including how to structure “assistant policy” content after the contract). Define what counts as preamble for validation purposes (blank lines, list items, blockquotes, code fences, and any headings other than the first H1). Link the relevant validator entrypoints from `docs/runbooks/skills/TOOLING_INDEX_V2.md`.
- **Dependencies**: none
- **Complexity**: 4
- **Acceptance criteria**:
  - The doc defines the maximum preamble rule and what counts as “preamble”.
  - The doc defines what is Contract-only (Prereqs/Inputs/Outputs/Exit codes/Failure modes) vs what belongs in Setup/Workflow.
  - The doc defines how to handle duplication (allowed minimal reminders vs forbidden verbatim repeats), and explicitly forbids `## Setup` from introducing new hard prerequisites that are missing from `## Contract`.
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md` references the new format doc.
- **Validation**:
  - `test -f docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`
  - `rg -n \"^## Contract$\" docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`

### Task 1.2: Add a canonical SKILL.md template and wire create-skill to it
- **Location**:
  - `skills/tools/skill-management/create-skill/assets/templates/SKILL_TEMPLATE.md`
  - `skills/tools/skill-management/create-skill/scripts/create_skill.sh`
- **Description**: Add a single source-of-truth SKILL.md template that matches the new format (preamble + Contract first, then standard optional sections). Update `create_skill.sh` to render the template (name/description/title) instead of embedding the SKILL.md stub inline, so new skills start compliant by default.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 6
- **Acceptance criteria**:
  - `create_skill.sh` generates a SKILL.md whose first H2 is `## Contract` and whose contract headings pass existing validation.
  - The template includes stubs for `## Scripts (only entrypoints)` and `## Workflow` (when applicable) without introducing placeholder tokens in required Contract headings.
  - The template location is stable and documented in the format spec.
- **Validation**:
  - `bash $AGENTS_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh --help`
  - `rm -rf skills/_tmp/skill-md-format-smoke || true`
  - `bash $AGENTS_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh --skill-dir skills/_tmp/skill-md-format-smoke --title \"Skill Md Format Smoke\" --description \"smoke\"`
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/_tmp/skill-md-format-smoke/SKILL.md`
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/_tmp/skill-md-format-smoke`
  - `rm -rf skills/_tmp/skill-md-format-smoke`

### Task 1.3: Add an audit script for SKILL.md structure
- **Location**:
  - `scripts/skills/audit_skill_md_format.py`
- **Description**: Add a lightweight repo tool that scans all `skills/**/SKILL.md` and reports structural issues relevant to this standardization: preamble length, whether `## Contract` is the first H2, presence of `## Setup`, and a list of files that need migration. The script should support a human summary output for use in reviews and a JSON output for tooling/CI use. Create the `scripts/skills/` directory if needed.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Running the script produces a deterministic summary (sorted output).
  - The summary explicitly flags `skills/tools/media/image-processing/SKILL.md` as needing changes under the new rule.
  - The JSON output includes the violation type(s) and per-file counts (stable ordering).
  - The script exits non-zero when violations exist (so it can be used in CI later if desired).
- **Validation**:
  - `python3 scripts/skills/audit_skill_md_format.py --format summary`
  - `python3 scripts/skills/audit_skill_md_format.py --format json | python3 -m json.tool >/dev/null`

## Sprint 2: Enforce the format in skill-governance

**Goal**: extend the existing validator so the new structure is enforced and add tests to prevent regressions.

**Demo/Validation**:
- Command(s):
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
  - `pytest -q`
- Verify:
  - Validator fails on known-bad fixtures and passes on the repo’s SKILL.md set after migration.

### Task 2.1: Enforce Contract placement in validate_skill_contracts.sh
- **Location**:
  - `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- **Description**: Extend the validator to enforce the new file-level rule: after the first H1 title, allow at most 2 non-empty preamble lines, forbid any markdown headings other than that H1, and require `## Contract` to be the first H2 in the file. Keep the existing “required headings in Contract in order” checks unchanged. Error messages must include the violating file path and a single-sentence fix suggestion.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 7
- **Acceptance criteria**:
  - The validator exits non-zero when `## Contract` is preceded by more than 2 non-empty lines.
  - The validator exits non-zero when any other markdown heading appears before `## Contract`.
  - The validator preserves current behavior for Contract inner headings and ordering.
  - Error output is actionable for mass-fixing (grouped by file, stable ordering).
- **Validation**:
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/media/image-processing/SKILL.md`
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/devex/semantic-commit/SKILL.md`

### Task 2.2: Add regression tests for the new Contract placement rule
- **Location**:
  - `skills/tools/skill-management/skill-governance/tests/test_tools_skill_management_skill_governance.py`
  - `skills/tools/skill-management/skill-governance/tests/fixtures/skill_md_contract_not_first.md`
  - `skills/tools/skill-management/skill-governance/tests/fixtures/skill_md_preamble_too_long.md`
- **Description**: Add pytest coverage that runs `validate_skill_contracts.sh --file ...` against fixture SKILL.md files and asserts expected exit codes and error messages. Include at least one fixture for “another heading before Contract” and one fixture for “preamble too long”. Prefer asserting that stderr contains key substrings rather than matching the entire error text.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 6
- **Acceptance criteria**:
  - Tests fail on the old validator and pass after the validator is updated.
  - Fixtures are minimal and only cover structure (not content correctness beyond the Contract headings).
  - The test suite remains hermetic (no dependency on external network or user config).
- **Validation**:
  - `pytest -q skills/tools/skill-management/skill-governance/tests/test_tools_skill_management_skill_governance.py`

### Task 2.3: Add create-skill integration coverage for generated SKILL.md structure
- **Location**:
  - `skills/tools/skill-management/create-skill/tests/test_tools_skill_management_create_skill.py`
- **Description**: Add a test that runs `create_skill.sh` in a temporary directory under the repo (creating and then removing a throwaway skill directory), and asserts the generated SKILL.md passes `validate_skill_contracts.sh` including the new Contract placement rule. This prevents the scaffolder from drifting from the enforced format.
- **Dependencies**:
  - Task 1.2
  - Task 2.1
- **Complexity**: 7
- **Acceptance criteria**:
  - The test cleans up the created skill directory even when assertions fail.
  - The generated SKILL.md passes the updated validator.
  - The test does not require git staging/committing.
- **Validation**:
  - `pytest -q skills/tools/skill-management/create-skill/tests/test_tools_skill_management_create_skill.py`

## Sprint 3: Migrate outlier SKILL.md files

**Goal**: bring the repo’s SKILL.md set into compliance with the new validator with minimal content changes.

**Demo/Validation**:
- Command(s):
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Verify:
  - All tracked SKILL.md pass (no exceptions).

### Task 3.1: Refactor image-processing SKILL.md to move policy content after the Contract
- **Location**:
  - `skills/tools/media/image-processing/SKILL.md`
- **Description**: Move the current pre-Contract “preferences/policy/completion response” content to post-Contract sections using consistent H2 headings (for example `## Guidance` and `## Policies`). Keep at most a 1–2 line preamble between `# Image Processing` and `## Contract`. Preserve all existing behavioral requirements; this is a structure-only refactor.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 5
- **Acceptance criteria**:
  - `skills/tools/media/image-processing/SKILL.md` passes the updated validator.
  - No policy requirements are lost; they are only reorganized under headings.
  - The `## Contract` block remains intact and unchanged (no semantic edits; only whitespace if needed for formatting).
- **Validation**:
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/media/image-processing/SKILL.md`

### Task 3.2: Refactor worktree-stacked-feature-pr SKILL.md to use a short preamble
- **Location**:
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/SKILL.md`
- **Description**: Reduce the pre-Contract introduction to at most two non-empty lines. Move the extended explanation and bullet lists into a post-Contract section (for example `## Overview`) without changing meaning. This keeps the file compliant while preserving the helpful context.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 4
- **Acceptance criteria**:
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/SKILL.md` passes the updated validator.
  - The longer explanation remains available, just relocated under an H2.
- **Validation**:
  - `bash $AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/workflows/pr/progress/worktree-stacked-feature-pr/SKILL.md`

## Testing Strategy

- Unit:
  - Add fixture-based tests for `validate_skill_contracts.sh`.
  - Add an integration test for `create_skill.sh` output.
- Integration:
  - Run `validate_skill_contracts.sh` and `audit-skill-layout.sh` over the whole repo.
- Manual review:
  - Spot-check migrated SKILL.md files for readability (no content loss, headings still make sense).

## Risks & gotchas

- Overly strict preamble rules can create unnecessary churn; keep the allowance small but practical (2 non-empty lines).
- Some “project wrapper” skills under `skills/_projects/` may have more narrative; if they become noisy to migrate, adjust the spec and explicitly document exceptions rather than silently skipping them.
- Validators should report stable, actionable errors to avoid frustrating bulk fixes.
- Without clear rules, `## Setup` can drift into being “the real prereqs”; the spec should forbid Setup from adding hard requirements not listed in `## Contract`.

## Rollback plan

- Revert the validator tightening in `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`.
- Keep the format spec doc, but mark the stricter rules as deferred.
- If migrations caused confusion, revert individual SKILL.md reorganizations (format-only changes are low-risk and easy to revert).
