---
name: gh-fix-ci
description: "Fully automated GitHub Actions CI fixer: inspect failing checks, apply fixes, semantic-commit-autostage + push, then watch CI and repeat until green."
---

# GitHub CI Auto Fix

## Contract

Prereqs:

- Run inside the target git repo (or pass `--repo`).
- `git`, `gh`, and `python3` available on `PATH`.
- `semantic-commit` and `git-scope` available on `PATH` (required for commits).
- `gh auth status` succeeds for the repo (workflow scope required for logs).
- Push access to the target branch (PR branch or specified branch).

Inputs:

- `--repo <path>`: repo working directory (default `.`).
- `--pr <number|url>`: PR number or URL (optional).
- `--ref <branch|sha>`: branch name or commit SHA (optional).
- `--branch <name>`: branch name to inspect (alias of `--ref`).
- `--commit <sha>`: commit SHA to inspect (alias of `--ref`).
- `--limit <n>`: max workflow runs to inspect when using branch/commit targets (default `20`).
- PR-only flags: `--required` (only required checks).
- Optional log extraction flags: `--max-lines`, `--context`, `--json`.

Outputs:

- One or more fix commits pushed to the target branch.
- CI ends green (no failing required checks) or a terminal report of what blocked automation.
- Text summary or JSON report of failing checks (including log snippets when available) for each iteration.

Exit codes:

- N/A (multi-command workflow; failures surfaced from underlying commands).

Failure modes:

- Not inside a git repo or unable to resolve the PR/branch/commit target.
- `gh` missing or unauthenticated for the repo.
- `semantic-commit`/`git-scope` missing (cannot auto-commit).
- `gh pr checks` field drift; fallback fields still fail.
- `gh run list` failed for branch/commit targets.
- Logs unavailable (pending, external provider, or job log is a zip payload).
- Insufficient permissions to push to the target branch.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/automation/gh-fix-ci/scripts/gh-fix-ci.sh`
- `$CODEX_HOME/skills/automation/gh-fix-ci/scripts/inspect_ci_checks.py`

## TL;DR (fast paths)

```bash
$CODEX_HOME/skills/automation/gh-fix-ci/scripts/gh-fix-ci.sh --pr 123
$CODEX_HOME/skills/automation/gh-fix-ci/scripts/gh-fix-ci.sh --ref main
$CODEX_HOME/skills/automation/gh-fix-ci/scripts/inspect_ci_checks.py --ref main --json
```

## Trigger

Use this skill when the user wants end-to-end CI fixing (no manual review pauses): diagnose, fix, commit, push, and keep iterating until CI is green.

## Workflow

1. Verify `gh` authentication with `gh auth status`. If unauthenticated, ask the user to run `gh auth login` (repo + workflow scopes).
2. Resolve the target:
   - If the user provided `--pr`, use it.
   - If the user provided `--ref`/`--branch`/`--commit`, use that.
   - Otherwise attempt `gh pr view --json number,url` on the current branch; if unavailable, fall back to the current branch name (or `HEAD` commit when detached).
3. Inspect failing checks (GitHub Actions only):
   - For PR targets: run `inspect_ci_checks.py`, which calls `gh pr checks`.
   - For branch/commit targets: run `inspect_ci_checks.py`, which calls `gh run list` + `gh run view`.
   - For each failure, capture the check name, run URL, and log snippet.
4. Handle external providers:
   - If `detailsUrl` is not a GitHub Actions run, label as external and report the URL only.
5. Auto-fix loop (repeat until green):
   - Reproduce locally when feasible (prefer the repo’s documented lint/test commands; otherwise use the failing command shown in logs).
   - Implement the minimal fix; avoid refactors.
   - Run the most relevant local validation command(s) as a gate (lint/test/build as applicable).
   - Commit using `semantic-commit-autostage` (single commit per iteration unless splitting is clearly beneficial).
   - Push the current branch (update the PR branch when targeting a PR).
   - Wait for CI:
     - PR: `gh pr checks <pr> --watch --interval 10 --required` (wait until required checks finish, then confirm pass/fail)
     - Branch/commit: watch the latest run for the pushed SHA (use `gh run list` then `gh run watch <run-id> --interval 10 --exit-status`)
   - If CI still fails, inspect again and continue the loop.

## Notes

- `inspect_ci_checks.py` returns exit code `1` when failures remain so it can be used in automation.
- Pending logs are reported as `log_pending`; rerun after the workflow completes.
- Guardrail: if the failure indicates missing secrets, infra outage, or an external provider, stop and report the blocking detail/URL instead of guessing.
