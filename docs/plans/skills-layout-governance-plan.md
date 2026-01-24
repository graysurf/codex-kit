# Plan: Skills layout governance (v2)

## Overview

This plan defines a consistent, enforceable directory structure for `skills/` and each skill folder, with explicit conventions for (a) shared files across related skills, (b) where scripts should live, and (c) how SKILL.md should reference files safely from any working directory. It also adds automated audits + tests so new skills must follow the rules, then migrates existing skills to comply (including fixing currently broken `$CODEX_HOME/...` paths in `_projects` skills).

## Scope

- In scope:
  - Define “Skill Anatomy v2” (folder layout + naming + allowed shared patterns).
  - Add mechanical enforcement (audits + CI hooks + regression tests).
  - Migrate existing skills that violate the new rules (start with `_projects/*` path bugs already present).
- Out of scope:
  - Changing the meaning/triggering logic of skills beyond path/reference correctness.
  - Rewriting historical docs except for required Addendums when a path migration breaks archived references.

## Assumptions

1. `CODEX_HOME` is set (CI + local tests already set it), so `$CODEX_HOME/...` is the stable “absolute” anchor.
2. Repo policy remains: any file under `skills/**/scripts/**` is treated as an executable entrypoint by script regression tests.
3. Shared “library” code should be non-executable (no shebang) and must not live under a `scripts/` directory to avoid accidental execution in tests.

## Feasibility evaluation (your proposed rules)

1) Shared `.md` / `.sh` / `.py` across related skills
- Feasible and already partially implemented (`skills/automation/_libs` + `_projects/*` group-level shared wrappers).
- Recommended rule: shared *executable* entrypoints go under a group-level `scripts/` (must be safe under `--help`); shared *non-executable* logic goes under a sibling `_libs/` tree (no `scripts/` dir inside `_libs/`).
- For shared `.md`, prefer `docs/templates/` (global) or group-level `_libs/md/` (local) depending on reuse scope.

2) “skills-related scripts should not be in repo `scripts/`”
- Partially feasible, but `scripts/` is currently the repo’s stable CLI/tooling surface (lint/test/plan tooling).
- Recommended rule: keep repo-wide tooling in `scripts/` (stable entrypoints), but move skill-family-specific implementations under that family’s `_libs/` and/or a dedicated “governance skill”, with `scripts/*` becoming thin wrappers over time (backwards compatible).

3) Single-skill directory structure / whether to add `tests/`
- Feasible, but adding `tests/` inside each skill requires updating layout audits and deciding how tests are discovered.
- Recommended rule (minimal disruption): keep skill folders as `SKILL.md` + optional `scripts/`, `references/`, `assets/`; store fixtures under `assets/testdata/` and keep executable tests centralized under repo `tests/` (pytest + script regression/specs).

4) Related skills (e.g. `skills/workflows/plan`) sharing structure
- Feasible via group-level `_libs/` + optional group-level docs, without turning shared folders into “skills”.
- Recommended rule: group-level shared folders MUST NOT contain `SKILL.md`; they are implementation/shared resources only.

5) SKILL.md file paths should use `$CODEX_HOME/...` (not relative)
- Feasible and improves reliability, but must be linted to avoid “correct-looking but wrong” paths (currently present: duplicated `$CODEX_HOME/...$CODEX_HOME/...` and non-existent wrapper paths).
- Recommended rule: command snippets must use `$CODEX_HOME/...`; markdown links may remain relative for GitHub readability; add an audit that verifies `$CODEX_HOME/...` paths exist and do not contain nested `$CODEX_HOME`.

## Sprint 1: Define Skill Anatomy v2 (spec + examples)
**Goal**: Publish an executable, repo-enforced spec for skill layout + sharing conventions + path rules.
**Demo/Validation**:
- Command(s): `rg -n "Skill Anatomy v2" docs/skills/SKILL_LAYOUT_V2.md`
- Verify: the spec includes directory diagrams, “MUST/SHOULD/MAY” language, and examples for each rule.

### Task 1.1: Write the canonical spec doc
- **Location**:
  - `docs/skills/SKILL_LAYOUT_V2.md`
