# Skill-Dev Workflow

## Scope

- Canonical required workflow for `skill-dev` context.
- Applies to skill creation, updates, governance checks, and skill script validation.

## Entry commands

1. `agent-docs resolve --context startup --strict --format checklist`
2. `agent-docs resolve --context skill-dev --strict --format checklist`
3. `agent-docs resolve --context task-tools --format checklist` (optional, when external tool/document lookup is needed)
4. `agent-docs baseline --check --target all --strict --format text` (only when strict resolve fails)

## Deterministic flow

1. Resolve `startup` in strict mode before any skill preflight.
2. Resolve `skill-dev` in strict mode before touching `skills/**`.
3. Follow skill contract format and repository skill governance rules.
4. Validate skill contract/layout/tests before reporting completion.
5. Keep changes scoped to intended skill paths and referenced assets/scripts.

## Failure handling

- `startup` strict resolve fails:
  - Block skill file edits.
  - Run strict baseline check and report missing docs.
  - Resume only after required docs are present.
- `skill-dev` strict resolve fails:
  - Block skill file edits.
  - Run strict baseline check and report missing docs.
  - Resume only after required docs are present.
- Skill governance/test validation fails:
  - Report failing command and key output.
  - Do not claim skill task completion.

## Validation checklist

- [ ] `agent-docs resolve --context startup --strict --format checklist` exits 0 before skill edits.
- [ ] `agent-docs resolve --context skill-dev --strict --format checklist` exits 0 before skill edits.
- [ ] Skill contract validation and required checks are executed.
- [ ] Validation failures are surfaced with command-level details.
