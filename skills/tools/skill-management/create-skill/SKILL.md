---
name: create-skill
description: Scaffold a new skill directory that passes skill-governance audit and contract validation.
---

# Create Skill

## Contract

Prereqs:

- Run inside a git work tree.
- `bash`, `git`, and `python3` available on `PATH`.

Inputs:

- Target directory via `--skill-dir` (must start with `skills/`).
- Optional metadata:
  - `--title` (defaults to Title Case derived from the directory name)
  - `--description` (defaults to `TBD`)

Outputs:

- A new skill skeleton under `--skill-dir`:
  - `SKILL.md`
  - `scripts/<skill-name>.sh`
  - `tests/test_<skill_path>.py`
- Runs skill-governance validators:
  - `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file <SKILL.md>`
  - `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir <skill-dir>`

Exit codes:

- `0`: created + validated
- `1`: creation or validation failed
- `2`: usage error

Failure modes:

- `--skill-dir` invalid, already exists, or is outside `skills/`.
- Missing prerequisites (`git`, `python3`).
- Generated skeleton fails `skill-governance` validation.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh`
