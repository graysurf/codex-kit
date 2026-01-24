# Skills Migration Map v2

Status: Draft

## Wrapper policy

- Canonical entrypoints live under `skills/` and use `$CODEX_HOME/...` paths.
- Legacy entrypoints under `scripts/` (or `scripts/e2e/`) remain as thin wrappers.
- Wrappers delegate to canonical scripts without behavior changes.
- Deprecation timing will be announced separately; no removals in v2 baseline.

## Script migration map

| Old path | New canonical path | Wrapper policy |
| --- | --- | --- |
| `scripts/validate_skill_contracts.sh` | `skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh` | Keep wrapper in `scripts/` |
| `scripts/audit-skill-layout.sh` | `skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh` | Keep wrapper in `scripts/` |
| `scripts/validate_plans.sh` | `skills/workflows/plan/plan-tooling/scripts/validate_plans.sh` | Keep wrapper in `scripts/` |
| `scripts/plan_to_json.sh` | `skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh` | Keep wrapper in `scripts/` |
| `scripts/plan_batches.sh` | `skills/workflows/plan/plan-tooling/scripts/plan_batches.sh` | Keep wrapper in `scripts/` |
| `scripts/e2e/progress_pr_workflow.sh` | `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh` | Keep wrapper in `scripts/e2e/` |

## Shared reuse guidance

- Prefer category/area `_shared/` for assets reused within a single area.
- Use `skills/_shared/` only for cross-category reuse.
- Keep entrypoints in per-skill `scripts/`; shared folders must not contain `scripts/`.

## Notes

- Documentation should reference canonical `$CODEX_HOME/...` paths.
- Wrapper paths remain valid for backward compatibility and existing automation.
