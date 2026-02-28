---
name: create-plan-rigorous
description:
  Create an extra-thorough implementation plan (sprints + atomic tasks) and get a subagent review. Use when the user wants a more rigorous
  plan than usual.
---

# Create Plan (Rigorous)

Same as `create-plan`, but more rigorous: add per-task complexity notes, explicitly track dependencies, and get a subagent review before
finalizing.

## Contract

Prereqs:

- User explicitly requests a more rigorous plan than normal.
- You can spawn a review subagent.
- `plan-tooling` available on `PATH` for linting/parsing/splitting (`validate`, `to-json`, `batches`, `split-prs`; install via
  `brew install nils-cli`).

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

1. Clarify (if needed)

- If underspecified, ask 1–5 “need to know” questions first.
- Use the format from `$AGENT_HOME/skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`.

1. Research

- Identify existing patterns and the minimal touch points.
- Identify tricky edge cases, migrations, rollout, and compatibility constraints.

1. Draft the plan (do not implement)

- Same structure as `create-plan`, plus:
  - Fill a per-task **Complexity** score (1–10).
  - Explicitly list dependencies and parallelizable tasks.
  - Treat each sprint as an integration gate; do not plan cross-sprint execution parallelism.
  - Focus parallelization design inside each sprint (task/PR dependency graph), not across sprints.
  - Add sprint metadata lines with exact case-sensitive labels:
    - `**PR grouping intent**: per-sprint|group`
    - `**Execution Profile**: serial|parallel-xN`
  - Keep grouping/profile metadata coherent:
    - If `PR grouping intent` is `per-sprint`, do not declare parallel width `>1`.
    - If planning multi-lane parallel PR execution, set `PR grouping intent` to `group`.
  - Add a “Rollback plan” that is operationally plausible.

1. Save the plan

- Path: `docs/plans/<slug>-plan.md` (kebab-case, end with `-plan.md`).

1. Lint the plan (format + executability)

- Run: `plan-tooling validate --file docs/plans/<slug>-plan.md`
- Fix until it passes (no placeholders in required fields; explicit validation commands; dependency IDs exist).

1. Run a sizing + parallelization pass (mandatory)

- Parallelization policy for this skill:
  - `Sprint` is an integration/decision gate. Do not schedule cross-sprint execution parallelism.
  - Optimize for parallel execution inside a sprint by improving the task DAG (dependencies, file overlap, PR grouping).
- For each sprint, run:
  - `plan-tooling to-json --file docs/plans/<slug>-plan.md --sprint <n>`
  - `plan-tooling batches --file docs/plans/<slug>-plan.md --sprint <n>`
  - `plan-tooling split-prs --file docs/plans/<slug>-plan.md --scope sprint --sprint <n> --strategy auto --default-pr-grouping group --format json`
- If planning explicit deterministic/manual grouping for a sprint:
  - Provide explicit mapping for every task: `--pr-group <task-id>=<group>` (repeatable).
  - Validate with:

    ```bash
    plan-tooling split-prs --file docs/plans/<slug>-plan.md --scope sprint --sprint <n> --pr-grouping group --strategy deterministic --pr-group ... --format json
    ```

- If planning explicit single-lane-per-sprint behavior:
  - Validate with:

    ```bash
    plan-tooling split-prs --file docs/plans/<slug>-plan.md --scope sprint --sprint <n> --pr-grouping per-sprint --strategy deterministic --format json
    ```

- Metadata guardrails:
  - Metadata field names are strict; do not use variants such as `PR Grouping Intent`.
  - `plan-tooling validate` now blocks metadata mismatch by default (`per-sprint` cannot pair with parallel width `>1`).
- Per-sprint sizing/parallelization scorecard (record in the plan or sprint notes):
  - `Execution Profile`: `serial` | `parallel-x2` | `parallel-x3`
  - `TotalComplexity`: sum of task complexity in the sprint
  - `CriticalPathComplexity`: sum of complexity on the longest dependency chain
  - `MaxBatchWidth`: widest dependency batch returned by `plan-tooling batches`
  - `OverlapHotspots`: same-batch file/module overlap risks to watch
