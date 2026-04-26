# Task-Tools Research Workflow

## Scope

- Canonical required workflow for `task-tools` context.
- Keep technical lookup policy outside `AGENTS.md`, referenced via `AGENT_DOCS.toml`.
- Use the lightest source that can answer the question with traceable evidence; do not force a single lookup sequence for every task.

## Entry commands

1. `agent-docs --docs-home "$AGENT_HOME" resolve --context startup --strict --format checklist`
2. `agent-docs --docs-home "$AGENT_HOME" resolve --context task-tools --strict --format checklist`
3. `agent-docs --docs-home "$AGENT_HOME" baseline --check --target all --strict --format text` (only when strict resolve fails)

## Decision framework

1. Resolve `startup` in strict mode before any research preflight.
2. Resolve `task-tools` in strict mode before research recommendations.
3. Classify the research target before choosing tools:
   - Official library/framework docs or API usage guidance -> `Context7`
   - Rendered docs/live pages for exploratory navigation, quick extraction, or interactive probing -> Web via `$agent-browser` skill (`$AGENT_HOME/skills/tools/browser/agent-browser/scripts/agent-browser.sh`)
   - Rendered docs/live pages requiring deterministic replay, traceable artifacts, or scripted verification -> Web via `$playwright` skill (`$AGENT_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh`)
   - GitHub metadata, PRs/issues/releases, default branch, README/docs, or a small number of repository files -> `gh`
   - Cross-file implementation tracing, local execution, build/test validation, or patches against repository code -> local checkout/clone
4. Choose the most direct source for the classified target.
   Do not require `Context7 -> Web -> gh -> clone` when the earlier source
   types are not relevant.
5. When jumping directly to a heavier source, especially a new local clone of
   an external repository, state why lighter-weight sources are insufficient.
6. For a new temporary clone of an external repository, ask first unless the
   user explicitly requested a clone or local execution is clearly required.
7. Keep evidence traceable: include concrete doc/source references for external claims.
8. If fallback/degraded mode is used, label assumptions explicitly.

## Source selection rules

- Prefer `Context7` when the main question is "what does the official library/framework documentation say?"
- Prefer Web/agent-browser when the research step is exploratory and benefits from fast `snapshot`/`@ref` interaction.
- Prefer Web/Playwright when browser findings need deterministic replay, explicit step logs, or artifact-oriented verification.
- Prefer `gh` when GitHub-hosted facts are enough and a full checkout would add cost without improving confidence.
- Prefer a local checkout when repository implementation details, broad text search, or command execution are central to the task.
- For the current workspace repository, direct local inspection is allowed
  when the task is implementation-facing and the needed evidence is already on
  disk.

### Browser decision table (`agent-browser` vs `playwright`)

| Research situation | Preferred tool | Why |
| --- | --- | --- |
| Early-page exploration, quick UI probing, element discovery (`snapshot -i` + `@ref`) | `agent-browser` | Faster interaction loop and lower overhead for exploratory work |
| Need to capture deterministic replay evidence (repeatable step flow with explicit command history) | `playwright` | Better fit for reproducible, verification-oriented browser checks |
| One-off content extraction where strict replay is not required | `agent-browser` | Lightweight and direct for ad hoc extraction |
| Browser findings that will be handed off as verification artifacts for implementation follow-up | `playwright` | Aligns better with artifact-driven validation and follow-up checks |
| Browser CLI unavailable (`npx` missing / bootstrap blocked) | Next best non-browser source | Continue with traceable evidence and disclose browser-validation gap |

## Failure handling

- `startup` strict resolve fails:
  - Run strict baseline check for all scopes.
  - Stop execution and report missing required docs.
- `task-tools` strict resolve fails:
  - Run strict baseline check for all scopes.
  - Continue in non-strict mode only when at least one required document is usable.
  - If no usable required docs remain, stop and report missing files.
- `command -v npx` fails and browser validation is needed:
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
- [ ] When Web source is selected, the choice between `agent-browser` and `playwright` is justified.
- [ ] Any new external clone is justified, and approval is requested when required.
- [ ] At least one concrete source reference is included in findings.
- [ ] Any fallback/degraded behavior is disclosed.
