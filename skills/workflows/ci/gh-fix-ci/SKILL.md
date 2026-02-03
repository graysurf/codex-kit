---
name: gh-fix-ci
description: Use when a user asks to debug or fix failing GitHub Actions checks for PRs or branches/commits; use `gh` to inspect checks and logs, summarize failure context, draft a fix plan, and implement only after explicit approval. Treat external providers (for example Buildkite) as out of scope and report only the details URL.
---

# GitHub CI Fix

## Contract

Prereqs:

- Run inside the target git repo (or pass `--repo`).
- `git`, `gh`, and `python3` available on `PATH`.
- `gh auth status` succeeds for the repo (workflow scope required for logs).

Inputs:

- `--repo <path>`: repo working directory (default `.`).
- `--pr <number|url>`: PR number or URL (optional).
- `--ref <branch|sha>`: branch name or commit SHA (optional).
- `--branch <name>`: branch name to inspect (alias of `--ref`).
- `--commit <sha>`: commit SHA to inspect (alias of `--ref`).
- `--limit <n>`: max workflow runs to inspect when using branch/commit targets (default `20`).
- Optional log extraction flags: `--max-lines`, `--context`, `--json`.

Outputs:

- Text summary or JSON report of failing checks for PRs or branches/commits, including log snippets when available.
- Non-zero exit when failing checks remain or inspection fails.

Exit codes:

- `0`: no failing checks detected.
- `1`: failing checks remain or inspection failed.
- `2`: usage error (invalid flags).

Failure modes:

- Not inside a git repo or unable to resolve the PR/branch/commit target.
- `gh` missing or unauthenticated for the repo.
- `gh pr checks` field drift; fallback fields still fail.
- `gh run list` failed for branch/commit targets.
- Logs unavailable (pending, external provider, or job log is a zip payload).

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/workflows/ci/gh-fix-ci/scripts/gh-fix-ci.sh`
- `$CODEX_HOME/skills/workflows/ci/gh-fix-ci/scripts/inspect_ci_checks.py`

## TL;DR (fast paths)

```bash
$CODEX_HOME/skills/workflows/ci/gh-fix-ci/scripts/gh-fix-ci.sh --pr 123
$CODEX_HOME/skills/workflows/ci/gh-fix-ci/scripts/gh-fix-ci.sh --ref main
$CODEX_HOME/skills/workflows/ci/gh-fix-ci/scripts/inspect_ci_checks.py --ref main --json
```

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
5. Summarize failures:
   - Provide a concise snippet + the run URL or note when logs are pending.
6. Draft a fix plan and ask for approval before implementation.
   - Prefer the `create-plan` skill when available.
7. After approval, implement fixes, rerun relevant tests, and re-check `gh pr checks` (PR targets) or `gh run list` (branch/commit targets).

## Notes

- `inspect_ci_checks.py` returns exit code `1` when failures remain so it can be used in automation.
- Pending logs are reported as `log_pending`; rerun after the workflow completes.
