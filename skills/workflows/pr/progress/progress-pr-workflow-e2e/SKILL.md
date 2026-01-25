---
name: progress-pr-workflow-e2e
description: Run a real-GitHub E2E driver for the progress PR workflow (planning -> handoff -> stacked PRs -> close/archive). Use when validating the full progress workflow end-to-end.
---

# Progress PR Workflow E2E Driver

## Contract

Prereqs:

- Run inside the target git repo with a clean working tree.
- `git`, `gh`, and `python3` available on `PATH`.
- `gh auth status` succeeds.
- `E2E_ALLOW_REAL_GH=1` is set.
- `CI` is not `true` (script refuses to run in CI).

Inputs:

- `--phase <init|plan|handoff|worktrees|prs|close|cleanup|all>`
- Optional:
  - `--run-id <id>` (reuse an existing run directory)
  - `--base <branch>` (source branch for sandbox base; default `main`)
  - `--sandbox-base <branch>` (sandbox base branch name)
  - `--skip-checks` (skip gh checks gating)
  - `--keep-sandbox` (preserve sandbox branches in cleanup)

Outputs:

- `out/e2e/progress-pr-workflow/<run-id>/run.json`
- Worktrees under `../.worktrees/<repo>/e2e-<run-id>` (when `worktrees` runs)
- GitHub PRs and branches created/merged during the run

Exit codes:

- `0`: success
- non-zero: guard failures, missing tooling, git/gh errors, or phase failures

Failure modes:

- `E2E_ALLOW_REAL_GH` not set or `CI=true`.
- Dirty working tree or missing repo context.
- `gh auth status` fails.
- Helper scripts under `skills/workflows/pr/progress/**` are missing.

## Usage

Canonical entrypoint:

- `$CODEX_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh --phase all`

## Notes

- This driver touches real GitHub resources. Use a sandbox repo or sandbox base branch.
- Use `--run-id` to resume phases and `--keep-sandbox` to preserve branches for inspection.
