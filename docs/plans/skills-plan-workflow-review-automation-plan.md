# Plan: Review + Automate + Validate `skills/workflows/plan`

## Overview

This plan reviews the three planning-related skills (`create-plan`, `create-plan-rigorous`, `execute-plan-parallel`), then designs and implements scriptable automation + validation so plan documents become (a) concrete/executable and (b) easy to split into parallel subagent work. The end state is a small, CI-friendly “plan toolchain” (lint + parse + dependency/parallel batch output) and updated skill templates that consistently produce plans the toolchain can validate.

The plan finishes by dogfooding: creating a brand-new `plan.md` and executing it with `/execute-plan-parallel`, then iterating until the workflow reliably produces parallelizable, verifiable tasks.

## Scope

- In scope:
  - Review and improve: `skills/workflows/plan/{create-plan,create-plan-rigorous,execute-plan-parallel}/SKILL.md`
  - Define a stricter “Plan Format v1” that is both human-friendly and machine-parseable
  - Add repo-local scripts to lint/parse plans + compute dependency order/parallel batches
  - Add tests and integrate plan checks into `scripts/check.sh`
  - Create and execute a real, new plan as a validation case
- Out of scope:
  - Building a full plan execution engine outside of Codex subagents (we’ll emit JSON/batches, but orchestration stays in `/execute-plan-parallel`)
  - Adding a new markdown parser dependency (prefer stdlib + simple conventions)
  - Refactoring unrelated skills or repo tooling beyond what’s needed for plan automation

## Assumptions

1. We can standardize on a single heading structure for plan files:
   - Sprints: `## Sprint N: <name>`
   - Tasks: `### Task N.M: <name>`
2. Plan automation must be CI-friendly: deterministic output, non-interactive, clear exit codes.
3. Plan “concreteness” can be approximated via lint rules (required fields, no placeholders/TBDs, explicit validation commands), even if it can’t be perfectly proven.
4. “Parallelizable” is derived from declared dependencies + file touch overlap heuristics (best-effort), not enforced perfectly.
5. To keep plans machine-parseable, task metadata uses strict values:
   - `Location` is a list of repo-relative file paths
   - `Dependencies` is `none` or a list of exact task IDs (e.g. `Task 2.1`)

## Success criteria

- A new script can lint plan files under `docs/plans/` and fail fast with actionable errors when a plan is underspecified.
- A new script can parse a plan into a stable JSON schema (sprints, tasks, dependencies, validations).
- A new script can compute dependency layers (parallel batches) for a selected sprint.
- `create-plan` and `create-plan-rigorous` templates are updated so newly generated plans pass the linter by default.
- A brand-new plan file is created and executed via `/execute-plan-parallel`, completing at least one parallel batch and running explicit validation commands.

## Sprint 1: Review + Spec (Plan Format v1)

**Goal**: Document gaps in current planning skills and define a machine-parseable plan format + lint rules.

**Demo/Validation**:

- Verify: “Plan Format v1” doc exists, includes required fields, and includes at least 1 fully-worked example task.

**Suggested batches**:

- Batch A: Task 1.1, Task 1.2, Task 1.3
- Batch B: Task 1.4
- Batch C: Task 1.5

### Task 1.1: Review `create-plan` skill and template

- **Location**:
  - `skills/workflows/plan/create-plan/SKILL.md`
  - `docs/plans/reviews/create-plan-skill-review.md`
- **Description**: Identify ambiguity/gaps that prevent plans from being concrete and/or machine-parseable; propose template changes (required fields, validation, dependency conventions).
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - A written checklist of issues + proposed edits captured in `docs/plans/reviews/create-plan-skill-review.md`.
  - Clear guidance for writing tasks that are subagent-ready (scope, files, validation).
- **Validation**:
  - `scripts/validate_skill_contracts.sh --file skills/workflows/plan/create-plan/SKILL.md`

### Task 1.2: Review `create-plan-rigorous` additions and subagent review workflow

- **Location**:
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
  - `docs/plans/reviews/create-plan-rigorous-skill-review.md`
- **Description**: Validate that “Complexity”, dependency tracking, and review steps are sufficient; identify what’s still missing for automation/verification; propose updates.
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - Explicit rules for when complexity is required vs optional (and how to validate).
  - Review rubric for the subagent (what to critique and how to report).
  - Notes captured in `docs/plans/reviews/create-plan-rigorous-skill-review.md`.
- **Validation**:
  - `scripts/validate_skill_contracts.sh --file skills/workflows/plan/create-plan-rigorous/SKILL.md`

### Task 1.3: Review `execute-plan-parallel` parsing expectations and failure modes

