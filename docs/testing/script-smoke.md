# Script Smoke Tests (pytest)

## TL;DR

1. Install dev deps:

```bash
.venv/bin/pip install -r requirements-dev.txt
```

1. Run smoke:

```bash
$AGENT_HOME/scripts/test.sh -m script_smoke
```

Or via consolidated check wrapper:

```bash
scripts/check.sh --tests -- -m script_smoke
```

When entrypoints are added/removed/renamed, run companion ownership checks:

```bash
bash scripts/ci/stale-skill-scripts-audit.sh --check
scripts/check.sh --entrypoint-ownership
```

## What it does

- Runs selected script entrypoints through deeper smoke cases (beyond `--help`).
- Smoke cases are either:
  - Spec-driven (preferred): `tests/script_specs/<script_relpath>.json` includes a `smoke` list (or `{ "cases": [...] }`).
  - Fixture-driven: pytest builds temporary repos/files (used for scripts that mutate git state, etc.).
- Critical smoke specs retained after desktop-notify pruning:
  - `tests/script_specs/scripts/check.sh.json`
  - `tests/script_specs/skills/tools/devex/desktop-notify/scripts/desktop-notify.sh.json`
  - `tests/script_specs/skills/tools/devex/desktop-notify/scripts/project-notify.sh.json`
- Retained issue-workflow smoke specs:
  - `tests/script_specs/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh.json`
  - `tests/script_specs/skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh.json`
- Removed desktop-notify wrappers (for example `codex-notify.sh`) should not keep stale smoke specs.
- Deprecated release-workflow helper entrypoints removed in PR #221 (`audit-changelog.zsh`, `release-audit.sh`,
  `release-find-guide.sh`, `release-notes-from-changelog.sh`, `release-scaffold-entry.sh`) should not keep stale smoke specs.
  Keep smoke coverage on retained entrypoints only:
  - `tests/script_specs/skills/automation/release-workflow/scripts/release-resolve.sh.json`
  - `tests/script_specs/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh.json`
- Writes evidence (untracked) under:
  - `out/tests/script-smoke/summary.json`
  - `out/tests/script-smoke/logs/**`

## CI artifact conventions

- Pytest workflow artifacts stay under `out/tests/**`.
- API workflow artifacts stay under `out/api-test-runner/<suite>/`.
- For each API suite, CI writes:
  - `out/api-test-runner/<suite>/results.json`
  - `out/api-test-runner/<suite>/junit.xml`
  - `out/api-test-runner/<suite>/summary.md`
- API workflow summary steps append each `summary.md` to `GITHUB_STEP_SUMMARY`, and the summary includes the artifact directory for fast triage.

## Plan-issue cleanup gate

Run the cleanup helper before declaring plan completion:

```bash
scripts/check_plan_issue_worktree_cleanup.sh \
  "$AGENT_HOME/out/plan-issue-delivery/graysurf__agent-kit/issue-193/worktrees"
```

Expected behavior:

- Pass (`exit 0`): no leftover task worktree directories under `worktrees/*/*`.
- Fail (`exit 1`): leftover task directories still exist; stderr lists each path.

Quick local smoke example:

```bash
test_root="${AGENT_HOME:-$(pwd)}/out/plan-issue-delivery-e2e-cleanup-check"
rm -rf "$test_root"
mkdir -p "$test_root/worktrees/pr-isolated/task-a"
! scripts/check_plan_issue_worktree_cleanup.sh "$test_root/worktrees"
rm -rf "$test_root/worktrees/pr-isolated/task-a"
scripts/check_plan_issue_worktree_cleanup.sh "$test_root/worktrees"
```

## Authoring spec-driven smoke cases

Create or extend a per-script spec at:

`tests/script_specs/<script_relpath>.json`

Add a `smoke` array of cases (or `{ "cases": [...] }`):

- `name`: string (used in log filenames)
- `args`: list of CLI args (default: `[]`)
- `command`: optional full argv list (cannot be combined with `args`)
- `env`: env var overrides (values are strings; use `null` to unset)
- `timeout_sec`: number (default: `10`)
- `expect`:
  - `exit_codes`: list of allowed exit codes (default: `[0]`)
  - `stdout_regex`: optional regex (multiline)
  - `stderr_regex`: optional regex (multiline)
- `artifacts`: optional list of repo-relative paths that must exist after the case runs

## When to use fixture-driven smoke

Use pytest fixtures when a smoke case needs setup/teardown that must not touch the real repo state, e.g.:

- Temporary git repos (commits, staging, branching)
- Scripts that write files and require isolated working dirs
- Scripts that must run under a specific cwd

See: `tests/test_script_smoke.py`

## Related docs

- Regression suite (broad `--help` guardrail): `docs/testing/script-regression.md`
- CI parity + docs completion guardrails: `docs/testing/ci-check-parity.md`
