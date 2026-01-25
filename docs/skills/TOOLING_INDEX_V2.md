# Skills Tooling Index v2

This doc lists canonical executable entrypoints that live under `skills/**/scripts/`.

## Skill governance

- Validate SKILL.md contract format:
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh`
- Audit tracked skill directory layout:
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`
- Validate runnable path rules in SKILL.md:
  - `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_paths.sh`

## Plan tooling (Plan Format v1)

- Lint plans:
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh`
- Parse plan → JSON:
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh`
- Compute dependency batches:
  - `$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh`

## Progress PR workflow (real GitHub E2E driver)

- `$CODEX_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
