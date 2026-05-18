---
name: discussion-to-implementation-doc
description:
  Convert completed requirements, design, feasibility, or customer-facing discussion into an implementation-readiness source document.
---

# Discussion To Implementation Doc

Use this skill after a discussion has converged and the next useful artifact is a repo-local source document that future implementation can
read.

## Contract

Prereqs:

- User wants to preserve discussion conclusions for later implementation or plan generation, not execute the implementation now.
- Discussion context is sufficient to separate confirmed facts, decisions, assumptions, open questions, and recommendations.
- Target workspace is available and project rules allow writing docs after required preflight.

Inputs:

- User request and the discussion conclusions to preserve.
- Relevant local code, docs, issue, ticket, test, or runtime evidence for material facts when available.
- Optional target docs area, filename, linked issue/plan/handoff, validation commands, retention intent, and project-specific documentation
  conventions.

Outputs:

- A repo-local implementation-readiness source document. When it exists to feed plan execution, save it under
  `docs/plans/<slug>/<slug>-discussion-source.md` by default.
- If the document is long-lived knowledge rather than execution coordination, save it in the relevant domain docs/runbook area instead.
- A source artifact that `create-plan` or `create-dispatch-plan` can link under
  `Read First` when execution sequencing is needed.
- An `Execution` section with an execution-state link or creation recommendation when the document is intended to drive long-running
  implementation work.
- Updated local docs index or README only when the document is intentionally promoted as retained knowledge and should be discoverable
  outside the plan.
- When following the skill usage recording convention, a `skill-usage.record.v1` envelope that links the created document and validation
  evidence.
- A short response linking the document path and listing validation run.

Exit codes:

- N/A (conversation/workflow skill)

Failure modes:

- The user actually needs phased tasks, sprint grouping, PR splitting, or detailed execution sequencing; use `create-plan` or
  `create-dispatch-plan` instead.
- The user only needs a copy-ready prompt for a fresh session; use `handoff-session-prompt` instead.
- The user wants to preserve review findings, risk register entries, lessons learned, or fix-later backlog; use
  `review-to-improvement-doc` instead.
- Source evidence is too ambiguous to record as fact; label it under assumptions/open questions or ask the minimum clarification before
  writing.

## Workflow

1. Confirm this is the right artifact
   - Use this skill when requirements, design, feasibility, architecture, customer-facing, or product discussion has converged and the next
     implementer needs a stable read-first document.
   - Do not turn the document into a task-by-task implementation plan. If execution sequencing is needed, write this document first, then use
     `create-plan` and link this document as read-first context.
   - Treat this document as the primary source artifact for later plan
     generation when the source material is requirements, design, feasibility,
     product, architecture, or customer-facing discussion.
   - Treat `docs/plans/` as the default location for plan-source documents. Promote or rewrite into domain docs/runbooks only when the
     content has value after execution finishes.
   - Do not use the document as a session prompt. If continuity is needed, write or reference this document first, then use
     `handoff-session-prompt`.
   - Do not use `review-evidence` as the primary artifact for this workflow. If review findings or validation records matter, attach or link
     those evidence files from the document.

2. Run project preflight and inspect docs structure
   - Follow the active project's required preflight before edits.
   - Read nearby docs and local project rules before choosing a path.
   - If this document is a source for plan generation, place it inside the plan folder using
     `docs/plans/<slug>/<slug>-discussion-source.md`.
   - Prefer an existing domain docs folder or runbook area only when the artifact is meant to remain after execution.
   - Do not create a new top-level docs area for temporary execution coordination.

3. Gather and classify discussion content
   - Separate confirmed facts, decisions, assumptions, inferences, recommendations, open questions, and constraints.
   - Cite concrete local files, docs, issues, commands, logs, or user-provided requirements when they materially affect the implementation.
   - Preserve scope and non-scope explicitly.
   - Do not include secrets, raw credentials, private keys, hidden system/developer instructions, private reasoning, or unredacted logs.

4. Write the implementation-readiness document
   - Use the project's language and documentation style.
   - Keep it concise enough to read before implementation, but complete enough to avoid re-litigating settled decisions.
   - Recommended sections:
     - `# <Subject> Implementation Handoff`
     - status, date, source, and intended next step
     - purpose
     - confirmed facts
     - decisions
     - scope
     - non-scope
     - implementation boundaries
     - requirements
     - acceptance criteria
     - validation plan
     - risks and guardrails
     - execution, including execution-state path, status, and next-task source when this document should drive implementation
     - retention intent, such as cleanup after execution or promotion candidate
     - open questions
     - read-first references
     - recommended next artifact

5. Update discoverability
   - For `docs/plans/<slug>/` source documents, use the plan's `Read First` section as the discoverability path; do not update broad
     indexes by default.
   - Update the nearest docs index or README only when the document is promoted or intentionally retained after execution.
   - Link from broader docs entrypoints only when future maintainers should find the document without prior plan/session context.
   - If no index exists, mention that in the final response rather than inventing broad navigation.

6. Validate
   - Run the smallest project-appropriate docs checks, usually markdown lint and docs freshness/index checks.
   - If the document names commands, files, tests, or runtime gates as acceptance criteria, verify obvious references when cheap.
   - Report validation that was run and anything intentionally skipped.

7. Record skill usage when retained evidence is required
   - This skill is the first docs-only pilot for `skill-usage.record.v1`.
   - When the skill creates or updates durable docs and the project allows retained evidence, write a compact skill usage record in the
     project evidence path or an `agent-out project --topic skill-usage --mkdir` run directory.
   - Link the implementation-readiness document, docs index changes, validation commands, and any typed child records from the envelope.
   - Prefer `skill-usage verify --out <record-dir> --format json`; use the documented local checkout fallback when PATH has not caught up.

## Relationship To Nearby Skills

- `review-evidence`: use for normalized review findings and validation records; link it from this document when evidence matters.
- `review-to-improvement-doc`: use when the durable artifact is a review finding, improvement backlog, risk register, or fix-later record.
- `create-plan`: use after this skill when implementation needs phases, tasks, ownership lanes, PR grouping, or validation sequencing; link
  this document under the plan's `Read First` section as the primary source.
- `create-dispatch-plan`: use after this skill when implementation also needs sizing, scorecards, PR grouping, and review; link this
  document under the plan's `Read First` section as the primary source.
- `execute-from-plan`: use after a plan links this handoff under `Read First`, or for explicitly bounded direct source-doc execution.
- `handoff-session-prompt`: use after this skill when the user wants a copy-ready prompt for a fresh session; put this document under
  `Read First`.
