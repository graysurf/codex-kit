---
name: skill-governance
description: Audit skill layout and validate SKILL.md contracts.
---

# Skill Governance

## Contract

Prereqs:

- Run inside a git work tree.
- `bash` available on `PATH`.
- `git` available on `PATH`.
- `python3` available on `PATH`.

Inputs:

- `audit-skill-layout.sh`: no args (optional `--help`).
- `validate_skill_contracts.sh`: optional `--file <path>` (repeatable).
- `validate_skill_paths.sh`: optional `--help` (placeholder until v2 enforcement).

Outputs:

- Validation results on stdout/stderr.
- Exit status indicating pass/fail.

Exit codes:

- `0`: all checks pass
- `1`: validation errors or missing prerequisites
- `2`: usage error (unsupported flags)

Failure modes:

- Not running inside a git repo.
- Missing `git` or `python3`.
- Skill layout violates allowed top-level entries.
- `SKILL.md` missing required `## Contract` headings.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/audit-skill-layout.sh`
- `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh`
- `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_paths.sh`

## Compatibility

Legacy wrappers remain available under `$CODEX_HOME/scripts/`.
