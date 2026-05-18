# Plan Workflows

This directory contains planning, execution, and cleanup workflows for durable implementation work.

Use these workflows when a task needs more than one conversational turn or when a repo-local artifact should be the source of truth.

## Artifact Roles

- Source doc: durable facts, decisions, findings, requirements, acceptance criteria, and guardrails.
- Plan: execution-control artifact with phases, tasks, dependencies, validation sequencing, and optional PR grouping.
- Execution state: resume ledger for current status, task progress, validation evidence, blockers, and session log.

Keep these roles separate. A source doc should explain why and what; a plan
should sequence how; execution state should record what happened.

## Durable Artifact Workflow

Use durable artifacts when discussion, review, planning, execution, or handoff must survive across sessions:

1. `requirements-gap-scan` when missing requirements would change scope, safety, or done criteria.
2. `discussion-to-implementation-doc` for converged requirements/design discussion that should become implementation-ready context.
3. `review-to-improvement-doc` for review findings, risks, lessons learned, or fix-later backlog.
4. `create-plan` or `create-dispatch-plan` when a primary source artifact needs phases, tasks, ownership lanes, or validation sequencing.
   This is the default bridge from source docs to implementation for multi-step or cross-session work.
5. `execute-from-plan` when a plan should drive long-running execution with an execution-state ledger, or when a source doc is
   explicitly small enough to execute directly with a recorded direct-execution waiver.
6. `handoff-session-prompt` only when a fresh session prompt is needed; point it at the maintained source doc and execution state.
7. `durable-artifact-cleanup` after execution is complete and the coordination docs are obsolete, unreferenced, and safe to delete.

Plan-created source docs live under the same `docs/plans/<slug>/` folder as the
plan that consumes them. Treat the whole folder as one execution bundle unless a
source doc has been promoted. Promote or rewrite source content into domain
docs, runbooks, or HEURISTIC_SYSTEM records only when it has value after
execution.

Prefer deleting obsolete coordination docs after completion and reference checks. Keep or rehome retained evidence, audit material, and
diagnostic artifacts when project policy or future validation needs require them. For HEURISTIC_SYSTEM gaps that remain unfixed after
execution, write or preserve a curated `heuristic-system/error-inbox/` entry before deleting the temporary plan source.

## Workflow Roles

- `create-plan`: create a standard execution-ready implementation plan under `docs/plans/<slug>/`.
- `create-dispatch-plan`: create a dispatch-ready execution model with sprint metadata, sizing scorecards, PR grouping, and subagent review.
- Plan skills require one primary source artifact under `Read First` unless the
  user explicitly asks for a plan-only waiver.
- `discussion-to-implementation-doc` and `review-to-improvement-doc`: create
  plan-source docs under the matching `docs/plans/<slug>/` folder when they exist for execution
  coordination.
- `execute-from-plan`: resume implementation from a plan by default; direct source-doc execution is only for bounded
  single-step work or an explicit waiver recorded in execution state.
- `execute-plan-parallel`: execute a markdown plan through explicitly requested parallel subagents.
- `durable-artifact-cleanup`: audit named durable artifacts or ambiguous cleanup scopes, then remove obsolete coordination docs after
  execution is complete and references are clear.
- `docs-plan-cleanup`: prune broad `docs/plans/` coordination markdown batches with its existing script and report format after keep/delete
  intent is known.

## Cleanup Selection

- Use `durable-artifact-cleanup` for named source docs, plans, execution-state
  docs, handoff prompts, or any case where completion/reference status is
  unclear.
- Use `docs-plan-cleanup` for broad `docs/plans/` hygiene after active plan
  bundles are known. It is the batch executor, not the policy audit.
- If both apply, run `durable-artifact-cleanup` first to classify the scope, then
  use `docs-plan-cleanup` for the `docs/plans/` batch when the report format and
  script safeguards are useful.

## Cleanup Stance

Delete stale coordination docs once they are complete, unreferenced, and no longer needed for resume. This avoids long-lived artifacts
drifting from maintained code and tests.

Do not delete retained evidence, diagnostic artifacts, raw run outputs, or compliance/audit material unless project retention rules and the
user's cleanup request explicitly allow it. Treat HEURISTIC_SYSTEM `error-inbox/` and `operation-records/` entries as maintained records,
not stale coordination docs.
