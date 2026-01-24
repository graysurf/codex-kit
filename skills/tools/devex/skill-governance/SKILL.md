---
name: skill-governance
description: Enforce codex-kit skill conventions (contract, layout, and SKILL.md path audits) via deterministic scripts.
---

# Skill Governance

## Contract

Prereqs:

- Run inside the codex-kit git repo.
- `git` and `python3` available on `PATH`.

Inputs:

- Optional `--file` arguments for validating specific `skills/**/SKILL.md` files.

Outputs:

- Audit results printed as `error:` lines to stderr on failure.
- Exit code `0` on success; non-zero on violations or usage errors.

Exit codes:

- `0`: all checks pass
- `1`: validation errors found
- `2`: usage error

Failure modes:

- Not in a git work tree (cannot resolve repo root).
- Missing required tools (`git`, `python3`).
- Violations detected (prints `error:` lines).

## Scripts

Canonical implementations live under this skill:

- `scripts/validate-skill-contracts.sh`
- `scripts/audit-skill-layout.sh`
- `scripts/audit-skill-paths.sh`

Repo-level wrappers (stable entrypoints) delegate to these scripts:

- `$CODEX_HOME/scripts/validate_skill_contracts.sh`
- `$CODEX_HOME/scripts/audit-skill-layout.sh`
- `$CODEX_HOME/scripts/audit-skill-paths.sh`

