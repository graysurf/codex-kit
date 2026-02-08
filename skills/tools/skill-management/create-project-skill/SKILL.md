---
name: create-project-skill
description: Scaffold a project-local skill under .codex/skills with contract and layout validation.
---

# Create Project Skill

## Contract

Prereqs:

- Run inside a git work tree.
- `bash`, `git`, and `python3` available on `PATH`.
- Target project path is a git work tree where `.codex/skills/` can be created.

Inputs:

- Required:
  - `--skill-dir <.codex/skills/...|<skill-name>>`
- Optional:
  - `--project-path <path>` (defaults to current directory)
  - `--title "<Title>"` (defaults to Title Case from skill name)
  - `--description "<text>"` (defaults to `TBD`)

Outputs:

- Creates a project-local skill skeleton at `<project>/.codex/skills/...`:
  - `SKILL.md`
  - `scripts/<skill-name>.sh`
  - `tests/test_<skill_path>.sh`
- Validates generated contract headings using:
  - `$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file <SKILL.md>`
- Validates project-skill layout using an internal local validator.

Exit codes:

- `0`: created + validated
- `1`: creation or validation failed
- `2`: usage error

Failure modes:

- `--skill-dir` missing/invalid or outside `.codex/skills/`.
- Target project path missing, not a directory, or not a git work tree.
- Target skill directory already exists.
- Missing prerequisites (`git`, `python3`) or missing template/validator files.
- Generated skeleton fails contract or layout validation.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/tools/skill-management/create-project-skill/scripts/create_project_skill.sh`

## Workflow

1. Resolve the target project root (default current directory) and verify it is a git work tree.
2. Normalize `--skill-dir` to `.codex/skills/...` (supports shorthand `<skill-name>`).
3. Scaffold `SKILL.md`, a scripts entrypoint, and a tests smoke stub.
4. Run contract validation and local project-skill layout validation.
5. Return success output with the created project-skill path.