- **Description**: Add a single canonical document that defines Skill Anatomy v2, including: (a) the per-skill directory layout, (b) group-level sharing via `_libs/`, (c) rules for executable entrypoints under `scripts/`, (d) rules for shared markdown/templates, and (e) SKILL.md path conventions (when to use `$CODEX_HOME`, when relative links are allowed).
- **Dependencies**: none
- **Complexity**: 6
- **Acceptance criteria**:
  - The document defines “MUST/SHOULD/MAY” rules for all five user concerns (sharing, scripts placement, tests, group sharing, absolute paths).
  - The document includes at least one concrete example tree for each of: a tool skill, a workflow skill, and a `_projects` wrapper skill.
  - The document contains no unfinished placeholder markers (for example: “to be filled later” notes or angle-bracket placeholders).
- **Validation**:
  - `rg -n "MUST|SHOULD|MAY" docs/skills/SKILL_LAYOUT_V2.md`
  - `rg -n "^## (Directory layout|Sharing \\(_libs_\\)|Scripts and entrypoints|Testing|Path rules|Examples)$" docs/skills/SKILL_LAYOUT_V2.md`

### Task 1.2: Wire the spec into repo docs and guidance
- **Location**:
  - `README.md`
  - `skills/.system/skill-creator/SKILL.md`
- **Description**: Add a short “Skill Anatomy v2” reference link in the repo README and update `skill-creator` to point to the canonical spec for repo-specific rules (especially the `$CODEX_HOME` path rules and `_libs` sharing rules).
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - `README.md` links to `docs/skills/SKILL_LAYOUT_V2.md` in the Skills section.
  - `skills/.system/skill-creator/SKILL.md` references the spec (repo-specific deltas) without duplicating the full content.
- **Validation**:
  - `rg -n \"docs/skills/SKILL_LAYOUT_V2\\.md\" README.md skills/.system/skill-creator/SKILL.md`

## Sprint 2: Add enforcement (audits + CI + regression tests)
**Goal**: Make the new rules enforceable so new skills cannot regress structure or path correctness.
**Demo/Validation**:
- Command(s): `scripts/check.sh --lint`
- Verify: new audits run in CI and fail on invalid SKILL.md path references.

### Task 2.1: Add a SKILL.md path audit script
- **Location**:
  - `scripts/audit-skill-paths.sh`
  - `scripts/README.md`
- **Description**: Implement a repo-level audit that scans tracked `skills/**/SKILL.md` and enforces: (a) no duplicated `$CODEX_HOME` segments, (b) every `$CODEX_HOME/`-anchored path referenced in inline code or code blocks exists in the repo, and (c) `_projects` wrapper skills reference the correct group-level wrapper location (for example: `skills/_projects/qburger/scripts/qb-mysql.zsh`) rather than non-existent per-skill paths.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 8
- **Acceptance criteria**:
  - `scripts/audit-skill-paths.sh --help` exits 0 and prints usage.
  - `scripts/audit-skill-paths.sh` supports `--file PATH` (repeatable) to validate specific SKILL.md files in isolation.
  - `scripts/audit-skill-paths.sh` exits non-zero when violations are found and prints `error:` lines with file + offending path.
  - On failure, the script prints `error:` lines identifying the SKILL.md and the offending path.
- **Validation**:
  - `scripts/audit-skill-paths.sh --help`

### Task 2.2: Add the new audit to the standard check pipeline
- **Location**:
  - `scripts/check.sh`
  - `.github/workflows/lint.yml`
- **Description**: Integrate the new audit into `scripts/check.sh` (lint mode) and CI so failures block merges. Keep the existing audits (`validate_skill_contracts.sh`, `audit-skill-layout.sh`) intact and order the checks so the path audit runs after layout/contract checks.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 5
- **Acceptance criteria**:
  - `scripts/check.sh --lint` runs `scripts/audit-skill-paths.sh` and reports its exit code on failure.
  - CI runs the audit as part of the lint workflow.
- **Validation**:
  - `scripts/check.sh --lint`
  - `rg -n \"audit-skill-paths\\.sh\" scripts/check.sh .github/workflows/lint.yml`

### Task 2.3: Add regression fixtures/specs for the new audit
- **Location**:
  - `tests/test_audit_scripts.py`
  - `tests/script_specs/scripts/audit-skill-paths.sh.json`
