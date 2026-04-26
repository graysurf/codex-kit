# New Project Bootstrap (agent-docs)

## Scope

- Canonical bootstrap sequence for repositories that do not yet satisfy baseline policy docs.
- Keep this flow as the single startup bootstrap path referenced by `AGENTS.md`.

## Canonical command path

- `$AGENT_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh`

## Bootstrap sequence

1. Preview changes (default dry-run):

```bash
$AGENT_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh \
  --dry-run \
  --project-path "$PROJECT_PATH"
```

1. Apply missing baseline docs (safe default: missing-only scaffold):

```bash
$AGENT_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh \
  --apply \
  --project-path "$PROJECT_PATH"
```

1. Verify strict baseline coverage:

```bash
agent-docs --docs-home "$AGENT_HOME" baseline --check --target all --strict --project-path "$PROJECT_PATH" --format text
```

1. Continue with normal preflight resolves:

```bash
agent-docs --docs-home "$AGENT_HOME" resolve --context startup --strict --format checklist
agent-docs --docs-home "$AGENT_HOME" resolve --context project-dev --strict --format checklist
agent-docs --docs-home "$AGENT_HOME" resolve --context task-tools --strict --format checklist
agent-docs --docs-home "$AGENT_HOME" resolve --context skill-dev --strict --format checklist
```

## Optional project extension registration

If the project needs extra required docs beyond built-ins, add entries during apply mode:

```bash
$AGENT_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh \
  --apply \
  --project-path "$PROJECT_PATH" \
  --project-required "project-dev:BINARY_DEPENDENCIES.md:External runtime tools"
```
