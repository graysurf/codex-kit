# New Project Bootstrap (agent-docs)

## Scope

- Canonical bootstrap sequence for repositories that do not yet satisfy baseline policy docs.
- Keep this flow as the single startup bootstrap path referenced by `AGENTS.md`.

## Canonical command path

- `$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh`

## Bootstrap sequence

1. Preview changes (default dry-run):

```bash
$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh \
  --dry-run \
  --project-path "$PROJECT_PATH"
```

2. Apply missing baseline docs (safe default: missing-only scaffold):

```bash
$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh \
  --apply \
  --project-path "$PROJECT_PATH"
```

3. Verify strict baseline coverage:

```bash
agent-docs baseline --check --target all --strict --project-path "$PROJECT_PATH" --format text
```

4. Continue with normal preflight resolves:

```bash
agent-docs resolve --context startup --strict --format checklist
agent-docs resolve --context project-dev --strict --format checklist
agent-docs resolve --context task-tools --strict --format checklist
agent-docs resolve --context skill-dev --strict --format checklist
```

## Optional project extension registration

If the project needs extra required docs beyond built-ins, add entries during apply mode:

```bash
$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh \
  --apply \
  --project-path "$PROJECT_PATH" \
  --project-required "project-dev:BINARY_DEPENDENCIES.md:External runtime tools"
```
