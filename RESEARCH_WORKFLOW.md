# Task-Tools Research Workflow

## Scope

- Canonical required workflow for `task-tools` context.
- Keep technical lookup policy outside `AGENTS.md`, referenced via `AGENT_DOCS.toml`.
- Use the lightest authoritative source that can answer the question with traceable evidence.
- Prefer native Codex tools, MCP/app connectors, and project-local evidence before shell or browser CLI wrappers.

## Entry commands

1. `agent-docs --docs-home "$AGENT_HOME" resolve --context startup --strict --format checklist`
2. `agent-docs --docs-home "$AGENT_HOME" resolve --context task-tools --strict --format checklist`
3. `agent-docs --docs-home "$AGENT_HOME" baseline --check --target all --strict --format text` (only when strict resolve fails)

## Decision framework

1. Resolve `startup` in strict mode before any research preflight.
2. Resolve `task-tools` in strict mode before research recommendations.
3. Classify the research target before choosing tools:
   - Current workspace behavior or implementation-facing evidence -> local inspection and command execution.
   - Official product/API docs with a dedicated skill, connector, or MCP docs tool -> that dedicated entrypoint.
   - Official library/framework docs with useful `Context7` coverage -> `Context7`; otherwise use official web docs.
   - Time-sensitive facts, public web pages, announcements, policies, prices, releases, or citations -> authoritative web sources.
   - GitHub metadata, PRs/issues/releases, default branch, README/docs, or a small number of repository files -> `gh`.
   - Rendered-page behavior, UI state, or browser-visible evidence -> native/browser tools first; CLI wrappers only when their
     artifact or replay model is needed.
   - Cross-file implementation tracing, external repo execution, or broad source search -> local checkout/clone.
4. Choose the most direct source for the classified target.
   Do not require `Context7 -> Web -> gh -> clone` when the earlier source types are not relevant.
5. Use browser CLI wrappers for their specific strengths, not as the default web lookup path:
   - `agent-browser`: CLI-driven exploratory probing, `snapshot -i`, and `@ref` interaction loops.
   - `playwright`: deterministic replay, explicit step logs, and artifact-oriented verification.
6. When jumping directly to a heavier source, especially a new local clone of
   an external repository, state why lighter-weight sources are insufficient.
7. For a new temporary clone of an external repository, ask first unless the
   user explicitly requested a clone or local execution is clearly required.
8. Keep evidence traceable: include concrete doc/source references for external claims.
9. If fallback/degraded mode is used, label assumptions explicitly.

## Source selection rules

- Prefer local inspection for current-workspace implementation questions when the evidence is already on disk.
- Prefer dedicated skills, MCP docs tools, or app connectors when they exist for the target product or service.
- Prefer official web sources for unstable or time-sensitive claims, and cite concrete source references.
- Prefer `Context7` when the main question is "what does the official library/framework documentation say?" and coverage is current enough.
- Prefer `gh` when GitHub-hosted facts are enough and a full checkout would add cost without improving confidence.
- Prefer native/browser tooling for rendered pages before browser CLI wrappers.
- Prefer `agent-browser` when the browser step specifically benefits from fast CLI `snapshot -i` and `@ref` interaction.
- Prefer `playwright` when browser findings need deterministic replay, explicit step logs, or artifact-oriented verification.
- Prefer a local checkout when repository implementation details, broad text search, or command execution are central to the task.

### Browser CLI wrapper decision table

| Research situation | Preferred tool | Why |
| --- | --- | --- |
| Early-page exploration where a CLI loop is useful (`snapshot -i` + `@ref`) | `agent-browser` | Fast element discovery and lower overhead for ad hoc CLI probing |
| Need to capture deterministic replay evidence (repeatable step flow with explicit command history) | `playwright` | Better fit for reproducible, verification-oriented browser checks |
| One-off public content lookup where rendered interaction is not required | Native web/search source | Avoids unnecessary browser automation overhead |
| Browser findings that will be handed off as verification artifacts for implementation follow-up | `playwright` | Aligns better with artifact-driven validation and follow-up checks |
| Browser CLI unavailable (`npx` missing / bootstrap blocked) | Native/browser source or next best evidence source | Continue with traceable evidence and disclose any validation gap |

## Failure handling

- `startup` strict resolve fails:
  - Run strict baseline check for all scopes.
  - Stop execution and report missing required docs.
- `task-tools` strict resolve fails:
  - Run strict baseline check for all scopes.
  - Continue in non-strict mode only when at least one required document is usable.
  - If no usable required docs remain, stop and report missing files.
- A selected browser CLI wrapper needs `npx`, but `command -v npx` fails:
  - Skip browser CLI tools (`agent-browser`, `playwright`) and use the next best evidence source.
  - Mark the browser-validation gap in output.
- A preferred source is unavailable:
  - Move to the next best source for that research target.
  - Report the skipped source and the reason.
- A new external clone would be the next best source but is not approved/requested:
  - Stop at the best available evidence and state the limitation.

## Validation checklist

- [ ] `agent-docs --docs-home "$AGENT_HOME" resolve --context startup --strict --format checklist` exits 0 before research work.
- [ ] `agent-docs --docs-home "$AGENT_HOME" resolve --context task-tools --strict --format checklist` exits 0 before research work.
- [ ] The research target is classified before source selection.
- [ ] The chosen source matches the target category, or any deviation is explained.
- [ ] When a browser source is selected, native/browser tooling vs CLI wrapper choice is justified when it affects evidence.
- [ ] Any new external clone is justified, and approval is requested when required.
- [ ] At least one concrete source reference is included in findings.
- [ ] Any fallback/degraded behavior is disclosed.
