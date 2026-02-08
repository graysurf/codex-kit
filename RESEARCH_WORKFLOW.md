# Task-Tools Research Workflow

## Scope

- Canonical required workflow for `task-tools` context.
- Keep technical lookup policy outside `AGENTS.md`, referenced via `AGENT_DOCS.toml`.

## Entry commands

1. `agent-docs resolve --context startup --strict --format checklist`
2. `agent-docs resolve --context task-tools --strict --format checklist`
3. `agent-docs baseline --check --target all --strict --format text` (only when strict resolve fails)

## Deterministic flow

1. Resolve `startup` in strict mode before any research preflight.
2. Resolve `task-tools` in strict mode before research recommendations.
3. Use source order exactly:
   1. Context7
   2. Web via `$playwright` skill (`$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh`)
   3. GitHub source via `gh`
   4. Local clone (ask first unless user already requested clone)
4. Keep evidence traceable: include concrete doc/source references for external claims.
5. If fallback/degraded mode is used, label assumptions explicitly.

## Failure handling

- `startup` strict resolve fails:
  - Run strict baseline check for all scopes.
  - Stop execution and report missing required docs.
- `task-tools` strict resolve fails:
  - Run strict baseline check for all scopes.
  - Continue in non-strict mode only when at least one required document is usable.
  - If no usable required docs remain, stop and report missing files.
- `command -v npx` fails:
  - Skip Playwright path and continue with Context7 plus `gh`.
  - Mark web validation gap in output.
- Context7/web/`gh` source access fails:
  - Continue to the next source in order.
  - Report skipped source and error class.
- Clone is needed but not approved/requested:
  - Stop at available evidence and state limitation.

## Validation checklist

- [ ] `agent-docs resolve --context startup --strict --format checklist` exits 0 before research work.
- [ ] `agent-docs resolve --context task-tools --strict --format checklist` exits 0 before research work.
- [ ] Source order is preserved: Context7 -> Web -> `gh` -> clone.
- [ ] At least one concrete source reference is included in findings.
- [ ] Any fallback/degraded behavior is disclosed.
