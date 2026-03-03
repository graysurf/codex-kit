# Automation shared libs

This folder holds shared, sourceable implementation code used by automation skills.

Conventions:

- Keep libraries **non-executable** (no shebang) so they are not treated as script entrypoints.
- Avoid creating a `scripts/` directory under `_libs/` (repo tests treat `skills/**/scripts/**` as entrypoints).
- Do not place user-facing wrapper entrypoints in `_libs/`; shared libraries stay internal to retained entrypoints.
- Suggested layout (create only what you use):
  - `skills/automation/_libs/zsh/*.zsh` for zsh helpers (source from `zsh -f` scripts)
  - `skills/automation/_libs/sh/*.sh` for POSIX shell helpers
  - `skills/automation/_libs/python/*.py` for python helpers

Rule of thumb:

- If it must be invoked directly: put it under a specific skill’s `scripts/` (entrypoint).
- If it’s shared logic: put it here and source/import it from the entrypoint.
- If multiple skills need the same direct command surface: keep one shared primitive skill entrypoint and import shared code from `_libs/`.
