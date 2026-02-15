---
name: remove-skill
description: Remove a tracked skill directory and purge non-archived repo references (breaking change).
---

# Remove Skill

## Contract

Prereqs:

- Run inside a git work tree.
- `bash`, `git`, `python3`, and `rg` available on `PATH`.
- You understand this is a breaking change (no compatibility shims are created).

Inputs:

- Target directory via `--skill-dir` (must start with `skills/`).
- Safety flags:
  - `--dry-run` to print planned changes without writing.
  - `--yes` to skip the interactive confirmation prompt.

Outputs:

- Deletes the skill directory under `--skill-dir` (tracked + untracked files).
- Deletes any matching script-spec files under `tests/script_specs/**` for scripts in that skill.
- Removes references in tracked Markdown files (excluding `docs/progress/archived/**`).
- Fails if any remaining references are found outside `docs/progress/archived/**`.

Exit codes:

- `0`: removed + no remaining references
- `1`: deletion failed or references remain
- `2`: usage error

Failure modes:

- `--skill-dir` invalid or missing `SKILL.md`.
- Remaining references in non-Markdown tracked files (must be fixed manually).
- Attempting to remove references from `docs/progress/archived/**` (explicitly skipped).

## Scripts (only entrypoints)

- `$AGENTS_HOME/skills/tools/skill-management/remove-skill/scripts/remove_skill.sh`
