# Workflows shared libs

This folder holds shared, non-executable implementation code used by workflow skills.

Conventions:

- Keep libraries **non-executable** (no shebang) so they are not treated as script entrypoints.
- Do not create a `scripts/` directory under `_libs/` (repo tests treat `skills/**/scripts/**` as entrypoints).
- Suggested layout (create only what you use):
  - `skills/workflows/_libs/sh/*.sh` for POSIX shell helpers
  - `skills/workflows/_libs/zsh/*.zsh` for zsh helpers
  - `skills/workflows/_libs/python/*.py` for python helpers
  - `skills/workflows/_libs/md/*.md` for shared docs/skeletons

Rule of thumb:

- If it must be invoked directly: put it under a specific skill’s `scripts/` (entrypoint).
- If it’s shared logic: put it here and source/import it from the entrypoint.

