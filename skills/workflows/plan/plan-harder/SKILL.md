---
name: plan-harder
description: Create an extra-thorough implementation plan (sprints + atomic tasks) and get a subagent review. Use when the user explicitly says "plan harder".
---

# Plan Harder

Same as `planner`, but more rigorous: add per-task complexity notes, explicitly track dependencies, and get a subagent review before finalizing.

## Contract

Prereqs:

- User explicitly requests “plan harder” (or clearly wants a more rigorous plan than normal).
- You can spawn a review subagent.

Inputs:

- User request (goal, scope, constraints, success criteria).
- Optional: repo context (files, architecture notes, existing patterns).

Outputs:

- A new plan file saved to `docs/plans/<slug>-plan.md`.
- A short response linking the plan path and summarizing key decisions/risks.

Exit codes:

- N/A (conversation/workflow skill)

Failure modes:

- Request remains underspecified and the user won’t confirm assumptions.
- Plan requires repo access/info you can’t obtain.
- Subagent review yields conflicting guidance; reconcile and document the decision.

## Workflow

1) Clarify (if needed)

- If underspecified, ask 1–5 “need to know” questions first.
- Use the format from `$CODEX_HOME/skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`.

2) Research

- Identify existing patterns and the minimal touch points.
- Identify tricky edge cases, migrations, rollout, and compatibility constraints.

3) Draft the plan (do not implement)

- Same structure as `planner`, plus:
  - Add a per-task **Complexity** score (1–10).
  - Explicitly list dependencies and parallelizable tasks.
  - Add a “Rollback plan” that is operationally plausible.

4) Save the plan

- Path: `docs/plans/<slug>-plan.md` (kebab-case, end with `-plan.md`).

5) Subagent review

- Spawn a subagent to review the saved plan file.
- Give it: the plan path + the original request + any constraints.
- Explicitly instruct it: “Do not ask questions; only provide critique and improvements.”
- Incorporate useful feedback into the plan (keep changes minimal and coherent).

6) Final gotchas pass

- Ensure the plan has clear success criteria, validation commands, and risk mitigation.

## Plan Template (delta)

Add this field to each task:

```markdown
- **Complexity**: <1-10>
```
