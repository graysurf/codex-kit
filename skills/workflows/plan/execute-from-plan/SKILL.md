---
name: execute-from-plan
description: Resume and execute plan-driven implementation work with a durable execution-state ledger.
---

# Execute From Plan

Use this skill when a durable plan should be the execution-control source for implementation and cross-session progress.

## Contract

Scope boundary:

- For multi-step or cross-session implementation, prefer a plan as the
  execution-control source.
- Source docs such as `*-discussion-source.md` and `*-review-source.md` should
  normally be paired with a sibling plan that links them under `Read First`.
- Direct source-doc execution is allowed only for bounded single-step work, or
  when the user explicitly accepts a direct-execution waiver and that waiver is
  recorded in execution state.

Prereqs:

- User explicitly asks to start, continue, resume, or execute work from a durable plan or bounded source doc.
- Execution source exists and is ready enough to proceed, or gaps can be recorded safely before asking for the minimum clarification.
- Target workspace is available, required project preflight has passed, and project rules allow edits.
- A progress record exists or can be created as an execution-state document.

Inputs:

- Execution source path, preferably an execution-ready plan. A source doc such
  as an implementation handoff, improvement record, or equivalent project doc is
  accepted only when direct execution is bounded or explicitly waived.
- Optional execution-state path; when absent, use the source document's `Execution` section or create a sibling
  `<source-slug>-execution-state.md`.
- Optional task, phase, sprint, or priority selector.
- Optional validation commands, scope limits, branch/commit policy, linked issue/PR, and user-provided stop conditions.

Outputs:

- Scoped code, docs, config, test, or workflow changes for the next unblocked task unless execution is blocked.
- Created or updated execution-state document with current status, task ledger, validation evidence, blockers, and append-only session log.
- Source document updates only when durable facts, decisions, acceptance criteria, execution-state links, or guardrails changed.
- A concise final response summarizing completed work, blocked work, files changed, validation, and next step.

Exit codes:

- N/A (multi-step workflow skill)

Failure modes:

- Source document is missing, unreadable, or does not contain enough execution contract to proceed safely.
- Required task, acceptance criteria, validation plan, or guardrail is ambiguous enough that execution would risk the wrong change.
- Execution state conflicts with the work tree, branch, or source document; inspect and reconcile before editing.
- Work tree contains unrelated dirty changes that overlap the selected task; preserve user changes and ask if needed.
- Validation fails and cannot be fixed within the selected task scope; record the failure and stop without claiming completion.

## Execution-Ready Source Contract

Accepted source documents include:

- `discussion-to-implementation-doc` implementation handoffs.
- `review-to-improvement-doc` improvement records with executable backlog.
- `create-plan` or `create-dispatch-plan` plans.
- Hand-written project docs that carry the same execution contract.

Plan-created source docs under `docs/plans/<slug>/` are read-first inputs, not
the preferred execution-control artifact. If a sibling `<slug>-plan.md` exists,
execute from that plan. If no sibling plan exists and the work is multi-step,
create or request a plan before editing production files.

Required source content:

- Goal or purpose.
- Scope and non-scope, or an equivalent boundary.
- Task ledger, backlog, sprint, phase, or next-task source.
- Acceptance criteria.
- Validation plan.
- Guardrails and known risks.
- Open questions or blockers.
- Execution-state path or enough context to create one.

Do not treat `review-evidence.json` as the primary source document. Link it as evidence from an improvement record or execution state.

## Workflow

1. Resolve and classify the source
   - Read the source document first.
   - Classify it as `implementation-handoff`, `improvement-record`, `plan`, or `other-execution-doc`.
   - If the source is a plan-created `*-discussion-source.md` or
     `*-review-source.md`, look for a sibling `<slug>-plan.md` and use that plan
     as the execution source when it exists.
   - If the source doc is not paired with a plan and the requested work needs
     sequencing, dependencies, or multiple tasks, stop and use `create-plan` or
     `create-dispatch-plan` instead of starting edits.
   - Follow project preflight before reading or editing additional files.
   - If the document references `Read First` files, read only the files needed for the selected task.

2. Verify execution readiness
   - Check for the required source content listed above.
   - For direct source-doc execution, verify the work is a bounded single-step
     change or record an explicit direct-execution waiver in execution state.
   - If fields are missing but the next safe step is obvious, record assumptions in execution state and continue.
   - If missing context could change scope, safety, acceptance, or reversibility, ask the minimum clarification and stop.

3. Establish execution state
   - Use the source document's execution-state link when present.
   - If absent, create a sibling state document named `<source-slug>-execution-state.md` and add a link from the source document.
   - Keep top sections editable for fast resume.
   - Keep `Session Log` append-only so prior decisions and validation evidence remain traceable.

4. Resume the next task
   - Inspect `Current State`, `Task Ledger`, blockers, and the work tree.
   - Pick the next unblocked task that matches any user-provided selector.
   - For production behavior changes, obtain failing-test evidence or record an explicit waiver before editing production behavior.
   - Do not spawn subagents unless the user explicitly requested a delegation mode.

5. Execute within scope
   - Read relevant code/docs/tests before editing.
   - Make the smallest changes that satisfy the selected task.
   - Update the task ledger as tasks move from `todo` to `in-progress`, `done`, `blocked`, or `accepted-risk`.
   - If a durable requirement, decision, acceptance criterion, or guardrail changes, update the source document as well.

6. Validate
   - Run the source document's validation plan, or the closest project-defined validation for the selected change.
   - Record command, result, summary, and artifacts in the execution state.
   - If validation fails, fix within scope or mark the task blocked with concrete evidence.

7. Persist and report
   - Update `Current State` with status, current/next task, last updated timestamp, branch/commit when relevant, and blocker summary.
   - Append a session log entry with read files, changed files, validation, blockers, and next step.
   - Final response should link the source document and execution state, summarize work done, and state whether execution can continue.

## Execution State Template

```md
# <Topic> Execution State

## Current State

- Status: not-started | in-progress | blocked | validating | complete
- Current task: <task id or short description>
- Next task: <task id or short description>
- Last updated: YYYY-MM-DD HH:mm TZ
- Branch/commit: <optional>
- Source document: `<path>`

## Task Ledger

| ID | Status | Task | Evidence | Notes |
| --- | --- | --- | --- | --- |
| T1 | todo | <task> | <command/path/commit> | <notes> |

## Validation

| Command | Status | Summary | Artifact |
| --- | --- | --- | --- |
| `<command>` | pass/fail/skipped | <summary> | <path> |

## Blockers

- <open question, missing access, failing check, or overlap with unrelated work>

## Session Log

### YYYY-MM-DD HH:mm TZ

- Read:
- Changed:
- Validated:
- Blocked by:
- Next:
```

## Relationship To Nearby Skills

- `discussion-to-implementation-doc`: creates implementation handoffs that can become execution-ready sources.
- `review-to-improvement-doc`: creates improvement records; use this skill after the record has executable backlog and validation gates.
- `create-plan` / `create-dispatch-plan`: create execution-ready plans; use this skill to resume multi-step implementation from those plans.
- `execute-plan-parallel`: use only when the user explicitly wants plan execution through parallel subagents.
- `durable-artifact-cleanup`: use after execution is complete and the source/progress docs are no longer needed as maintained records.
- `handoff-session-prompt`: use when a fresh session prompt is needed; point it at the source document and execution state instead of
  copying the full progress record.