- Sizing guardrails (adjust plan when violated):
  - Task complexity target is `1-6`; complexity `>=7` should usually be split into smaller tasks.
  - PR complexity target is `2-5`; preferred max is `6`.
  - PR complexity `7-8` is an exception and requires explicit justification (single responsibility, low overlap, isolated validation).
  - PR complexity `>8` should be split before execution planning.
  - Sprint target is `2-5` tasks and total complexity `8-24`, but evaluate it with the sprint's execution profile:
    - `serial`: target `2-4` tasks, `TotalComplexity 8-16`, `CriticalPathComplexity 8-16`, `MaxBatchWidth = 1`
    - `parallel-x2`: target `3-5` tasks, `TotalComplexity 12-22` (up to `24` if justified), `CriticalPathComplexity 8-14`,
      `MaxBatchWidth <= 2`
    - `parallel-x3`: target `4-6` tasks, `TotalComplexity 16-24`, `CriticalPathComplexity 10-16`, `MaxBatchWidth <= 3`
  - Do not use `TotalComplexity` alone as the sizing signal; `CriticalPathComplexity` is the primary throughput constraint.
  - If dependency layers become mostly serial (for example a chain of `>3` tasks), rebalance/split to recover parallel lanes unless the
    sequence is intentionally strict.
  - For a task with complexity `>=7`, try to split first; if it cannot be split cleanly, keep it as a dedicated lane and dedicated PR (when
    parallelizable and isolated enough).
  - Default limit is at most one task with complexity `>=7` per sprint; more than one requires explicit justification plus low overlap,
    frozen contracts, and non-blocking validation.
  - For tasks in the same dependency batch, avoid heavy file overlap in `Location`; if overlap is unavoidable, either group those tasks into
    one PR or serialize them explicitly.
- After each adjustment, rerun `plan-tooling validate` and the relevant `split-prs` command(s) until output is stable and executable in the
  intended grouping mode.

1. Subagent review

- Spawn a subagent to review the saved plan file.
- Give it: the plan path + the original request + any constraints.
- Explicitly instruct it: “Do not ask questions; only provide critique and improvements.”
- Review rubric for the subagent:
  - Check for missing required task fields (`Location`, `Description`, `Dependencies`, `Acceptance criteria`, `Validation`).
  - Check for placeholder tokens left behind (`<...>`, `TODO`, `TBD`) in required fields.
  - Check task atomicity (single responsibility) and parallelization opportunities (dependency clarity, minimal file overlap).
  - Check the plan can be split with `plan-tooling split-prs` in the intended
    grouping mode (`--strategy auto --default-pr-grouping group` by default;
    `--strategy deterministic --pr-grouping group` with full mapping or
    `--strategy deterministic --pr-grouping per-sprint` when explicitly
    requested).
  - Check sprint metadata labels are exact (`PR grouping intent`, `Execution Profile`) and consistent with grouping strategy.
  - Check sprint/task sizing is realistic for subagent PR execution (not just conceptually valid).
  - Check the sprint scorecard (`Execution Profile`, `TotalComplexity`, `CriticalPathComplexity`, `MaxBatchWidth`, `OverlapHotspots`) is
    present and consistent with dependencies.
  - Check no cross-sprint execution parallelism is implied by the plan sequencing.
  - Check that validation is runnable and matches acceptance criteria.
- Incorporate useful feedback into the plan (keep changes minimal and coherent).

1. Final gotchas pass

- Ensure the plan has clear success criteria, validation commands, risk mitigation, and explicit execution grouping intent per sprint.

## Plan Template

Shared template (single source of truth):

- `skills/workflows/plan/_shared/assets/plan-template.md`

Rigorous requirement:

- Fill `Complexity` for every task (int 1–10).
- Treat sprints as sequential integration gates (no cross-sprint execution parallelism).
- Optimize parallelism within each sprint and document the per-sprint scorecard (`Execution Profile`, `TotalComplexity`,
  `CriticalPathComplexity`, `MaxBatchWidth`, `OverlapHotspots`).
