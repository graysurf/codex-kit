---
name: create-plan
description: Create a comprehensive, phased implementation plan and save it under docs/plans/. Use when the user asks for an implementation plan (make a plan, outline the steps, break down tasks, etc.).
---

# Create Plan

Create detailed, phased implementation plans (sprints + atomic tasks) for bugs, features, or refactors. This skill produces a plan document only; it does not implement.

## Contract

Prereqs:

- User is asking for an implementation plan (not asking you to build it yet).
- You can read enough repo context to plan safely (or the user provides constraints).

Inputs:

- User request (goal, scope, constraints, success criteria).
- Optional: repo context (files, architecture notes, existing patterns).

Outputs:

- A new plan file saved to `docs/plans/<slug>-plan.md`.
- A short response that links the plan path and summarizes the approach.

Exit codes:

- N/A (conversation/workflow skill)

Failure modes:

- Request remains underspecified and the user won’t confirm assumptions.
- Plan requires access/info the user cannot provide (credentials, private APIs, etc.).

## Workflow

1) Decide whether you must ask questions first

- If the request is underspecified, ask 1–5 “need to know” questions before writing the plan.
- Follow the structure from `$CODEX_HOME/skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md` (numbered questions, short options, explicit defaults).

2) Research the repo just enough to plan well

- Identify existing patterns, modules, and similar implementations.
- Note constraints (runtime, tooling, deployment, CI, test strategy).

3) Write the plan (do not implement)

- Use sprints/phases that each produce a demoable/testable increment.
- Break work into atomic, independently testable tasks.
- Include file paths whenever you can be specific.
- Include a validation step per sprint (commands, checks, expected outcomes).

4) Save the plan file

- Path: `docs/plans/<slug>-plan.md`
- Slug rules: lowercase kebab-case, 3–6 words, end with `-plan.md`.

5) Lint the plan (format + executability)

- Run: `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh --file docs/plans/<slug>-plan.md`
- If it fails: tighten tasks (missing fields, placeholders, unclear validations) until it passes.

6) Review “gotchas”

- After saving, add/adjust a “Risks & gotchas” section: ambiguity, dependencies, migrations, rollout, backwards compatibility, and rollback.

## Plan Template

```markdown
# Plan: <Task name>

## Overview
<2–5 sentences: what changes, what stays the same, approach>

## Scope
- In scope: ...
- Out of scope: ...

## Assumptions (if any)
1. ...

## Sprint 1: <Name>
**Goal**: ...
**Demo/Validation**:
- Command(s): ...
- Verify: ...

### Task 1.1: <Name>
- **Location**:
  - `<file paths>`
- **Description**: ...
- **Dependencies**:
  - <task IDs or "none">
- **Acceptance criteria**:
  - ...
- **Validation**:
  - ...

## Sprint 2: <Name>
...

## Testing Strategy
- Unit: ...
- Integration: ...
- E2E/manual: ...

## Risks & gotchas
- ...

## Rollback plan
- ...
```