- **Location**:
  - `skills/workflows/plan/execute-plan-parallel/SKILL.md`
  - `docs/plans/reviews/execute-plan-parallel-skill-review.md`
- **Description**: Tighten the plan structure contract so “parse → spawn → integrate → validate” is deterministic; propose changes to reduce merge conflicts and improve batching.
- **Dependencies**: none
- **Complexity**: 4
- **Acceptance criteria**:
  - A defined, unambiguous mapping from markdown headings to “sprint/task objects”.
  - Clear “what makes a task unblocked” criteria (dependency IDs, required fields present).
  - Notes captured in `docs/plans/reviews/execute-plan-parallel-skill-review.md`.
- **Validation**:
  - `scripts/validate_skill_contracts.sh --file skills/workflows/plan/execute-plan-parallel/SKILL.md`

### Task 1.4: Write “Plan Format v1” spec + lint rules

- **Location**:
  - `docs/plans/FORMAT.md`
- **Description**: Define required headings, per-task required fields, dependency syntax, validation requirements, placeholder bans, and the JSON schema emitted by the parser.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
  - Task 1.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Spec includes:
    - Required sections/headings
    - Required per-task fields: Location, Description, Dependencies, Acceptance criteria, Validation
    - Optional fields: Complexity, “Parallel notes”, “Owner”
    - Dependency grammar (exact task IDs; no free-text)
    - Parser ignore rules for appendices (e.g. allow `## Execution Notes` without affecting parsing)
    - Lint rules (error vs warn) and exit codes
    - Parser JSON schema with an example payload
  - Spec includes at least one “good task” and one “bad task” example.
- **Validation**:
  - `python3 -m compileall -q .` (sanity for any example code blocks, if present)

### Task 1.5: Design the plan automation toolchain (interfaces + integration points)

- **Location**:
  - `docs/plans/TOOLCHAIN.md`
- **Description**: Decide exact scripts/flags, how to lint all plans, and how `/execute-plan-parallel` will use the outputs. Define minimal “happy path” commands.
- **Dependencies**:
  - Task 1.4
- **Complexity**: 5
- **Acceptance criteria**:
  - Defined CLIs (names + args), e.g.:
    - `scripts/validate_plans.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md`
    - `scripts/plan_to_json.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md --sprint 1`
    - `scripts/plan_batches.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md --sprint 1`
  - Defined integration:
    - `scripts/check.sh --plans` runs the plan linter across tracked plan files.
    - `/execute-plan-parallel` uses the same parsing rules as the scripts (no drift).
- **Validation**:
  - N/A (design task)

## Sprint 2: Implement scripts + tests (lint/parse/batches)

**Goal**: Add CI-friendly scripts that (1) lint plan structure, (2) parse plan → JSON, and (3) compute parallel batches from dependencies.

