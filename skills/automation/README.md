# Automation skills

This folder groups skills intended for end-to-end automation (no manual staging/review pauses).

Prefer the review-first variants when the user wants to stage a subset of changes manually.

## Design principles

- Build automation on proven base skills: validate the workflow first, then wrap it as automation.
- Reuse base skill scripts as the canonical implementation; do not copy stable entrypoints into each automation skill.
- Add glue only when needed (autostage, retries, batching). Keep glue thin and prefer shared primitives over duplicated wrappers.
- Keep test growth flat: adding a new automation workflow should rarely add new executable scripts.

## Shared automation libs

Put reusable implementation code under `skills/automation/_libs/`.

Guidelines:

- `_libs/` is for sourceable libraries and non-entrypoint code (no shebang; not executable).
- Keep executable entrypoints in a skill’s `scripts/` only when necessary.
- Prefer `skills/automation/<primitive>/` as a shared primitive (others reference it) over copying wrapper scripts into each automation skill.
- Prefer shared CLI primitives on PATH (install via `brew install nils-cli`; provides `plan-tooling`, `api-*`, `semantic-commit`) for
  deterministic project file/folder discovery; do not add per-skill `*-resolve.sh` wrappers when the shared primitive already exists.

## Migration notes

- Deprecated pattern: per-skill `*-resolve.sh` wrapper scripts that only re-route to the same shared CLI primitive.
- Replace with direct shared primitive usage:
  - automation primitive scripts under `skills/automation/<primitive>/scripts/`
  - shared CLI commands on PATH (`plan-issue`, `plan-tooling`, `semantic-commit`, `api-*`)
