# Startup Workflow

## Scope

- Canonical required workflow for `startup` context.
- Defines session preflight behavior before any task execution.

## Entry commands

1. `agent-docs resolve --context startup --strict --format checklist`
2. `agent-docs baseline --check --target all --strict --format text` (only when strict resolve fails)

## Deterministic flow

1. Resolve `startup` in strict mode at session start/resume.
2. Confirm required startup docs are present before any task action.
3. If startup strict pass, continue to intent-specific context preflight (`task-tools`, `project-dev`, or `skill-dev`).

## Failure handling

- `startup` strict resolve fails:
  - Run strict baseline check to enumerate missing required docs.
  - For new repositories, run bootstrap: `$CODEX_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh --apply --project-path "$PROJECT_PATH"` (see `docs/runbooks/agent-docs/new-project-bootstrap.md`).
  - Block normal task execution.
  - Allow read-only diagnostics only.
  - Report missing files and required remediation.
- Baseline check fails due schema/config errors:
  - Stop execution and report config error details.

## Validation checklist

- [ ] `agent-docs resolve --context startup --strict --format checklist` exits 0 before task work.
- [ ] On failure, strict baseline check is executed and reported.
- [ ] No task edits/commands run before startup preflight passes.
