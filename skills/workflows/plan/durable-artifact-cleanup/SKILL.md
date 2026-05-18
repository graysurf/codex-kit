---
name: durable-artifact-cleanup
description: Audit and remove obsolete durable implementation artifacts after execution is complete.
---

# Durable Artifact Cleanup

Use this skill when source docs, implementation handoffs, improvement records, plans, execution-state docs, or handoff prompts have served
their purpose and should not drift from maintained code.

## Contract

Scope boundary:

- This is the audit and policy workflow for cleanup.
- For broad `docs/plans/` batch deletion, use this skill to classify ambiguous
  scope first, then use `docs-plan-cleanup` as the deterministic batch executor
  when keep/delete intent is known.

Prereqs:

- User explicitly asks to audit, prune, delete, or clean up durable implementation artifacts.
- Target workspace is a git work tree and project rules allow documentation cleanup after required preflight.
- Candidate artifacts are known or discoverable from source document, execution-state document, docs index, issue, PR, or user-provided path.
- Run an audit/dry-run classification before deletion; apply deletion only after the user asks for cleanup or has already authorized it.

Inputs:

- Candidate artifact paths, docs folder, source document, execution-state document, plan path, issue/PR link, or user-described cleanup scope.
- Optional completion evidence such as merged PR, closed issue, `Status: complete`, passing validation, final commit, or accepted-risk note.
- Optional keep/delete preferences, retention rules, docs index path, and validation commands.

Outputs:

- Cleanup report grouping artifacts as `delete`, `keep`, `archive-or-rehome`, and `manual-review`.
- Deleted obsolete durable artifacts only when the audit shows they are complete, unreferenced, and safe to remove.
- Updated docs index or README when removed artifacts were listed there.
- A concise response listing deleted files, retained files, validation, and any unresolved cleanup risks.

Exit codes:

- N/A (conversation/workflow skill)

Failure modes:

- Candidate artifact is still active, blocked, in progress, or lacks clear completion evidence.
- Candidate is still referenced by source docs, plans, issues, PRs, code comments, tests, README/index files, or execution state.
- Artifact contains retained evidence, diagnostic history, raw run output, or compliance/audit material that project policy requires keeping.
- Artifact is a HEURISTIC_SYSTEM error inbox or operation record that is still
  open, promoted, or retained as durable evidence.
- Cleanup scope mixes obsolete durable docs with runtime fixtures, generated outputs, raw logs, or test evidence; split the scope first.
- Deletion would leave dangling links or remove the only source for acceptance, validation, or decision history.

## Workflow

1. Confirm cleanup scope
   - Identify whether the candidates are implementation handoffs, improvement records, plans, execution-state docs, handoff prompts, or
     related evidence.
   - Classify source docs, plans, and execution-state docs as one execution
     bundle when they live together under `docs/plans/<slug>/` and none has been
     promoted into maintained docs.
   - Use this workflow for named artifacts or unclear cleanup status. Use
     `docs-plan-cleanup` for broad `docs/plans/` pruning after active bundles are
     known.
   - Treat deletion as the preferred end state for obsolete durable docs once they are complete and unreferenced.
   - Use archive/rehome only when the project has audit, release, compliance, or historical lookup needs.

2. Verify completion
   - Read candidate docs and their execution state.
   - Confirm `Status: complete`, equivalent task ledger completion, merged/closed issue or PR, or explicit user confirmation.
   - If open questions, blockers, incomplete validation, or active tasks remain, classify the artifact as `keep` or `manual-review`.

3. Scan references
   - Use `rg` over tracked docs/code/tests plus relevant issue/PR links when available.
   - Check docs indexes, README files, `Read First` lists, execution-state links, plan references, and handoff prompts.
   - If a sibling source doc, plan, or execution-state doc still points at the
     candidate, either keep the bundle together or update the maintained
     reference before deletion.
   - Classify candidates still referenced by maintained material as `keep` or `archive-or-rehome` until references are updated.

4. Separate evidence from stale coordination docs
   - Do not delete retained evidence, redacted validation artifacts, diagnostic logs, or raw run outputs unless the user explicitly asks and
     project retention rules allow it.
   - Treat `heuristic-system/error-inbox/` and
     `heuristic-system/operation-records/` as retained evidence
     locations. Keep them unless the entry is closed/promoted and the cleanup
     request explicitly includes it.
   - Do not mix cleanup of durable docs with cleanup of runtime fixtures or generated build/test outputs.
   - If evidence is useful but the coordination doc is stale, keep evidence linked from a maintained location and delete the coordination
     doc.

5. Apply cleanup
   - Delete only artifacts classified as `delete`.
   - For broad `docs/plans/` cleanup, run `docs-plan-cleanup` dry-run/execute
     instead of manually deleting plan bundles.
   - Update docs indexes, README files, and source documents so links do not dangle.
   - If deletion creates empty docs folders, remove them only when project rules allow it.
   - Keep changes scoped to cleanup; do not refactor the docs tree unless asked.

6. Validate and report
   - Run the smallest project-appropriate docs checks, usually markdown lint, docs freshness, and link/reference checks.
   - Report deleted paths, retained paths, updated indexes, validation commands, and any manual-review items.
   - If validation fails, stop and report the failing command instead of claiming cleanup complete.

## Relationship To Nearby Skills

- `discussion-to-implementation-doc`: creates implementation handoffs that may later become cleanup candidates.
- `review-to-improvement-doc`: creates improvement records; delete them only after fixes are complete and evidence is retained elsewhere when
  needed.
- `execute-from-plan`: updates execution state; use this cleanup skill after execution status is complete and no future resume
  is needed.
- `docs-plan-cleanup`: deterministic batch executor for broad `docs/plans/` coordination-doc pruning with its existing report format. Use
  it after this workflow when cleanup scope needs policy classification first.
- `handoff-session-prompt`: prompt artifacts should usually be deleted once source docs and execution state are the maintained record.
