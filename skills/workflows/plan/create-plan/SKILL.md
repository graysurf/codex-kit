---
name: create-plan
description:
  Create a comprehensive, phased implementation plan and save it under docs/plans/. Use when the user asks for an implementation plan (make
  a plan, outline the steps, break down tasks, etc.).
---

# Create Plan

Create detailed, phased implementation plans (sprints + atomic tasks) for bugs, features, or refactors. This skill produces a plan document
only; it does not implement.

## Contract

Prereqs:

- User is asking for an implementation plan (not asking you to build it yet).
- You can read enough repo context to plan safely (or the user provides constraints).
- `plan-tooling` available on `PATH` for linting/parsing/splitting (`validate`, `to-json`, `batches`, `split-prs`; install via
  `brew install nils-cli`).

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

## Entrypoint

- None. This is a workflow-only skill with no `scripts/` entrypoint.

## Workflow

1. Decide whether you must ask questions first

- If the request is underspecified, ask 1–5 “need to know” questions before writing the plan.
- Follow the structure from `$AGENT_HOME/skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md` (numbered questions, short
  options, explicit defaults).

1. Research the repo just enough to plan well

- Identify existing patterns, modules, and similar implementations.
- Note constraints (runtime, tooling, deployment, CI, test strategy).

1. Write the plan (do not implement)

- Follow the shared baseline in `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.
- Fill `Complexity` when it materially affects batching/splitting or when a task looks oversized.
- You may omit sprint scorecards unless the user explicitly wants deeper sizing analysis or execution modeling.

1. Save the plan file

- Use the shared save rules from `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.

1. Lint the plan (format + executability)

- Use the shared lint flow from `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.

1. Run an executability + grouping pass (mandatory)

- Use the shared executability + grouping workflow in `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.
- Add sprint metadata only when the plan needs explicit grouping/parallelism metadata or the user asks for that level of execution detail.

1. Review “gotchas”

- Use the shared `Risks & gotchas` guidance from `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.

## Plan Template

Shared markdown scaffold:

- `skills/workflows/plan/_shared/assets/plan-template.md`

Canonical shared authoring and validation rules:

- `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`

Optional scaffold helper (creates a placeholder plan; fill it before linting):

- `plan-tooling scaffold --slug <kebab-case> --title "<task name>"`
