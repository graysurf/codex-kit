# Plan Format v1

This repo treats plans as both human docs and machine-parseable inputs for tooling + `/execute-plan-parallel` execution.

## Required structure

- Plan title: first `# ...` heading (recommended: `# Plan: <name>`)
- Sprints (required for tooling):
  - Heading: `## Sprint N: <name>` where `N` is an integer (1, 2, 3, ...)
- Tasks (required for tooling):
  - Heading: `### Task N.M: <name>` where `N` is the sprint number and `M` is an integer (1, 2, 3, ...)
  - Tasks must be under a sprint heading.

## Required per-task fields

Each task must include the following fields (exact labels):

- `Location` (list): repo-relative file paths the task will touch
- `Description` (string): what to do, in one paragraph
- `Dependencies` (list or `none`): task IDs this task depends on
- `Acceptance criteria` (list): objective, checkable outcomes
- `Validation` (list): commands or checks to run

### Canonical example

```md
### Task 1.2: Add plan linter
- **Location**:
  - `scripts/plan/validate_plans.sh`
  - `scripts/README.md`
- **Description**: Add a plan linter script that enforces Plan Format v1 for docs/plans/*-plan.md.
- **Dependencies**:
  - Task 1.1
- **Acceptance criteria**:
  - `scripts/plan/validate_plans.sh` exits 0 on valid plans.
  - `scripts/plan/validate_plans.sh` exits non-zero with `error:` lines on invalid plans.
- **Validation**:
  - `scripts/plan/validate_plans.sh --file docs/plans/example-plan.md`
```

## Field rules (linted)

- `Location`
  - Must be a non-empty list.
  - Must not contain placeholders.
- `Dependencies`
  - Use `none` for no dependencies.
  - Otherwise must be a list of exact task IDs: `Task N.M` (no free text).
  - Dependencies must exist in the same plan file.
- `Acceptance criteria` and `Validation`
  - Must be non-empty lists.
- Placeholders
  - Required fields must not contain placeholder tokens:
    - `<...>` (angle-bracket placeholders)
    - `TBD`
    - `TODO`

## Optional fields

- `Complexity` (int 1–10): required by `create-plan-rigorous`, optional for `create-plan`

## Parser ignore rules

Tooling only reads sprint/task headings and task fields. Any other sections (e.g. `## Overview`, `## Risks`, `## Execution Notes`) are ignored as long as task headings remain valid.

## JSON schema (scripts/plan/plan_to_json.sh)

`scripts/plan/plan_to_json.sh` emits JSON with:

- `title` (string)
- `file` (string, repo-relative if possible)
- `sprints` (array)
  - `number` (int)
  - `name` (string)
  - `start_line` (int, 1-based)
  - `tasks` (array)
    - `id` (string, `Task N.M`)
    - `name` (string)
    - `sprint` (int)
    - `start_line` (int, 1-based)
    - `location` (array of strings)
    - `description` (string or null)
    - `dependencies` (array of strings)
    - `complexity` (int or null)
    - `acceptance_criteria` (array of strings)
    - `validation` (array of strings)
