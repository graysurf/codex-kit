---
name: execute-plan-parallel
description: Execute a markdown implementation plan by spawning parallel subagents for unblocked tasks, then integrate results and validate. Triggers on explicit "/execute-plan-parallel <plan.md> [sprint <n>]".
---

# Execute Plan (Parallel)

Run an existing plan by delegating independent tasks to parallel subagents, then integrating and validating the combined result.

## Contract

Prereqs:

- A plan file exists (markdown) with clear task breakdown and dependencies.
- You can spawn and monitor multiple subagents.
- The repo has a way to validate changes (tests, lint, build, or a manual checklist).

Inputs:

- Plan file path (required).
- Optional: sprint/phase selector (e.g., “sprint 2”, “phase 1”).

Outputs:

- Code changes implementing the selected sprint/phase (or the whole plan).
- A concise execution summary: completed tasks, blocked tasks, files changed, and validation performed.

Exit codes:

- N/A (multi-step workflow skill)

Failure modes:

- Plan parsing fails (unexpected heading structure) or sprint not found.
- Tasks conflict in the same files and require sequential execution/merge resolution.
- A task is underspecified or blocked (missing access, unclear acceptance criteria).

## Workflow

1) Parse the request

- Identify the plan file path.
- If no sprint/phase is specified, ask the user which sprint/phase to run (or default to Sprint 1).

2) Read and parse the plan

- Prefer using repo tooling (avoid parsing drift):
  - Lint: `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh --file <plan.md>`
  - Parse JSON: `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh --file <plan.md> [--sprint <n>]`
  - Compute batches: `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh --file <plan.md> --sprint <n>`
- Locate the selected sprint/phase section (e.g., `## Sprint 1:`).
- Extract tasks (e.g., `### Task 1.1:`).
- For each task, capture:
  - ID/name
  - Location(s)
  - Acceptance criteria
  - Validation
  - Dependencies / blockers

3) Launch parallel subagents for unblocked tasks

- Batch-launch subagents for tasks that have no unmet dependencies (use `plan_batches.sh` output when available).
- Provide each subagent the task text, relevant context, and strict scope: “implement this task only”.
- Require each subagent to report:
  - Files modified/created
  - What changed
  - How acceptance criteria are met
  - What validation ran (or why not)

4) Integrate results and resolve conflicts

- Apply changes, resolve overlapping edits, and keep diffs minimal.
- If the plan implies commits, follow the repo’s commit policy (do not run `git commit` directly).

5) Repeat

- Mark completed tasks.
- Launch the next batch of unblocked tasks until the sprint/phase is done.

6) Validate

- Run the plan’s validation commands (or the closest available repo commands).
- If validation fails, fix within scope or mark the task blocked with the failure reason.

7) Report

- Summarize: completed vs blocked tasks, files changed, and validation status.
