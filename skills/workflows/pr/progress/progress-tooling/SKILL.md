---
name: progress-tooling
description: Render progress PR templates, scaffold progress files, and validate progress index formatting for the progress PR workflow.
---

# Progress Tooling

Helper scripts for the PR progress workflow. This skill provides deterministic entrypoints for template rendering, progress file scaffolding, and index validation.

## Contract

Prereqs:

- `bash` available on `PATH`.
- `git` available on `PATH` (required by create/validate commands).
- `python3` available on `PATH`.

Inputs:

- Script CLI args (see `--help` in each script).
- Run inside the target git repo when using `--project` templates or writing under `docs/`.

Outputs:

- `create_progress_file.sh`: writes a new progress file under `docs/progress/` and may update `docs/templates/` and `docs/progress/README.md`.
- `render_progress_pr.sh`: prints templates to stdout for copy/paste or `gh pr create --body-file ...`.
- `validate_progress_index.sh`: validates progress index formatting in `docs/progress/README.md`.

Exit codes:

- N/A (script entrypoints; failures surfaced by the underlying scripts)

Failure modes:

- Running outside a git work tree when required.
- Missing required templates (project templates under `docs/templates/` or the shared defaults under `skills/workflows/pr/progress/_shared/`).
- Invalid progress index table formatting.

## Scripts (entrypoints)

- `$AGENTS_HOME/skills/workflows/pr/progress/progress-tooling/scripts/create_progress_file.sh`
- `$AGENTS_HOME/skills/workflows/pr/progress/progress-tooling/scripts/render_progress_pr.sh`
- `$AGENTS_HOME/skills/workflows/pr/progress/progress-tooling/scripts/validate_progress_index.sh`
