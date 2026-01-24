# Projects shared libs

This folder holds shared, non-executable implementation code used by `_projects` skills.

Note: Unlike most of `skills/_projects/` (local-only), this `_libs/` folder is
versioned so multiple local projects can share safe helpers.

Conventions:

- Keep libraries **non-executable** (no shebang) so they are not treated as script entrypoints.
- Do not create a `scripts/` directory under `_libs/` (repo tests treat `skills/**/scripts/**` as entrypoints).
- Suggested layout (create only what you use):
  - `skills/_projects/_libs/sh/*.sh` for POSIX shell helpers
  - `skills/_projects/_libs/zsh/*.zsh` for zsh helpers
  - `skills/_projects/_libs/python/*.py` for python helpers
  - `skills/_projects/_libs/md/*.md` for shared docs/skeletons

Rule of thumb:

- If it must be invoked directly: put it under a project’s `scripts/` (entrypoint).
- If it’s shared logic across projects: put it here and source/import it from the entrypoint.