- **Description**: Extend pytest coverage to ensure the new audit script passes on the repo and fails on at least one minimal fixture SKILL.md containing an invalid `$CODEX_HOME/...$CODEX_HOME/...` path. Add a script spec to ensure script regression uses the correct safe invocation when needed.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 6
- **Acceptance criteria**:
  - A new test asserts `scripts/audit-skill-paths.sh` passes for the repo.
  - A new test asserts `scripts/audit-skill-paths.sh` fails for a fixture with a nested `$CODEX_HOME` path and reports `error:`.
  - Script regression/smoke remains green.
- **Validation**:
  - `scripts/test.sh -k audit_skill_paths`

## Sprint 3: Migrate existing skills to comply (paths + shared wrappers)
**Goal**: Make the repo compliant with Skill Anatomy v2 without breaking existing workflows.
**Demo/Validation**:
- Command(s): `scripts/audit-skill-layout.sh && scripts/validate_skill_contracts.sh && scripts/audit-skill-paths.sh`
- Verify: all audits pass; `_projects` skills can be followed literally without hitting missing paths.

### Task 3.1: Fix `_projects` wrapper SKILL.md paths (broken today)
- **Location**:
  - `skills/_projects/tun-group/tun-psql/SKILL.md`
  - `skills/_projects/tun-group/tun-mssql/SKILL.md`
  - `skills/_projects/qburger/qb-mysql/SKILL.md`
  - `skills/_projects/megabank/mb-mssql/SKILL.md`
  - `skills/_projects/finance-report/fr-psql/SKILL.md`
- **Description**: Update the affected `_projects` SKILL.md files so “Wrapper loaded: source …” points to the actual group-level wrapper scripts under each project’s `skills/_projects/PROJECT/scripts/` folder (and remove duplicated `$CODEX_HOME/...$CODEX_HOME/...` segments). Keep examples anchored with `$CODEX_HOME`.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Every referenced wrapper path in these SKILL.md files exists in the repo.
  - No SKILL.md contains a duplicated `$CODEX_HOME/...$CODEX_HOME/...` segment.
- **Validation**:
  - `scripts/audit-skill-paths.sh`

### Task 3.2: Introduce group-level `_libs/` skeletons for sharing (no executable entrypoints)
- **Location**:
  - `skills/workflows/_libs/README.md`
  - `skills/tools/_libs/README.md`
  - `skills/_projects/_libs/README.md`
- **Description**: Create group-level `_libs/` folders (patterned after `skills/automation/_libs`) to hold shared non-executable implementation code and guidance for each top-level skill family. Document the “no shebang / no scripts/ under _libs” rule and provide language subfolders (`sh/`, `zsh/`, `python/`, `md/`) only as needed.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Each new `_libs/README.md` clearly states what belongs there vs in `scripts/`.
  - No new `skills/**/_libs/**` file is executable or lives under a `scripts/` directory.
- **Validation**:
  - `rg -n \"^#!\" skills/*/_libs -S || true`
  - `find skills -type d -name _libs -exec find {} -type d -name scripts -print \\; | cat`

### Task 3.3: Normalize existing shared logic to `_libs/` where appropriate
- **Location**:
  - `skills/automation/_libs/README.md`
  - `skills/_projects/tun-group/scripts/tun-psql.zsh`
  - `skills/_projects/tun-group/scripts/tun-mssql.zsh`
- **Description**: Review existing shared patterns and document the recommended split: wrappers that define user-facing commands/functions remain executable under a group `scripts/`, while reusable helper functions move into `_libs/` (sourced/imported). Apply this split minimally where it reduces duplication without changing behavior.
- **Dependencies**:
  - Task 3.2
- **Complexity**: 6
- **Acceptance criteria**:
  - `_projects/*/scripts/*.zsh` remain directly usable and continue defining the same wrapper functions.
  - Any extracted shared helpers live under `skills/_projects/_libs/` and are non-executable.
- **Validation**:
  - `scripts/test.sh -m script_regression -k _projects`

## Sprint 4: Optional refactor — re-home governance tooling under skills (keep wrappers)
**Goal**: Align with the principle “skill-related tooling lives under skills”, while keeping backwards-compatible stable entrypoints.
**Demo/Validation**:
- Command(s): `scripts/check.sh --lint`
- Verify: `scripts/*` entrypoints still work, but are thin wrappers over `skills/.../scripts/*`.

