# Reproduction Script Guidance (Project-Specific)

Use this guidance when creating a project-specific bug-fix skill.

## Goal

Create a minimal reproduction script that triggers the bug before the fix and passes after the fix.

## Expectations

- Keep it minimal and deterministic.
- Prefer a single command; name it clearly (for example: `scripts/repro.sh`).
- Run it before the fix and after the fix.
- Record the command and results in the PR body and output.

## When not feasible

If the bug depends on UI, external systems, or credentials, document why a repro script is not feasible and provide alternative evidence (logs, unit tests, or mocked steps).
