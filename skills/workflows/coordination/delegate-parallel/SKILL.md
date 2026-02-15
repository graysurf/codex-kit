---
name: delegate-parallel
description: Decompose a multi-part goal into parallelizable tasks and execute them via parallel subagents, integrating and validating iteratively.
---

# Delegate (Parallel)

Execute a multi-part request by delegating independent tasks to parallel subagents, integrating their results, and iterating until acceptance criteria are met.

## Contract

Prereqs:

- The user explicitly triggers this workflow (recommended invocation: `/delegate-parallel <goal>`).
- The request can be decomposed into 2+ tasks with limited file overlap.
- You can spawn and monitor multiple subagents.
- There is a way to validate changes (tests/lint/build or a concrete manual checklist).
- You can write artifacts to `$AGENTS_HOME/out/` (fallback: repo `out/` if needed).

Inputs:

- A user goal (natural language) plus any constraints/success criteria.
- Optional knobs (defaults recommended):
  - `max_agents`: 3
  - `max_retries_per_task`: 2
  - `mode`: patch-artifacts (subagents deliver `changes.patch`; orchestrator applies + validates)
  - `artifact_root`: `$AGENTS_HOME/out/delegate-parallel/<run-id>/`

Outputs:

- Integrated code changes implementing the goal.
- A concise execution summary: completed tasks, blocked tasks, files changed, and validation performed.

Exit codes:

- N/A (workflow skill)

Failure modes:

- The request is not safely parallelizable (tight sequential dependencies or high file overlap).
- Acceptance criteria remain unclear and the user will not confirm assumptions.
- Subagent outputs are incomplete (missing patch/report/validation evidence).
- Integration conflicts or validation failures cannot be resolved within retry budget.

## When to use

Use this workflow when you have a single user goal that naturally splits into independent workstreams (e.g., API + UI + docs, or multiple isolated modules) and you want to keep the main agent context focused on orchestration + acceptance.

Do not use it for small changes or tightly-coupled refactors.

## Core principles

- **Context hygiene**: subagents write details (diffs/logs) to artifacts; chat stays short.
- **Strict scope**: each subagent implements exactly one task card.
- **Artifact-based handoff**: prefer `changes.patch` over pasting diffs into chat.
- **Acceptance-gated iteration**: reject with a concrete delta and retry until correct (max 2 retries by default).

## Workflow

### Step 1 — Gate: decide if parallelization is worth it

Proceed only if you can identify at least 2 tasks that are:

- Independently implementable,
- Scoped to a small file/module set,
- Unlikely to conflict when integrated.

If not, stop and execute sequentially without subagents.

### Step 2 — Clarify must-haves (when needed)

If objective/scope/constraints/done criteria are unclear, ask 1–5 “Need to know” questions before dispatch.

Use the format from `$AGENTS_HOME/skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`.

### Step 3 — Decompose into task cards

Create task cards (in-memory, and optionally written to the run folder as `TASKS.md`) with:

- `ID`: `T1`, `T2`, …
- `Objective`: single responsibility
- `Scope`: allowed dirs/files; explicit “out of scope”
- `Dependencies`: other task IDs (if any)
- `Acceptance criteria`: checklist
- `Validation`: minimum commands or manual checks
- `Expected artifacts`: `REPORT.md`, `changes.patch`, `commands.txt`, `logs.txt`

If two cards must edit the same files substantially, merge them or serialize them.

### Step 4 — Create an artifact run folder

Create:

- `artifact_root = $AGENTS_HOME/out/delegate-parallel/<run-id>/` (preferred)
- Fallback (if `AGENTS_HOME` is unavailable): `out/delegate-parallel/<run-id>/`

For each task card, allocate a folder:

- `<artifact_root>/<task-id>/`

### Step 5 — Dispatch parallel subagents (batch by dependency)

- Spawn up to `max_agents` subagents for tasks with no unmet dependencies.
- Provide each subagent:
  - The task card text
  - The task artifact folder path
  - A strict instruction: “Implement this task only; do not expand scope.”

### Step 6 — Subagent completion requirements (required)

Each subagent must produce in its task folder:

- `REPORT.md` (≤10 lines):
  - What changed
  - Files touched
  - How acceptance criteria are met
  - Validation commands run + result (or “not run” + reason)
  - Remaining risks/blockers
- `changes.patch`: clean unified diff against the current workspace (no unrelated churn)
- `commands.txt`: commands executed (if any)
- `logs.txt`: trimmed logs (full logs go here, not in chat)

Chat response must be short: 3–8 lines + artifact paths only.

### Step 7 — Orchestrator acceptance (review + apply + iterate)

For each completed task:

1. Verify artifacts exist and match scope.
2. Apply the patch (preferred: `git apply <changes.patch>`), in a deterministic order.
3. Run the task’s validation (or the closest available equivalent).
4. If rejected:
   - Send the subagent a concrete rejection reason + acceptance delta.
   - Include only minimal failing excerpts in chat; put full logs under the task folder.
   - Request an updated `changes.patch`.
   - Retry up to `max_retries_per_task` times.

If a task exceeds retry budget: stop and report it as blocked (or take over sequentially if the user asks).

### Step 8 — Global validation

After integrating a batch (or all tasks), run the repo’s best overall validation (tests/lint/build). Treat this as a gate.

If it fails:

- Triage which task likely caused it.
- Create a small “fix task card” (`FX1`, `FX2`, …) scoped to the failing area.
- Dispatch to the responsible subagent (or a new one) with logs + expected fix.

### Step 9 — Report

Summarize:

- Completed vs blocked tasks
- Key files changed
- Validation status (what ran, what didn’t, why)

## Subagent prompt template (recommended)

You are a subagent implementing exactly ONE task.

Task:
<paste task card here>

Rules:
- Stay strictly within scope and allowed files.
- Do not paste large diffs into chat.
- Write artifacts to: <task artifact folder>
- Deliver:
  - REPORT.md
  - changes.patch
  - commands.txt + logs.txt

Return in chat:
- 3–8 line summary + artifact paths + blockers only.
