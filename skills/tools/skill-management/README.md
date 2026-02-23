# Skill management tools

This folder groups tools for maintaining the `skills/` tree (create/validate/remove).

## Quick start

- Create a new skill skeleton (writes files, then validates):
  - `$AGENT_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh --skill-dir skills/<category>/<area>/<skill-name>`
- Create a new project-local skill skeleton under `.agents/skills/`:
  - `$AGENT_HOME/skills/tools/skill-management/create-project-skill/scripts/create_project_skill.sh --project-path <repo-root> --skill-dir .agents/skills/<skill-name>`
- Validate contract headings (all tracked skills):
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Audit tracked skill layout:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- Audit a not-yet-tracked skill directory:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/<...>/<skill-name>`
- Remove a skill (breaking change; start with `--dry-run`):
  - `$AGENT_HOME/skills/tools/skill-management/remove-skill/scripts/remove_skill.sh --skill-dir skills/<...>/<skill-name> --dry-run`

## Tools

- `skill-governance`
  - Canonical validators for skill contracts and layout.
  - Use `--skill-dir` when validating a newly scaffolded skill before `git add`.
- `create-skill`
  - Scaffolds: `SKILL.md` + `scripts/<skill>.sh` + `tests/` (minimum) and runs the governance validators.
  - Updates root `README.md` skill catalog for public domains (`workflows`, `tools`, `automation`).
  - Does not stage/commit; you still need to fill in the real Contract + implementation.
- `create-project-skill`
  - Scaffolds project-local skills under `<project>/.agents/skills/` with contract + layout checks.
  - Supports shorthand `--skill-dir <skill-name>` -> `.agents/skills/<skill-name>`.
  - Does not stage/commit; you still need to fill in the real Contract + implementation.
- `remove-skill`
  - Deletes the skill directory and purges repo references (breaking change).

## Conventions

- Skill paths: `skills/<category>/<area>/<skill-name>` (kebab-case directory names).
- Entry points live under `skills/**/scripts/` and must support `--help` with exit code `0` (required by repo script regression tests).
- Shared, non-entrypoint code/assets:
  - Prefer category-level `_shared/` (e.g. `skills/tools/<area>/_shared/`) or global `skills/_shared/`.
  - `_shared/` must not contain `SKILL.md`, `scripts/`, or `tests/`.