### Task 4.1: Create a governance skill to own audits/validators
- **Location**:
  - `skills/tools/devex/skill-governance/SKILL.md`
  - `skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`
  - `skills/tools/devex/skill-governance/scripts/validate-skill-contracts.sh`
  - `skills/tools/devex/skill-governance/scripts/audit-skill-paths.sh`
- **Description**: Introduce a dedicated skill whose bundled scripts become the canonical implementations for skill governance checks (layout, contract, paths). This skill documents how to run audits locally and how CI uses them.
- **Dependencies**:
  - Task 2.2
  - Task 2.3
- **Complexity**: 7
- **Acceptance criteria**:
  - The skill exists and documents the governance toolchain without duplicating large script bodies in SKILL.md.
  - Governance scripts in this skill are safe under `--help` and compatible with script regression tests.
- **Validation**:
  - `scripts/test.sh -m script_regression -k skill-governance`

### Task 4.2: Convert `scripts/*` governance entrypoints into thin wrappers
- **Location**:
  - `scripts/audit-skill-layout.sh`
  - `scripts/validate_skill_contracts.sh`
  - `scripts/audit-skill-paths.sh`
- **Description**: Keep the existing `scripts/*` paths stable, but change their implementations to delegate to the canonical scripts under `skills/tools/devex/skill-governance/scripts/`. This allows future evolution without scattering logic across the repo.
- **Dependencies**:
  - Task 4.1
- **Complexity**: 6
- **Acceptance criteria**:
  - Running `scripts/audit-skill-layout.sh`, `scripts/validate_skill_contracts.sh`, and `scripts/audit-skill-paths.sh` behaves identically (exit codes + output format).
  - Script regression tests still pass for both the wrapper and canonical scripts.
- **Validation**:
  - `scripts/test.sh -m script_regression -k audit-skill`
  - `diff -u <(scripts/audit-skill-paths.sh --help) <(skills/tools/devex/skill-governance/scripts/audit-skill-paths.sh --help)`

## Sprint 5: Final validation + rollout guardrails
**Goal**: Ensure the migration is complete, tests are green, and future skills are blocked from regressing.
**Demo/Validation**:
- Command(s): `scripts/check.sh && scripts/test.sh`
- Verify: CI green; docs updated; audits enforced.

### Task 5.1: Run full repo validation and publish “how to add a new skill” checklist
- **Location**:
  - `docs/skills/SKILL_LAYOUT_V2.md`
- **Description**: Add a short, copy-pastable checklist section (“Adding a new skill”) that includes: required directories, where shared code goes, path rules, and the exact commands contributors must run locally before opening a PR.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 4
- **Acceptance criteria**:
  - The checklist includes the exact validation commands and expected outcomes.
  - Running the checklist commands is sufficient to catch the `_projects` path bug class.
- **Validation**:
  - `scripts/check.sh --lint`
  - `rg -n \"^## Adding a new skill$\" docs/skills/SKILL_LAYOUT_V2.md`
  - `rg -n \"scripts/audit-skill-paths\\.sh\" docs/skills/SKILL_LAYOUT_V2.md`

## Testing Strategy

- Unit: pytest tests for audit scripts with minimal fixtures (no network).
- Integration: script regression tests for `scripts/**` and `skills/**/scripts/**` (default `--help` coverage).
- Manual/E2E: spot-check at least one `_projects` wrapper skill end-to-end in a real shell session (source wrapper, run a harmless `SELECT 1`).

## Risks & gotchas

- Risk: false positives in SKILL.md path audit due to examples that intentionally reference non-existent files.
  - Mitigation: only lint `$CODEX_HOME/...` paths (repo-anchored) and allow opt-out markers for truly illustrative examples.
- Risk: shared folders accidentally become executable entrypoints (placing code under `skills/**/scripts/**`).
  - Mitigation: enforce “no `scripts/` under `_libs/`” and require “no shebang” for `_libs` files; add a regression test.
- Risk: moving governance scripts breaks downstream references.
  - Mitigation: keep `scripts/*` as stable wrappers; treat skill-owned scripts as canonical only after wrappers exist.

## Rollback plan

- For doc/spec-only changes: revert the commit(s) touching `docs/skills/*` and `README.md`.
- For audit/tooling changes: revert the new audit wiring in `scripts/check.sh` and CI; keep scripts but stop enforcing in merges.
- For path migrations: revert SKILL.md edits in `_projects/*` and re-run `scripts/test.sh` to confirm rollback correctness.
