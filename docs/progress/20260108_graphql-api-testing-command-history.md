# codex-kit: GraphQL API testing: command history

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-08 | 2026-01-08 |

Links:

- PR: TBD
- Docs: [skills/graphql-api-testing/SKILL.md](../../skills/graphql-api-testing/SKILL.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../templates/PROGRESS_GLOSSARY.md)

## Goal

- Record a local, append-only history of `gql.sh` invocations for quick review and replay.
- Store history under the resolved GraphQL config dir (typically `setup/graphql/`) and keep it gitignored by default.
- Keep history enabled by default, but controllable via environment variables (enable/disable, file path, optional size limits).

## Acceptance Criteria

- Running `skills/graphql-api-testing/scripts/gql.sh ...` appends a replayable shell snippet to the history file when history is enabled (default).
- Default history location is under the resolved config dir: `<config_dir>/.gql_history` (name TBD; see Risks / Uncertainties).
- Each entry includes a timestamp and exit code, plus resolved context (`config_dir`, `--env` or URL, `--jwt` name), and entries are separated by a blank line.
- History logging can be disabled via env toggle (proposed: `GQL_HISTORY=0`) without changing `gql.sh` stdout/stderr behavior.
- No secrets are written: token values (`ACCESS_TOKEN`, resolved `GQL_JWT_*`) are never logged.
- Template `.gitignore` ignores the history file by default and docs mention how to add it to existing repos.

## Scope

- In-scope:
  - Add history logging to `skills/graphql-api-testing/scripts/gql.sh` (append-only file under resolved `setup_dir`).
  - Define env-based controls (enable/disable; optional override path; optional size limit/rotation).
  - Update bootstrap template `skills/graphql-api-testing/template/setup/graphql/.gitignore` to ignore the history file.
  - Document the feature in `skills/graphql-api-testing/SKILL.md` (and optionally in the project guide template).
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
  - `GQL_HISTORY_MAX_BYTES=<n>` (optional; default TBD)

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

- History filename: `setup/graphql/.history` vs `setup/graphql/.gql_history` (prefer a namespaced filename to avoid collisions).
- Command reconstruction: logging a canonical snippet may differ from the exact user-typed command; ensure it is replayable and handles quoting safely.
- URLs can embed secrets (query params); decide whether to log the resolved URL as-is or redact parts by default.
- File growth and performance: decide max size / rotation strategy to avoid unbounded growth.
- Concurrency: parallel invocations could interleave writes; decide whether to add locking.
- Existing repos already using `setup/graphql/`: template `.gitignore` updates do not apply retroactively; docs should include a short “add this line” note.

## Steps (Checklist)

Note: Any unchecked checkbox in this section must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete.

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Decide history filename and default location relative to resolved `setup_dir`.
    - [ ] Define the env interface (enable/disable + optional override path + optional limits).
    - [ ] Define the entry format (metadata + canonical multi-line command + blank line separator).
    - [ ] Define a redaction policy (tokens never logged; consider URL redaction).
  - Artifacts:
    - `docs/progress/20260108_graphql-api-testing-command-history.md` (this file)
    - Notes and examples captured under Exit Criteria
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned (this document is complete).
    - [ ] Data flow and I/O contract are defined (what is logged, where, and under which controls).
    - [ ] Risks, rollback plan (disable flag), and retroactive adoption guidance are defined.
    - [ ] Minimal verification commands are defined (history file created/updated; no secrets logged).
- [ ] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [ ] Implement history append in `skills/graphql-api-testing/scripts/gql.sh` (enabled by default; env toggle to disable).
    - [ ] Add `GQL_HISTORY_FILE` override and default path under resolved `setup_dir`.
    - [ ] Update `skills/graphql-api-testing/template/setup/graphql/.gitignore` to ignore the history file.
    - [ ] Update docs: `skills/graphql-api-testing/SKILL.md` (and optionally `skills/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`).
  - Artifacts:
    - `skills/graphql-api-testing/scripts/gql.sh`
    - `skills/graphql-api-testing/template/setup/graphql/.gitignore`
    - `skills/graphql-api-testing/SKILL.md`
  - Exit Criteria:
    - [ ] `bash -n skills/graphql-api-testing/scripts/gql.sh` passes.
    - [ ] History file is appended on both success and failure with a recorded exit code (design choice; confirm).
    - [ ] Docs include a TL;DR snippet showing where history lives and how to disable it.
- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Add optional max size / rotation (proposed: `GQL_HISTORY_MAX_BYTES`).
    - [ ] Consider a CLI switch (`--no-history`) for one-off runs (optional; keep env as primary control).
    - [ ] Consider a helper to replay or extract the last entry (optional; follow-up).
  - Artifacts:
    - Notes and design decisions recorded in docs
  - Exit Criteria:
    - [ ] Common branches are covered (disable/override path/rotation/error handling).
    - [ ] No behavior regression for existing usage (stdout/stderr and exit codes unchanged).
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Validate in a real project repo with an existing `setup/graphql/` and endpoint presets.
    - [ ] Verify history content is replayable and does not include secrets.
  - Artifacts:
    - A redacted sample history excerpt under `output/graphql-api-testing/<project>/` (optional evidence)
    - Command transcripts recorded in the PR description or progress file
  - Exit Criteria:
    - [ ] Validation commands executed with results recorded (happy path + failure case + disable case).
    - [ ] Traceable evidence exists (sample excerpt, logs, or report links) with secrets redacted.
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] After merge, validate the feature in at least one repo and document any adoption notes.
    - [ ] Set progress Status to `DONE` and archive under `docs/progress/archived/`.
  - Artifacts:
    - `docs/progress/archived/20260108_graphql-api-testing-command-history.md`
  - Exit Criteria:
    - [ ] Progress file is archived and index updated (`docs/progress/README.md`).
    - [ ] Documentation entry points updated if needed (README / docs index links).
    - [ ] Cleanup completed (remove temporary flags/files; confirm defaults).

## Modules

- `skills/graphql-api-testing/scripts/gql.sh`: Record a canonical, replayable history entry for each invocation (no secrets).
- `skills/graphql-api-testing/template/setup/graphql/.gitignore`: Keep the history file out of git by default.
- `skills/graphql-api-testing/SKILL.md`: Document history behavior, location, and env toggles.
- `skills/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`: (Optional) Mention history in the project-local guide template.
