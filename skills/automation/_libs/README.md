# Automation shared libs

This folder holds shared, sourceable implementation code used by automation skills.

Conventions:

- Keep libraries **non-executable** (no shebang) so they are not treated as script entrypoints.
- Avoid creating a `scripts/` directory under `_libs/` (repo tests treat `skills/**/scripts/**` as entrypoints).
- Suggested layout (create only what you use):
  - `skills/automation/_libs/zsh/*.zsh` for zsh helpers (source from `zsh -f` scripts)
  - `skills/automation/_libs/sh/*.sh` for POSIX shell helpers
  - `skills/automation/_libs/python/*.py` for python helpers

Rule of thumb:

- If it must be invoked directly: put it under a specific skill’s `scripts/` (entrypoint).
- If it’s shared logic: put it here and source/import it from the entrypoint.

Related patterns:

- `skills/tools/_libs/` and `skills/workflows/_libs/` follow the same conventions for their respective skill families.
- `skills/_projects/_libs/` is reserved for shared helpers across `_projects` skills.
