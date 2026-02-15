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
- Root `README.md` updated with a new skill catalog row (for public domains: `workflows`, `tools`, `automation`).
- Runs skill-governance validators:
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file <SKILL.md>`
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir <skill-dir>`

Exit codes:

- `0`: created + validated
- `1`: creation or validation failed
- `2`: usage error

Failure modes:

- `--skill-dir` invalid, already exists, or is outside `skills/`.
- Missing prerequisites (`git`, `python3`).
- Generated skeleton fails `skill-governance` validation.
- `README.md` update fails because required section/table structure is missing or malformed.

## Scripts (only entrypoints)

- `$AGENTS_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh`
