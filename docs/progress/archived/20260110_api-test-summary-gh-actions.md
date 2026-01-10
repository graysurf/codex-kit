# codex-kit: API test runner: CI summary report (GitHub Actions)

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-10 | 2026-01-11 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/15
- Docs: [skills/api-test-runner/SKILL.md](../../../skills/api-test-runner/SKILL.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)
- Downstream validation (real project): https://github.com/Rytass/TunGroup/actions/runs/20880992440

## Goal

- Make GitHub Actions runs scannable for non-engineers by emitting a small human-friendly summary.
- Keep the runner contract stable: `api-test.sh` remains JSON-first; summarization consumes `results.json`.

## Acceptance Criteria

- Add `skills/api-test-runner/scripts/api-test-summary.sh`:
  - Input: `results.json` file (or stdin)
  - Output: concise Markdown summary to stdout (CI logs) and optional `--out <path>`
  - Default: list only failed cases + slowest Top N; skipped cases are shown only with `--show-skipped`
  - CI: append the same Markdown to `$GITHUB_STEP_SUMMARY` when available
- Update `.github/workflows/api-test-runner.yml` to demonstrate:
  - Run `api-test.sh` with `--out`
  - Always run `api-test-summary.sh` after (even when suite fails)
  - Upload `results.json` + `*.summary.md` artifacts
- Update docs to include copy/paste commands and CI pattern.

## Scope

- In-scope:
  - Summary script + minimal docs/workflow updates
  - Keep output small and safe (no secrets / no response body dumps)
- Out-of-scope:
  - Changing `api-test.sh` JSON schema or exit code behavior
  - Fancy HTML reports / charts
  - Automatically linking artifacts into the summary (Actions UI limitation)

## I/O Contract

### Input

- `out/api-test-runner/*.results.json` (output of `api-test.sh --out`)

### Output

- CI logs: Markdown summary printed to stdout
- Optional: `--out out/api-test-runner/*.summary.md`
- Optional (CI): append to `$GITHUB_STEP_SUMMARY`

### Intermediate Artifacts

- `out/api-test-runner/*.summary.md` (artifact for PMs to download)

## Design / Decisions

### Rationale

- Prefer B+Summary over modifying `api-test.sh` progress output:
  - Keeps runner contract stable and composable
  - Lets CI choose how to present results (log-only, summary-only, or artifact)

### Risks / Uncertainties

- Risk: accidental sensitive output in summaries
  - Mitigation: summarize only `results.json` fields; do not read/print response bodies

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Decide approach: B+Summary (separate `api-test-summary.sh`)
    - [x] Decide defaults: show failed + slow Top N; skipped behind a flag
  - Artifacts:
    - `docs/progress/20260110_api-test-summary-gh-actions.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (see sections above).
    - [x] Data flow and I/O contract are defined (results.json -> summary).
    - [x] Risks and mitigations are defined (no response body / no secrets).
    - [x] Minimal verification commands are listed in Step 3.
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement `skills/api-test-runner/scripts/api-test-summary.sh`
  - Artifacts:
    - `skills/api-test-runner/scripts/api-test-summary.sh`
  - Exit Criteria:
    - [x] Generates a readable summary from a real `results.json` (see Step 3 commands).
- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Update workflow example to run summary and upload artifacts
    - [x] Update docs and guide with usage + CI patterns
  - Artifacts:
    - `.github/workflows/api-test-runner.yml`
    - `skills/api-test-runner/SKILL.md`
    - `skills/api-test-runner/references/API_TEST_RUNNER_GUIDE.md`
  - Exit Criteria:
    - [x] CI usage pattern is documented (always-run summary step; upload `*.summary.md`).
    - [x] Summary output is bounded (Top N / max list limits).
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run a suite to produce `results.json`, then run `api-test-summary.sh`
    - [x] Verify missing/invalid input produces a clear summary without breaking CI steps
  - Artifacts:
    - `out/api-test-runner/results.json`
    - `out/api-test-runner/summary.md`
  - Exit Criteria:
    - [x] Commands executed with results recorded:
      - `cp -R "$CODEX_HOME/skills/api-test-runner/template/setup" ./setup`
      - `skills/api-test-runner/scripts/api-test.sh --suite smoke-demo --out out/api-test-runner/results.json`
      - `skills/api-test-runner/scripts/api-test-summary.sh --in out/api-test-runner/results.json --out out/api-test-runner/summary.md --slow 5`
    - [x] Summary is readable and small (failed list + slow Top N; no skipped unless enabled).
    - [x] Failure modes are readable (missing file / invalid JSON).
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Merge PR; archive this progress file via `close-progress-pr`
  - Artifacts:
    - `docs/progress/archived/20260110_api-test-summary-gh-actions.md`
  - Exit Criteria:
    - [x] Documentation completed and entry points updated.
    - [x] Cleanup completed: progress status `DONE`, archived file moved, follow-ups captured.

## Modules

- `skills/api-test-runner/scripts/api-test-summary.sh`: turns results JSON into a small Markdown summary for CI + PMs.
- `.github/workflows/api-test-runner.yml`: example usage (always-run summary, upload artifacts).
