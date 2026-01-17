# codex-kit: GraphQL API testing: command history

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-08 | 2026-01-17 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/8
- Planning PR: https://github.com/graysurf/codex-kit/pull/7
- Docs: [skills/tools/testing/graphql-api-testing/SKILL.md](../../../skills/tools/testing/graphql-api-testing/SKILL.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Addendum

### 2026-01-17

- Change: Update archived path references for the skill scaffold (`template/` -> `assets/scaffold/`).
- Reason: The skills directory layout was normalized; keep DONE docs accurate and reduce search noise.
- Impact: Documentation-only; no runtime behavior changes.
- Links:
  - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/.gitignore`
  - [docs/progress/archived/20260117_skills-layout-normalization-and-audit.md](20260117_skills-layout-normalization-and-audit.md)

## Goal

- Record a local, append-only history of `gql.sh` invocations for quick review and replay.
- Store history under the resolved GraphQL config dir (typically `setup/graphql/`) and keep it gitignored by default.
- Keep history enabled by default, but controllable via environment variables (enable/disable, file path, optional size limits).
- Optionally include a copy/pasteable `gql.sh` command snippet in `gql-report.sh` reports for quick reuse.

## Acceptance Criteria

- Running `skills/tools/testing/graphql-api-testing/scripts/gql.sh ...` appends a replayable shell snippet to the history file when history is enabled (default).
- Default history location is under resolved `setup_dir`: `<setup_dir>/.gql_history` (typically `setup/graphql/.gql_history`).
- Each entry includes a timestamp and exit code, plus resolved context (`config_dir`, `--env` or URL, `--jwt` name), and entries are separated by a blank line.
- History logging can be disabled via env toggle (`GQL_HISTORY=0`) without changing `gql.sh` stdout/stderr behavior.
- URL is logged by default; can be omitted via env (`GQL_HISTORY_LOG_URL=0`).
- History rotates by default when it grows beyond 10 MB (rotate keep old files); configurable via env (`GQL_HISTORY_MAX_MB`, `GQL_HISTORY_ROTATE_COUNT`).
- No secrets are written: token values (`ACCESS_TOKEN`, resolved `GQL_JWT_*`) are never logged.
- Template `.gitignore` ignores the history file by default and docs mention how to add it to existing repos.
- `gql-report.sh` includes a `## Command` section by default with a replayable `gql.sh` snippet; disable with `--no-command` or `GQL_REPORT_INCLUDE_COMMAND=0`.
- When the command uses `--url`, the URL is included by default but can be omitted via `--no-command-url` or `GQL_REPORT_COMMAND_LOG_URL=0`.

## Scope

- In-scope:
  - Add history logging to `skills/tools/testing/graphql-api-testing/scripts/gql.sh` (append-only file under resolved `setup_dir`).
  - Define env-based controls (enable/disable; optional override path; optional size limit/rotation).
  - Update bootstrap template `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/.gitignore` to ignore the history file.
  - Document the feature in `skills/tools/testing/graphql-api-testing/SKILL.md` (and optionally in the project guide template).
- Out-of-scope:
  - Capturing full shell pipelines (e.g., `| jq .`) automatically.
  - Storing request/response payloads or variable file contents in history.
  - Interactive UI/TUI for browsing and replaying history (can be a follow-up).
  - Windows portability improvements beyond current POSIX assumptions.

## I/O Contract

### Input

- `gql.sh` invocation context:
  - Operation file: `setup/graphql/**/<name>.graphql`
  - Variables file (optional): `setup/graphql/**/<name>.json`
  - Endpoint selection: `--env <name>` / `--url <url>` / `GQL_URL`
  - Auth selection: `--jwt <name>` / `GQL_JWT_NAME` / `ACCESS_TOKEN`
  - Config discovery: resolved `setup_dir` (via `--config-dir` or upward search)
- History controls (proposed):
  - `GQL_HISTORY=0|1` (default: enabled)
  - `GQL_HISTORY_FILE=<path>` (optional override; default under `setup_dir`)
  - `GQL_HISTORY_LOG_URL=0|1` (default: `1`)
  - `GQL_HISTORY_MAX_MB=<n>` (default: `10`; `0` disables the size limit)
  - `GQL_HISTORY_ROTATE_COUNT=<n>` (default: `5`)
- Report controls (proposed):
  - `GQL_REPORT_INCLUDE_COMMAND=0|1` (default: `1`)
  - `GQL_REPORT_COMMAND_LOG_URL=0|1` (default: `1`)

### Output

- History file entry appended (default): `<setup_dir>/.gql_history`.
- `gql.sh` behavior remains unchanged: prints response body to stdout; exits non-zero on invalid inputs or HTTP errors.

### Intermediate Artifacts

- (Optional) Locking mechanism to prevent interleaved writes (e.g., `flock` or a `*.lock` file), if needed.
- (Optional) Truncated/rotated history file if a max size is enforced.

## Design / Decisions

### Rationale

- A single append-only file per project is easy to review, grep, and reuse (similar ergonomics to `.zsh_history`).
- Logging a canonical multi-line snippet makes copy/paste replay the primary workflow; separating entries with a blank line keeps it readable without complex parsing.
- Writing under the resolved `setup_dir` avoids cross-project mixing and aligns with the skill’s file-based workflow.
- Env toggles are low-friction for global enable/disable and safe defaults.

### Risks / Uncertainties

- Command reconstruction: logging a canonical snippet may differ from the exact user-typed command; ensure it is replayable and handles quoting safely.
- URLs can embed secrets (query params); default is to log URL, but allow omitting via `GQL_HISTORY_LOG_URL=0` (optional future: redact query string).
- File growth and performance: enforce a default max size (10 MB) and rotate keep old files (keep N by policy).
- Concurrency: parallel invocations could interleave writes; decide whether to add locking.
- Existing repos already using `setup/graphql/`: template `.gitignore` updates do not apply retroactively; docs should include a short “add this line” note.

## Steps (Checklist)

Note: Any unchecked checkbox in this section must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete.

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Decide history filename and default location: `<setup_dir>/.gql_history`.
    - [x] Define the env interface (enable/disable + optional override path + URL logging toggle + size/rotation behavior).
    - [x] Define the entry format (metadata + canonical multi-line command + blank line separator).
    - [x] Define a redaction policy baseline: tokens never logged; URL logged by default with an env toggle to omit.
  - Artifacts:
    - `docs/progress/20260108_graphql-api-testing-command-history.md` (this file)
    - Notes and examples captured under Exit Criteria
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (this document is complete).
    - [x] Data flow and I/O contract are defined (what is logged, where, and under which controls).
    - [x] Risks, rollback plan (disable flag), and retroactive adoption guidance are defined.
    - [x] Minimal verification commands are defined (history file created/updated; no secrets logged).
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement history append in `skills/tools/testing/graphql-api-testing/scripts/gql.sh` (enabled by default; env toggle to disable).
    - [x] Add `GQL_HISTORY_FILE` override and default path under resolved `setup_dir`.
    - [x] Add size limit enforcement (default: 10 MB) and rotate keep old files (keep N by policy).
    - [x] Add URL logging toggle (default on; `GQL_HISTORY_LOG_URL=0` omits URL).
    - [x] Update `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/.gitignore` to ignore the history file.
    - [x] Add report `## Command` section in `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh` (enabled by default; toggleable).
    - [x] Add report URL omission toggle (`--no-command-url` / `GQL_REPORT_COMMAND_LOG_URL=0`).
    - [x] Update docs: `skills/tools/testing/graphql-api-testing/SKILL.md` (and `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`).
  - Artifacts:
    - `skills/tools/testing/graphql-api-testing/scripts/gql.sh`
    - `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`
    - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/.gitignore`
    - `skills/tools/testing/graphql-api-testing/SKILL.md`
  - Exit Criteria:
    - [x] `bash -n skills/tools/testing/graphql-api-testing/scripts/gql.sh` passes.
    - [x] `bash -n skills/tools/testing/graphql-api-testing/scripts/gql-report.sh` passes.
    - [x] History file is appended on both success and failure with a recorded exit code (confirmed).
    - [x] Docs include a TL;DR snippet showing where history lives and how to disable it.
    - [x] Reports include `## Command` by default and can omit URL value with `--no-command-url` / `GQL_REPORT_COMMAND_LOG_URL=0`.
- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] If rotating, support keeping N rotated files (and document the policy).
    - [x] Add a CLI switch (`--no-history`) for one-off runs (keep env as the primary control surface).
    - [x] Add a helper to extract recent entries: `skills/tools/testing/graphql-api-testing/scripts/gql-history.sh`.
  - Artifacts:
    - Notes and design decisions recorded in docs
  - Exit Criteria:
    - [x] Common branches are covered (disable/override path/rotation/error handling) via local smoke tests; full real-endpoint validation remains Step 3.
    - [x] No behavior regression for existing usage (stdout/stderr and exit codes unchanged) confirmed via `bash -n` + `--help` checks.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Validate in a real project repo with an existing `setup/graphql/` and endpoint presets.
    - [x] Verify history content is replayable and does not include secrets.
  - Artifacts:
    - Report evidence: `out/graphql-api-testing/financereport/20260108-0506-financereport-companyreports-local-api-test-report.md` (includes `## Command`).
    - History evidence: `/Users/terry/Project/rytass/FinanceReport/setup/graphql/.gql_history`.
    - Command transcripts recorded in this progress file (see Exit Criteria).
  - Exit Criteria:
    - [x] Validation commands executed with results recorded (happy path + failure case + disable case).
      - Happy path (report + history):
        - `cd /Users/terry/Project/rytass/FinanceReport && GQL_REPORT_DIR="$CODEX_HOME/out/graphql-api-testing/financereport" "$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-report.sh" --case "FinanceReport companyReports (local)" --op setup/graphql/operations/company-reports.graphql --vars setup/graphql/operations/company-reports.variables.json --config-dir setup/graphql --env local --jwt default --run`
        - History check: `"$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-history.sh" --config-dir /Users/terry/Project/rytass/FinanceReport/setup/graphql --last`
      - Failure case (history logs non-zero exit):
        - `cd /Users/terry/Project/rytass/FinanceReport && "$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh" --config-dir setup/graphql --env local --jwt default setup/graphql/operations/does-not-exist.graphql`
      - Disable case (`--no-history` leaves `.gql_history` unchanged):
        - `cd /Users/terry/Project/rytass/FinanceReport && "$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh" --no-history --config-dir setup/graphql --env local --jwt default setup/graphql/operations/does-not-exist.graphql`
    - [x] Traceable evidence exists (sample excerpt, logs, or report links) with secrets redacted.
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] After merge, validate the feature in at least one repo and document any adoption notes.
      - Post-merge report: `out/graphql-api-testing/financereport/20260108-0534-financereport-companyreports-post-merge-api-test-report.md`
      - Adoption note: existing repos should add `setup/graphql/.gitignore` (or equivalent) to ignore `.gql_history*` and `*.local.env` / `*.local.json` (template already includes it).
    - [x] Set progress Status to `DONE` and archive under `docs/progress/archived/`.
  - Artifacts:
    - `docs/progress/archived/20260108_graphql-api-testing-command-history.md`
  - Exit Criteria:
    - [x] Progress file is archived and index updated (`docs/progress/README.md`).
    - [x] Documentation entry points updated if needed (README / docs index links).
    - [x] Cleanup completed (remove temporary flags/files; confirm defaults).

## Modules

- `skills/tools/testing/graphql-api-testing/scripts/gql.sh`: Record a canonical, replayable history entry for each invocation (no secrets).
- `skills/tools/testing/graphql-api-testing/scripts/gql-history.sh`: Extract recent history entries for copy/paste replay.
- `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/.gitignore`: Keep the history file out of git by default.
- `skills/tools/testing/graphql-api-testing/SKILL.md`: Document history behavior, location, and env toggles.
- `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`: (Optional) Mention history in the project-local guide template.
