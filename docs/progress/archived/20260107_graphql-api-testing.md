# codex-kit: GraphQL API testing skill

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-07 | 2026-01-17 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/6
- Docs: [skills/tools/testing/graphql-api-testing/SKILL.md](../../../skills/tools/testing/graphql-api-testing/SKILL.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Addendum

### 2026-01-17

- Change: Update archived path references for the skill scaffold (`template/` -> `assets/scaffold/`).
- Reason: The skills directory layout was normalized; keep DONE docs accurate and reduce search noise.
- Impact: Documentation-only; no runtime behavior changes.
- Links:
  - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql`
  - [docs/progress/archived/20260117_skills-layout-normalization-and-audit.md](20260117_skills-layout-normalization-and-audit.md)

## Goal

- Make manual GraphQL API calls reproducible using file-based operations/variables and per-repo endpoint/JWT presets.
- Provide a single caller (`gql.sh`) and a report generator (`gql-report.sh`) suitable for humans and LLMs.
- Reduce accidental secret/PII leakage by separating templates vs local overrides and default redaction in reports.

## Acceptance Criteria

- `skills/tools/testing/graphql-api-testing/scripts/gql.sh` can:
  - Resolve an endpoint via `--env <name>`, `--url <url>`, or `GQL_URL=<url>` (with `setup/graphql/endpoints.env` + optional `endpoints.local.env` presets).
  - Resolve an Authorization token via `--jwt <name>`, `GQL_JWT_NAME=<name>`, or `ACCESS_TOKEN` (with `setup/graphql/jwts.env` + optional `jwts.local.env` presets).
  - When a selected JWT profile is missing/empty, auto-run `login.graphql` under `setup/graphql/` and extract a token via `jq`.
  - Execute an operation file (and optional variables file) and print the response body to stdout.
- `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh` can:
  - Run an operation via `gql.sh` (or replay via `--response`) and write a Markdown report under `<project>/docs/` by default.
  - Redact `accessToken` / `refreshToken` / `password` fields by default; allow opting out with `--no-redact`.
  - Refuse to write a report when the response has no meaningful `.data` content unless `--allow-empty` (or `GQL_ALLOW_EMPTY`) is set.
- Bootstrap template exists under `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql` and includes:
  - `endpoints.env`, `jwts.env`, `.gitignore`, and a sample `operations/login.graphql` + variables files.
- Skill docs exist and reference `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_CONTRACT.md` for reporting.

## Scope

- In-scope:
  - File-based GraphQL operations and variables under `setup/graphql/`.
  - Endpoint presets and JWT profiles with local-only overrides.
  - CLI scripts: `gql.sh` (caller) and `gql-report.sh` (report generator).
  - Documentation templates for project setup and report output.
- Out-of-scope:
  - Subscriptions/WebSockets, file uploads, multipart GraphQL.
  - Schema introspection tooling, codegen, typed clients.
  - Automated integration tests against production/staging endpoints (project-owned).

## I/O Contract

### Input

- Operation: `setup/graphql/**/<name>.graphql`
- Variables (optional): `setup/graphql/**/<name>.json`
- Endpoint selection:
  - `--env <name>` (from `setup/graphql/endpoints.env` + optional `endpoints.local.env`), OR
  - `--url <url>` / `GQL_URL=<url>`
- Auth selection (optional):
  - `--jwt <name>` / `GQL_JWT_NAME=<name>` (from `setup/graphql/jwts.env` + optional `jwts.local.env`), OR
  - `ACCESS_TOKEN=<token>` (when no JWT profile is selected)

### Output

- `gql.sh`: prints the raw response body to stdout; exits non-zero on invalid inputs or HTTP errors.
- `gql-report.sh`: writes a Markdown report file (default: `<project root>/docs/<YYYYMMDD-HHMM>-<case>-api-test-report.md`) and prints the path to stdout.

### Intermediate Artifacts

- Config resolution: inferred `setup/graphql/` dir via `--config-dir` or upward search.
- Auto-login request/response used to extract a JWT when needed.
- (Optional) response snapshot files used for replay: `<operation>.response.json`

## Design / Decisions

### Rationale

- Use committed, file-based operations/variables to keep API tests reviewable and replayable.
- Store endpoint presets and JWT profiles in env-like files to keep per-repo configuration simple; keep secrets in `*.local.*` files that are easy to gitignore.
- Prefer `xh`/HTTPie for ergonomics, but keep a `curl + jq` fallback to minimize required tooling.
- Implement auto-login as a best-effort fallback to avoid blocking when tokens expire or are unavailable, while keeping credentials local-only.
- Enforce “no empty reports” by default to prevent low-signal docs and encourage deterministic test inputs; allow explicit override.

### Risks / Uncertainties

- Auto-login token extraction is heuristic (`accessToken` / `token` / direct string); projects with different shapes may need custom extraction.
- `xh`/HTTPie file argument semantics may vary across versions; curl fallback exists but requires `jq`.
- The “meaningful data” detector may misclassify some responses (e.g., boolean-only payloads); override via `--allow-empty`/`GQL_ALLOW_EMPTY` when appropriate.
- Windows portability is not a goal; scripts assume POSIX tools (`bash`, `sed`, `awk`, `jq`).

## Steps (Checklist)

Note: Any unchecked checkbox in this section must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete.

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Define the per-repo filesystem layout under `setup/graphql/` (operations/variables/endpoints/jwts).
    - [x] Define precedence rules for `--env`/`--url` and `--jwt`/`ACCESS_TOKEN`.
  - Artifacts:
    - `docs/progress/20260107_graphql-api-testing.md` (this file)
    - `skills/tools/testing/graphql-api-testing/SKILL.md`
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (this document is complete).
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Implement `gql.sh` caller with endpoint presets, JWT profiles, and curl fallback.
    - [x] Provide a bootstrap template under `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql`.
    - [x] Add a skill entry documenting the workflow and safety rules.
  - Artifacts:
    - `skills/tools/testing/graphql-api-testing/scripts/gql.sh`
    - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql/*`
    - `skills/tools/testing/graphql-api-testing/SKILL.md`
  - Exit Criteria:
    - [x] `bash -n skills/tools/testing/graphql-api-testing/scripts/gql.sh` passes.
    - [x] `skills/tools/testing/graphql-api-testing/scripts/gql.sh --help` prints usage.
- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Implement `gql-report.sh` to generate reproducible Markdown reports with redaction.
    - [x] Add project-local guide template for teams that want repo docs under `docs/`.
    - [x] Add report contract under `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_CONTRACT.md`.
  - Artifacts:
    - `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`
    - `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`
    - `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_CONTRACT.md`
  - Exit Criteria:
    - [x] `bash -n skills/tools/testing/graphql-api-testing/scripts/gql-report.sh` passes.
    - [x] `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh --help` prints usage.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Validate `gql.sh` against a real GraphQL endpoint using an existing project `setup/graphql/`:
      - Project: `MegabankTourism`
      - Config: `/Users/terry/Project/rytass/MegabankTourism/setup/graphql`
      - Operation: `/Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.graphql`
      - Variables: `/Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.variables.json`
      - Verified summary (non-empty): `{"hasErrors":false,"total":38,"items":5}`
    - [x] Validate report generation:
      - [x] Real run (`--run`) report generated (non-empty response)
      - [x] Redaction smoke test (`--response`) verified (`accessToken` / `refreshToken` / `password` -> `<REDACTED>`)
  - Artifacts:
    - `out/graphql-api-testing/megabanktourism/20260108-0119-megabanktourism-articles-local-api-test-report.md`
    - `out/graphql-api-testing/megabanktourism/20260108-0119-graphql-api-testing-redaction-smoke-test-api-test-report.md`
    - Command transcripts recorded under Exit Criteria
  - Exit Criteria:
    - [x] End-to-end call works and returns a non-empty `.data` response:
      - `skills/tools/testing/graphql-api-testing/scripts/gql.sh --config-dir /Users/terry/Project/rytass/MegabankTourism/setup/graphql --env local /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.graphql /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.variables.json | jq -c '{hasErrors: (.errors|length>0), total: (.data.articles.total//null), items: ((.data.articles.items|length)//0)}'`
      - `skills/tools/testing/graphql-api-testing/scripts/gql.sh --config-dir /Users/terry/Project/rytass/MegabankTourism/setup/graphql --env local --jwt force-login /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.graphql /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.variables.json | jq -c '{hasErrors: (.errors|length>0), total: (.data.articles.total//null), items: ((.data.articles.items|length)//0)}'`
    - [x] Report file generated with redaction verified:
      - `GQL_REPORT_DIR=out/graphql-api-testing/megabanktourism skills/tools/testing/graphql-api-testing/scripts/gql-report.sh --case "MegabankTourism Articles (local)" --op /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.graphql --vars /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.variables.json --env local --jwt force-login --config-dir /Users/terry/Project/rytass/MegabankTourism/setup/graphql --run`
      - `GQL_REPORT_DIR=out/graphql-api-testing/megabanktourism skills/tools/testing/graphql-api-testing/scripts/gql-report.sh --case "graphql-api-testing redaction smoke test" --op /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.graphql --vars /Users/terry/Project/rytass/MegabankTourism/setup/graphql/operations/articles.variables.json --response out/graphql-api-testing/megabanktourism/dummy-redaction.response.json`
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Add the skill to the top-level `README.md` skills list.
    - [x] After merge + validation, set Status to `DONE` and archive the progress file.
  - Artifacts:
    - `README.md`
    - `docs/progress/archived/20260107_graphql-api-testing.md`
  - Exit Criteria:
    - [x] README entry exists and points to the skill name.
    - [x] Progress file is archived and index updated.

## Modules

- `skills/tools/testing/graphql-api-testing/SKILL.md`: End-user skill instructions (project layout, quickstart, safety, reporting rules).
- `skills/tools/testing/graphql-api-testing/scripts/gql.sh`: Single entrypoint to run GraphQL operations with env/JWT presets and auto-login fallback.
- `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`: Report generator (runs or replays requests, redacts secrets, blocks empty reports).
- `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql`: Bootstrap template for per-project `setup/graphql/`.
- `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_CONTRACT.md`: Standard output contract for manual API test reports.
- `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`: Project-local guide template to copy into a repo.
