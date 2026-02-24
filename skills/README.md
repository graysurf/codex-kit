# skills/

This directory contains Codex CLI skills tracked by this repo. A "skill" is a self-contained set of runnable instructions plus any scripts, helpers, tests, and references needed to keep it reliable.

## Canonical docs

- Skill directory anatomy and path rules (canonical):
  - `../docs/runbooks/skills/SKILLS_ANATOMY_V2.md`
- SKILL.md contract format spec:
  - `../docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`
- Executable entrypoint catalog:
  - `../docs/runbooks/skills/TOOLING_INDEX_V2.md`
- Create/validate/remove workflows:
  - `tools/skill-management/README.md`

## Tracked skill categories

Tracked skills live under:

- `skills/workflows/`
- `skills/tools/`
- `skills/automation/`

Non-tracked directories are best-effort only:

- `skills/_projects/`
- `skills/.system/`

## Quick rules (summary)

- Executable entrypoints in `SKILL.md` must use absolute `$AGENT_HOME/...` paths.
- Repo-relative links are allowed for non-executable references.
- `scripts/` is for entrypoints only; shared code belongs in `lib/` or `_shared/`.
- `tests/` is required for tracked skills (smoke coverage is acceptable).
- `_shared/` directories are reusable support trees and must not contain `SKILL.md`, `scripts/`, or `tests/`.

Example entrypoint path:

```bash
$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh
```

See `../docs/runbooks/skills/SKILLS_ANATOMY_V2.md` for the full directory anatomy table, shared-directory rules, and examples.

## Naming and layout conventions

- Skill directories use kebab-case (e.g., `create-feature-pr`).
- `_shared` is reserved for shared, non-skill content only.
- Avoid uppercase or spaces in directory names.