**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --lint --contracts --skills-layout --plans --tests`
- Verify:
  - New plan scripts have smoke tests and return stable, parseable output.

**Suggested batches**:

- Batch A: Task 2.1
- Batch B: Task 2.2, Task 2.3
- Batch C: Task 2.4
- Batch D: Task 2.5

### Task 2.1: Implement plan parser → JSON (`plan_to_json.sh`)

- **Location**:
  - `scripts/plan_to_json.sh`
- **Description**: Parse a plan file into a stable JSON schema (sprints, tasks, dependencies, validations). This is the machine-readable backbone for `/execute-plan-parallel`, and other tooling should consume this output to avoid drift.
- **Dependencies**:
  - Task 1.4
  - Task 1.5
- **Complexity**: 7
- **Acceptance criteria**:
  - `--file` required; optional `--sprint 1` filters output.
  - JSON includes normalized task IDs, dependencies list, and validation commands.
  - Output is stable (ordering + formatting documented).
- **Validation**:
  - `scripts/plan_to_json.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md | python3 -m json.tool >/dev/null`

### Task 2.2: Implement plan linter (`validate_plans.sh`)

- **Location**:
  - `scripts/validate_plans.sh`
  - `scripts/README.md`
- **Description**: Implement a strict linter for `docs/plans/*-plan.md` enforcing “Plan Format v1” (errors/warnings, helpful messages, exit codes). Prefer consuming `plan_to_json.sh` output where possible to avoid parsing drift.
- **Dependencies**:
  - Task 1.4
  - Task 2.1
- **Complexity**: 7
- **Acceptance criteria**:
  - Supports `--file` repeated + default “lint all tracked plans”.
  - Validates:
    - Sprint/task heading structure
    - Required per-task fields are present
    - Dependencies reference existing task IDs
    - No placeholder tokens (angle-bracket placeholders, common placeholder markers) in required fields
  - Prints `error:` lines to stderr; exits non-zero on errors.
- **Validation**:
  - `scripts/validate_plans.sh --help`
  - `scripts/validate_plans.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md`

### Task 2.3: Implement dependency layering / parallel batches (`plan_batches.sh`)

- **Location**:
  - `scripts/plan_batches.sh`
- **Description**: Compute topological “layers” (parallelizable batches) for a selected sprint and emit as JSON and/or a readable table.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 6
- **Acceptance criteria**:
  - Detects cycles and fails with a clear error.
  - Emits batches as ordered arrays of task IDs.
  - Optionally emits a “conflict risk” note when multiple tasks list overlapping `Location` paths.
- **Validation**:
  - `scripts/plan_batches.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md --sprint 1 | python3 -m json.tool >/dev/null`

### Task 2.4: Add pytest coverage for plan scripts

- **Location**:
  - `tests/test_plan_scripts.py`
  - `tests/fixtures/plan/valid-plan.md`
  - `tests/fixtures/plan/invalid-plan.md`
- **Description**: Add smoke/regression tests mirroring existing script tests (`test_audit_scripts.py` patterns) to validate help output, pass/fail behavior, and JSON schema stability.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 2.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Tests cover:
    - `validate_plans.sh` passes on a valid fixture plan
    - `validate_plans.sh` fails on an invalid fixture plan (missing required fields)
    - `plan_to_json.sh` emits JSON with expected keys
    - `plan_batches.sh` emits deterministic batches for a fixture
- **Validation**:
  - `scripts/test.sh -q`

### Task 2.5: Integrate plan lint into `scripts/check.sh`

- **Location**:
  - `scripts/check.sh`
- **Description**: Add a `--plans` flag (and include in `--all`) that runs `scripts/validate_plans.sh`.
- **Dependencies**:
  - Task 2.2
- **Complexity**: 4
- **Acceptance criteria**:
  - `scripts/check.sh --plans` runs plan lint and propagates failures.
  - `scripts/check.sh --all` includes plan lint.
- **Validation**:
  - `scripts/check.sh --plans`

## Sprint 3: Update skills to produce lintable, parallel-friendly plans

**Goal**: Update planning skills/templates so plans are consistently concrete, automatable, and aligned with the scripts.

**Demo/Validation**:

- Command(s):
  - `scripts/validate_skill_contracts.sh`
  - `scripts/validate_plans.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md`
- Verify:
  - Skill templates include required fields and point to the new scripts for validation.

### Task 3.1: Update `create-plan` template and guidance for “executable tasks”

- **Location**:
  - `skills/workflows/plan/create-plan/SKILL.md`
- **Description**: Update the plan template to match “Plan Format v1” required fields; add explicit guidance for subagent-ready task writing and per-sprint validation.
- **Dependencies**:
  - Task 1.4
  - Task 2.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Template includes required per-task fields and at least one concrete example task snippet.
  - Guidance includes rules for: single-responsibility tasks, minimal file overlap, explicit validations.
- **Validation**:
  - `scripts/validate_skill_contracts.sh --file skills/workflows/plan/create-plan/SKILL.md`

### Task 3.2: Update `create-plan-rigorous` to require linter + review rubric

- **Location**:
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
- **Description**: Add a required “run plan linter” step; strengthen subagent review rubric so review feedback is actionable and aligned with “Plan Format v1”.
- **Dependencies**:
  - Task 1.4
  - Task 2.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Workflow includes: save plan → run linter → spawn review subagent → incorporate feedback.
  - Review instructions include: check for placeholders, missing validation, dependency clarity, parallel batchability.
- **Validation**:
  - `scripts/validate_skill_contracts.sh --file skills/workflows/plan/create-plan-rigorous/SKILL.md`

### Task 3.3: Update `execute-plan-parallel` to reference parser/batches output

- **Location**:
  - `skills/workflows/plan/execute-plan-parallel/SKILL.md`
- **Description**: Align the skill’s parsing/batching workflow with `plan_to_json.sh` + `plan_batches.sh` (avoid drift), and add guidance for conflict minimization.
- **Dependencies**:
  - Task 2.1
  - Task 2.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Skill describes using script outputs to select unblocked tasks and launch batches.
  - Skill instructs subagents to avoid overlapping edits and to report file changes + validation.
- **Validation**:
  - `scripts/validate_skill_contracts.sh --file skills/workflows/plan/execute-plan-parallel/SKILL.md`

### Task 3.4: Add docs for plan tooling + format

- **Location**:
  - `docs/plans/README.md`
  - `docs/plans/FORMAT.md`
  - `docs/plans/TOOLCHAIN.md`
  - `scripts/README.md`
- **Description**: Document the new “plan toolchain” commands, expected outputs, and how to validate a plan before running `/execute-plan-parallel`.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 2.3
- **Complexity**: 4
- **Acceptance criteria**:
  - Docs include copy/paste commands for lint/parse/batches.
  - Docs clarify what “concrete/executable” means in this repo.
- **Validation**:
  - `scripts/validate_plans.sh --file docs/plans/skills-plan-workflow-review-automation-plan.md`

## Sprint 4: Dogfood with a real plan + real execution

**Goal**: Prove the workflow works end-to-end by creating a brand-new plan file and executing it with `/execute-plan-parallel`, then iterating until it meets success criteria.

**Demo/Validation**:

- Command(s):
  - `scripts/validate_plans.sh --file docs/plans/plan-dogfood-example-plan.md`
  - `/execute-plan-parallel docs/plans/plan-dogfood-example-plan.md sprint 1`
  - `scripts/check.sh --all`
- Verify:
  - At least one parallel batch executes without merge conflicts that require redesigning tasks.
  - All validations described in the plan are actually run and pass.

### Task 4.1: Create a new dogfood plan file with parallelizable tasks

- **Location**:
  - `docs/plans/plan-dogfood-example-plan.md`
- **Description**: Write a small, real plan (1 sprint is enough) with 3–6 tasks that touch mostly-disjoint files and include explicit validation commands.
- **Dependencies**:
  - Task 2.2
  - Task 3.1
  - Task 3.2
  - Task 3.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Plan passes `validate_plans.sh`.
  - `plan_batches.sh` shows at least one batch with 2+ tasks runnable in parallel.
- **Validation**:
  - `scripts/validate_plans.sh --file docs/plans/plan-dogfood-example-plan.md`
  - `scripts/plan_batches.sh --file docs/plans/plan-dogfood-example-plan.md --sprint 1`

### Task 4.2: Execute the dogfood plan via `/execute-plan-parallel` and record outcomes

- **Location**:
  - `docs/plans/plan-dogfood-example-plan.md`
- **Description**: Run `/execute-plan-parallel` on the dogfood plan; spawn subagents per batch; integrate results; run validations. Capture what worked/failed.
- **Dependencies**:
  - Task 4.1
- **Complexity**: 8
- **Acceptance criteria**:
  - Execution completes with explicit validations run.
  - Any blockers are recorded with concrete fixes (either in code/scripts or by rewriting the plan).
- **Validation**:
  - `scripts/check.sh --all`

### Task 4.3: Iterate based on failures (tighten lint rules / templates)

- **Location**:
  - `scripts/validate_plans.sh`
  - `docs/plans/FORMAT.md`
  - `skills/workflows/plan/create-plan/SKILL.md`
  - `skills/workflows/plan/create-plan-rigorous/SKILL.md`
  - `skills/workflows/plan/execute-plan-parallel/SKILL.md`
- **Description**: If dogfood execution reveals gaps (underspecified tasks, parser drift, batching issues), fix the root cause: adjust lint rules, templates, and docs; re-run dogfood until success criteria are met.
- **Dependencies**:
  - Task 4.2
- **Complexity**: 7
- **Acceptance criteria**:
  - Dogfood plan can be re-run and passes end-to-end with minimal manual intervention.
  - The updated templates prevent the same failure class from recurring.
- **Validation**:
  - Re-run Task 4.2 validations.

## Testing Strategy

- Unit (pytest):
  - Validate linter catches missing required fields and bad dependency references.
  - Validate parser JSON schema keys and ordering are stable.
  - Validate batcher detects cycles and produces deterministic layering.
- Integration:
  - `scripts/check.sh --all` in a clean environment.
- Manual/Workflow:
  - Run `/execute-plan-parallel` on the dogfood plan and confirm parallel execution actually happens.

## Risks & gotchas

- Markdown “parsing” can get brittle; we must keep the format conventions narrow and explicit.
- Overly strict lint rules can make planning feel heavy; balance errors vs warnings.
- File overlap heuristics can be noisy (directories vs files); treat as guidance, not a hard gate.
- Keeping `/execute-plan-parallel` parsing logic aligned with scripts requires explicit references to avoid drift.

## Rollback plan

- If the new plan scripts are too disruptive:
  - Remove `--plans` from `scripts/check.sh` (or leave flag but exclude from `--all`).
  - Keep `docs/plans/FORMAT.md` as guidance only.
  - Revert skill template changes to the last working version.
