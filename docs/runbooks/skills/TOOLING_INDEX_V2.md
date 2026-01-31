# Skills Tooling Index v2

This doc lists canonical executable entrypoints (under `skills/**/scripts/` and `commands/`).

## SKILL.md format

- SKILL.md format spec:
  - `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`

## Skill governance

- Validate SKILL.md contract format:
  - `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Audit tracked skill directory layout:
  - `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- Validate runnable path rules in SKILL.md:
  - `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_paths.sh`

## Skill management

- Create a new skill skeleton (validated):
  - `$CODEX_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh`
- Remove a skill and purge references (breaking change):
  - `$CODEX_HOME/skills/tools/skill-management/remove-skill/scripts/remove_skill.sh`

## Plan tooling (Plan Format v1)

- Scaffold a new plan file:
  - `$CODEX_COMMANDS_PATH/plan-tooling scaffold`
- Lint plans:
  - `$CODEX_COMMANDS_PATH/plan-tooling validate`
- Parse plan → JSON:
  - `$CODEX_COMMANDS_PATH/plan-tooling to-json`
- Compute dependency batches:
  - `$CODEX_COMMANDS_PATH/plan-tooling batches`

## Progress tooling (Progress PR workflow)

- Create a new progress file skeleton:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-tooling/scripts/create_progress_file.sh`
- Validate progress index formatting:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-tooling/scripts/validate_progress_index.sh`
- Render progress PR templates:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-tooling/scripts/render_progress_pr.sh`

## Progress PR workflow (real GitHub E2E driver)

- `$CODEX_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
