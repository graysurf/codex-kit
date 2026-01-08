# codex-kit: REST API testing skill

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-08 | 2026-01-08 |

Links:

- PR: [#9](https://github.com/graysurf/codex-kit/pull/9)
- Docs: TBD
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Make manual REST API calls reproducible using file-based requests and per-repo endpoint/token presets (mirrors `graphql-api-testing`).
- Provide a single caller (`rest.sh`), a report generator (`rest-report.sh`), and local command history (`rest-history.sh`) suitable for humans and LLMs.
- Keep secrets out of git by separating templates vs local overrides (`*.local.*`) and redacting sensitive fields in reports by default.
- MVP constraints: JSON payload only; Bearer token auth only; TODO: API key header auth; TODO: multipart/file upload.

## Acceptance Criteria

- `skills/rest-api-testing/scripts/rest.sh` can:
  - Resolve an endpoint base URL via `--env <name>`, `--url <url>`, or `REST_URL=<url>` (with `setup/rest/endpoints.env` + optional `endpoints.local.env` presets).
  - Resolve an Authorization token via `--token <name>`, `REST_TOKEN_NAME=<name>`, or `ACCESS_TOKEN=<token>` (with `setup/rest/tokens.env` + optional `tokens.local.env` presets) and send `Authorization: Bearer <token>`.
  - Execute a request file `setup/rest/requests/<name>.request.json` (single file includes method/path/query/headers/body) and print the response body to stdout; exits non-zero on invalid inputs or HTTP errors.
  - Keep a local history file at `setup/rest/.rest_history` by default (gitignored); supports one-off disable with `--no-history` (or `REST_HISTORY=0`).
- `skills/rest-api-testing/scripts/rest-report.sh` can:
  - Run a request via `rest.sh` (or replay via `--response`) and write a Markdown report under `<project>/docs/` by default.
  - Redact common secret fields in request/response by default; allow opting out with `--no-redact`.
- Bootstrap template exists under `skills/rest-api-testing/template/setup/rest` and includes:
  - `endpoints.env`, `tokens.env`, `.gitignore`, and at least one sample `requests/*.request.json`.
- Skill docs exist under `skills/rest-api-testing/SKILL.md` and reference `docs/templates/REST_API_TEST_OUTPUT_TEMPLATE.md` for reporting.

## Scope

- In-scope:
  - JSON REST requests defined in `setup/rest/requests/*.request.json` (single-file request definition).
  - Endpoint presets and Bearer token profiles with local-only overrides (`*.local.env`, `*.local.json`).
  - CLI scripts: `rest.sh` (caller), `rest-report.sh` (report generator), `rest-history.sh` (history replay).
  - Documentation templates for project setup and report output.
- Out-of-scope:
  - Multipart / file upload (`multipart/form-data`) support. (TODO)
  - API key header auth profiles. (TODO)
  - OpenAPI/Swagger schema tooling, codegen, typed clients. (TODO)
  - Auto-login / token fetching flows. (TODO / project-specific)
  - Non-JSON request payloads (XML, protobuf, etc). (TODO)

## I/O Contract

### Input

- Request: `setup/rest/requests/<name>.request.json`
- Endpoint selection:
  - `--env <name>` (from `setup/rest/endpoints.env` + optional `endpoints.local.env`), OR
  - `--url <url>` / `REST_URL=<url>`
- Auth selection (optional):
  - `--token <name>` / `REST_TOKEN_NAME=<name>` (from `setup/rest/tokens.env` + optional `tokens.local.env`), OR
  - `ACCESS_TOKEN=<token>` (when no token profile is selected)

### Output

- `rest.sh`: prints the raw response body to stdout; exits non-zero on invalid inputs or HTTP errors.
- `rest-report.sh`: writes a Markdown report file (default: `<project root>/docs/<YYYYMMDD-HHMM>-<case>-api-test-report.md`) and prints the path to stdout.

### Intermediate Artifacts

- Config resolution: inferred `setup/rest/` dir via `--config-dir` or upward search (TBD: exact discovery semantics).
- History: `setup/rest/.rest_history` (gitignored).
- (Optional) response snapshot files used for replay: `setup/rest/requests/<name>.response.json` (TBD: exact naming).

## Design / Decisions

### Rationale

- Mirror the GraphQL skill’s primitives (presets + local overrides + history + report) to keep the workflow consistent across API types.
- Use a single request file (`*.request.json`) to avoid cross-file drift and quoting mistakes; secrets remain in `*.local.*`.
- Prefer `xh` / HTTPie for ergonomics, but keep a `curl + jq` fallback to minimize required tooling.
- Default redaction in reports reduces accidental secret/PII leakage; opt-out is explicit.

### Risks / Uncertainties

- Request JSON schema needs a final, stable contract (fields, merge rules, query encoding, headers normalization). Mitigation: define schema + examples in `skills/rest-api-testing/SKILL.md` and validate inputs early.
- “Meaningful data” detection for REST responses is not standardized (vs GraphQL’s `.data`). Mitigation: start without strict no-data blocking in MVP (or make it opt-in), document expected behaviors, and iterate based on real endpoint shapes.
- Redaction heuristics may miss project-specific secret fields. Mitigation: add configurable redaction keys/patterns (TODO) and keep `--no-redact` discouraged.
- Some projects require cookies, mTLS, or non-Bearer auth. Mitigation: explicitly out-of-scope for MVP; track follow-ups as separate progress items.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Finalize naming + layout (`skills/rest-api-testing`, `setup/rest/`, env var prefixes, history file name).
    - [ ] Specify the `*.request.json` schema (method/path/query/headers/body) and provide at least one canonical example.
    - [ ] Decide report output contract (new template under `docs/templates/REST_API_TEST_OUTPUT_TEMPLATE.md`).
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - `docs/templates/REST_API_TEST_OUTPUT_TEMPLATE.md` (TBD)
    - `skills/rest-api-testing/` (TBD)
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned: TBD
    - [ ] Data flow and I/O contract are defined: request schema documented (TBD) + examples exist (TBD)
    - [ ] Risks and out-of-scope items are explicitly recorded: yes (this file)
    - [ ] Minimal reproducible verification data and commands are defined: TBD (pick a real repo + endpoint)
- [ ] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [ ] Implement `skills/rest-api-testing/scripts/rest.sh` (endpoint + auth presets, execute request, history).
    - [ ] Implement `skills/rest-api-testing/scripts/rest-history.sh` (replay last command; tail N).
    - [ ] Implement `skills/rest-api-testing/scripts/rest-report.sh` (generate Markdown report with redaction).
    - [ ] Add bootstrap template under `skills/rest-api-testing/template/setup/rest`.
    - [ ] Add skill instructions under `skills/rest-api-testing/SKILL.md`.
  - Artifacts:
    - `skills/rest-api-testing/scripts/rest.sh`
    - `skills/rest-api-testing/scripts/rest-history.sh`
    - `skills/rest-api-testing/scripts/rest-report.sh`
    - `skills/rest-api-testing/template/setup/rest/*`
    - `skills/rest-api-testing/SKILL.md`
    - `docs/templates/REST_API_TEST_OUTPUT_TEMPLATE.md`
  - Exit Criteria:
    - [ ] At least one happy path runs end-to-end (CLI/script/API): TBD
    - [ ] Primary outputs are verifiable (files/reports/history): `setup/rest/.rest_history` + report file path (TBD)
    - [ ] Usage docs skeleton exists (TL;DR + common commands + I/O contract): `skills/rest-api-testing/SKILL.md` (TBD)
- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Add optional URL omission controls for history/report command snippets (privacy / sharing).
    - [ ] Add better error printing (include response body on non-2xx when safe).
    - [ ] (Optional) Add request normalization knobs (e.g., bump numeric `limit` in query/body) if it proves useful.
  - Artifacts:
    - None
  - Exit Criteria:
    - [ ] Common branches are covered (e.g. missing env/token, 4xx/5xx, `--no-history`, replay): TBD
    - [ ] Compatible with existing project workflows (same `setup/*` conventions as other skills): TBD
    - [ ] Required migrations / backfill scripts and documentation exist: None
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Validate `rest.sh` against a real REST endpoint using an existing project’s `setup/rest/` (or create one for validation).
    - [ ] Validate report generation and default redaction behavior.
  - Artifacts:
    - `output/rest-api-testing/` (TBD: specific report paths)
  - Exit Criteria:
    - [ ] Validation and test commands executed with results recorded: TBD
    - [ ] Run with real data or representative samples (including failure + rerun after fix): TBD
    - [ ] Traceable evidence exists (logs, reports, command transcripts): `output/rest-api-testing/...` (TBD)
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Add the skill to the top-level `README.md` skills list.
    - [ ] After merge + validation, set Status to `DONE` and archive the progress file under `docs/progress/archived/`.
  - Artifacts:
    - `README.md`
    - `docs/progress/archived/20260108_rest-api-testing-skill.md` (TBD)
  - Exit Criteria:
    - [ ] Versioning and changes recorded: None
    - [ ] Release actions completed: None
    - [ ] Documentation completed and entry points updated (README / docs index links): `README.md` (TBD)
    - [ ] Cleanup completed (archive progress, update index, mark DONE): `docs/progress/README.md` + archived file (TBD)

## Modules

- `skills/rest-api-testing/SKILL.md`: End-user skill instructions (project layout, quickstart, safety, reporting rules).
- `skills/rest-api-testing/scripts/rest.sh`: Single entrypoint to run REST requests with env/token presets and history.
- `skills/rest-api-testing/scripts/rest-report.sh`: Report generator (runs or replays requests, redacts secrets by default).
- `skills/rest-api-testing/scripts/rest-history.sh`: History reader / replay helper.
- `skills/rest-api-testing/template/setup/rest`: Bootstrap template for per-project `setup/rest/`.
- `docs/templates/REST_API_TEST_OUTPUT_TEMPLATE.md`: Standard output contract for manual REST API test reports.
