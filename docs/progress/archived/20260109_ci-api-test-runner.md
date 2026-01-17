# codex-kit: CI API test runner (REST + GraphQL)

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-09 | 2026-01-17 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/12
- Planning PR: https://github.com/graysurf/codex-kit/pull/11
- Docs: [skills/tools/testing/api-test-runner/SKILL.md](../../../skills/tools/testing/api-test-runner/SKILL.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Addendum

### 2026-01-17

- Change: Update archived path references for the skill scaffold (`template/` -> `assets/scaffold/`).
- Reason: The skills directory layout was normalized; keep DONE docs accurate and reduce search noise.
- Impact: Documentation-only; no runtime behavior changes.
- Links:
  - `skills/tools/testing/api-test-runner/assets/scaffold/setup/api`
  - [docs/progress/archived/20260117_skills-layout-normalization-and-audit.md](20260117_skills-layout-normalization-and-audit.md)

## Goal

- Provide a lightweight, CI-friendly suite runner that executes REST and GraphQL API checks by calling existing runners (`rest.sh`, `gql.sh`).
- Reduce CI boilerplate via a single manifest-driven command, deterministic selection, and machine-readable JSON results consumable by other tools (including LLMs).
- Keep safety by default: no secret leakage in logs/results, and guardrails against unintended write operations in shared environments.

## Acceptance Criteria

- A new runner script exists (proposed: `skills/tools/testing/api-test-runner/scripts/api-test.sh`) that can run a suite manifest and exits non-zero when any case fails.
- Suite manifests can include both REST and GraphQL cases and support shared defaults (environment name, auth profile names, history toggles).
- Results are emitted in a machine-readable format (JSON to stdout and/or `--out <file>`), including per-case status, duration, and a replayable command snippet (without secrets).
- GraphQL cases include a default assertion that `.errors` is empty, plus optional `expect.jq` assertions.
- A bootstrap template exists so a repo can commit `setup/api/` and run CI with one command.

## Scope

- In-scope:
  - A new `api-test-runner` skill (docs + scripts + templates) that runs suites for REST and GraphQL by delegating to `rest.sh` / `gql.sh`.
  - Suite manifest schema v1 (JSON) with case defaults, per-case overrides, deterministic ordering, and selection filters (`--only`, `--tag`, `--skip`).
  - CI-friendly execution contract: stable exit codes + machine-readable JSON results.
  - Safety defaults: no token values in logs, and explicit opt-in required for write-capable cases in CI/shared envs.
- Out-of-scope:
  - Replacing standard test frameworks (JUnit/Pytest/Jest/etc); this runner is a small, composable harness.
  - Parallel execution, per-case timeouts, and retries/backoff (follow-up PR).
  - Multi-step scenario chaining (extract from response -> feed into next request).
  - REST multipart/file upload and REST API-key header auth (still separate REST TODOs).

## I/O Contract

### Input

- Suite manifest: `setup/api/suites/<suite>.suite.json` (committed)
- REST inputs: `setup/rest/endpoints.env`, `setup/rest/tokens.env`, `setup/rest/requests/*.request.json`
- GraphQL inputs: `setup/graphql/endpoints.env`, `setup/graphql/jwts.env`, `setup/graphql/operations/*.graphql`, `setup/graphql/operations/*.json`
- Secrets in CI: via env (e.g. `ACCESS_TOKEN`, `REST_URL`, `GQL_URL_*`) or local-only `*.local.env` files

### Output

- Runner stdout:
  - Machine-readable JSON (structured results; schema defined in this plan)
- Runner stderr:
  - Human-readable summary (stable enough for logs)
- Optional result file via `--out <path>` (recommended for CI artifacts), defaulting under `out/api-test-runner/`
- Exit code:
  - `0` when all selected cases pass
  - non-zero when any case fails or when inputs are invalid (exact codes defined in Step 0)

### Intermediate Artifacts

- Temporary response files (per case) for assertions and optional debugging (default location under `out/api-test-runner/<run-id>/`).

### Suite Manifest (proposed schema v1)

Location (recommended, committed):

- `setup/api/suites/<suite>.suite.json`

Example:

```json
{
  "version": 1,
  "name": "smoke",
  "defaults": {
    "env": "staging",
    "noHistory": true,
    "rest": { "token": "ci" },
    "graphql": { "jwt": "ci" }
  },
  "cases": [
    {
      "id": "rest.health",
      "type": "rest",
      "request": "setup/rest/requests/health.request.json"
    },
    {
      "id": "graphql.countries",
      "type": "graphql",
      "op": "setup/graphql/operations/countries.graphql",
      "vars": "setup/graphql/operations/countries.variables.json",
      "expect": {
        "jq": "(.errors? | length // 0) == 0 and (.data.countries | length) > 0"
      }
    }
  ]
}
```

Notes:

- REST assertions live in the request file (`expect.status` + optional `expect.jq`); suite-level `expect.jq` is optional (extra checks).
- GraphQL cases should at minimum enforce “no `.errors`” (runner default), plus optional `expect.jq` for stronger checks.

### Result JSON (proposed schema v1)

Example output (stdout and/or `--out` file):

```json
{
  "version": 1,
  "suite": "smoke",
  "runId": "20260109-010000Z",
  "startedAt": "2026-01-09T01:00:00Z",
  "finishedAt": "2026-01-09T01:00:10Z",
  "summary": { "total": 2, "passed": 2, "failed": 0, "skipped": 0 },
  "cases": [
    {
      "id": "rest.health",
      "type": "rest",
      "status": "passed",
      "durationMs": 120,
      "command": "$CODEX_HOME/skills/tools/testing/rest-api-testing/scripts/rest.sh --config-dir setup/rest --env staging setup/rest/requests/health.request.json"
    },
    {
      "id": "graphql.countries",
      "type": "graphql",
      "status": "passed",
      "durationMs": 240,
      "command": "$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh --config-dir setup/graphql --env staging --jwt ci setup/graphql/operations/countries.graphql setup/graphql/operations/countries.variables.json | jq -e '...'",
      "assertions": {
        "defaultNoErrors": "passed",
        "jq": "passed"
      }
    }
  ]
}
```

## Design / Decisions

### Rationale

- Reuse existing stable callers (`skills/tools/testing/rest-api-testing/scripts/rest.sh`, `skills/tools/testing/graphql-api-testing/scripts/gql.sh`) instead of re-implementing HTTP/auth logic.
- Keep assertions simple and composable (`expect.*` for REST, `jq -e` for GraphQL), so the runner can be called from CI scripts or higher-level tools.
- Prefer deterministic, machine-readable outputs over a “full test framework” feature set.

### Decisions (locked)

- Suite location/discovery (Q1 = C):
  - Canonical location: `setup/api/suites/*.suite.json`
  - Runner supports both:
    - `--suite <name>` (resolves to canonical path), and
    - `--suite-file <path>` (explicit override)
  - In CI: prefer canonical (`--suite`) or explicit `--suite-file` for deterministic runs; avoid discovery-only behavior.
- Safety gating for write-capable cases (Q2 = A + B):
  - Default: deny write-capable cases.
  - Allow writes only when the case is explicitly marked `allowWrite: true`, AND:
    - `env=local`, OR
    - runner is invoked with `--allow-writes` (or `API_TEST_ALLOW_WRITES=1`).
- Results contract (Q3 = B):
  - Always emit JSON results.
  - Optionally emit JUnit XML via `--junit <file>` for CI reporters.

### Risks / Uncertainties

- Network flakiness / rate limits can cause CI noise.
  - Mitigation: define timeouts; optionally add retries/backoff as a follow-up (explicitly gated and off by default).
- Side effects in shared environments (REST non-GET, GraphQL mutations).
  - Mitigation: require explicit opt-in for write-capable cases (e.g. `allowWrite: true` per case and/or `--allow-writes` flag).
- Project-specific naming drift (env names, auth profile names).
  - Mitigation: support suite-level defaults + per-case overrides; document recommended naming alignment (`local`, `dev`, `staging`, etc.).

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Finalize suite manifest schema v1 (fields, defaults, per-case overrides).
    - [x] Finalize runner CLI flags and stable exit code semantics.
    - [x] Finalize result JSON schema (per-case + summary) and redaction rules.
    - [x] Decide safety defaults (history behavior in CI, write-case gating, response capture policy).
  - Artifacts:
    - `docs/progress/20260109_ci-api-test-runner.md` (this file)
    - Example suite manifest + example result JSON snippet (embedded in this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (manifest + JSON results + safe defaults).
    - [x] Data flow and I/O contract are defined (suite -> rest/gql -> assertions -> results).
    - [x] Risks and safety guardrails are defined (write gating, redaction).
    - [x] Minimal reproducible verification commands are defined (public endpoints for REST + GraphQL).
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Create `skills/tools/testing/api-test-runner/` (docs + scripts + templates).
    - [x] Implement `api-test.sh` to run a suite manifest sequentially.
    - [x] Support case type `rest` by invoking `rest.sh` (respecting request `expect`).
    - [x] Support case type `graphql` by invoking `gql.sh` and applying default + optional `expect.jq` assertions.
    - [x] Emit machine-readable results (JSON) and meaningful exit codes.
  - Artifacts:
    - `skills/tools/testing/api-test-runner/SKILL.md`
    - `skills/tools/testing/api-test-runner/scripts/api-test.sh`
    - `skills/tools/testing/api-test-runner/assets/scaffold/setup/api/` (suite manifest + sample cases)
    - `README.md` (skills list entry)
  - Exit Criteria:
    - [x] At least one happy path runs end-to-end (suite runner): `api-test.sh --suite <suite>`.
    - [x] Primary outputs are verifiable (results JSON and optional saved responses) under `out/api-test-runner/`.
    - [x] Usage docs skeleton exists (TL;DR + suite schema + CI example): `skills/tools/testing/api-test-runner/SKILL.md`.
- [ ] Step 2: Expansion / integration
  - Reason: Timeouts/retries/parallel are deferred to a follow-up PR; this PR focuses on the core suite runner and JSON/JUnit contracts.
  - Work Items:
    - [x] Add selection and control flags: `--only`, `--tag`, `--skip`, `--fail-fast`, `--continue`.
    - [x] Add deterministic ordering guarantees and clearer error reporting for invalid suite schemas.
    - [ ] Add timeouts (and optional retries as a gated follow-up if needed).
      - Reason: Deferred to a follow-up PR (timeouts/retries/parallel and richer reporting).
    - [x] Add CI example snippets (GitHub Actions / generic shell) for both REST and GraphQL suites.
  - Artifacts:
    - `skills/tools/testing/api-test-runner/SKILL.md` (expanded)
    - Optional: `skills/tools/testing/api-test-runner/references/API_TEST_RUNNER_GUIDE.md`
  - Exit Criteria:
    - [x] Common branches are covered (missing files, invalid schema, assertion fail, skip/only, underlying runner error).
    - [x] Compatible with existing naming conventions (`setup/rest`, `setup/graphql`, `*.local.env`, `out/`).
    - [x] Required migrations / backfill scripts and documentation exist: none required.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Validate the runner against public endpoints:
      - REST: `https://httpbin.org`
      - GraphQL: `https://countries.trevorblades.com/`
    - [x] Validate failure behavior (intentional failing assertion and non-zero exit code).
  - Artifacts:
    - `out/api-test-runner/` (run logs + results JSON)
  - Exit Criteria:
    - [x] Validation commands executed with results recorded (happy path + failure case).
    - [x] Run with real data or representative samples (public endpoints; no secrets).
    - [x] Traceable evidence exists (results JSON files under `out/api-test-runner/`).

Validation evidence (local runs; artifacts are gitignored under `out/`):

```bash
# Happy path
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh \
  --suite smoke-demo \
  --out out/api-test-runner/smoke-demo.results.json \
  --junit out/api-test-runner/smoke-demo.junit.xml

# Selection example (filters are deterministic; unselected cases become skipped)
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh --suite smoke-demo --only rest.httpbin.get

# Failure path (intentional failing expect.jq; exits 2)
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh \
  --suite public-fail \
  --out out/api-test-runner/public-fail.results.json \
  --junit out/api-test-runner/public-fail.junit.xml
```

Observed summaries:

- `smoke-demo`: `passed=2 failed=0 skipped=0` (runId: `20260108-180931Z`)
- `public-fail`: `passed=1 failed=1 skipped=0` (runId: `20260108-180950Z`, exit `2`)
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Add the new skill to `README.md`.
    - [x] After merge + validation, set progress Status to `DONE` and archive under `docs/progress/archived/`.
  - Artifacts:
    - `README.md`
    - `docs/progress/archived/20260109_ci-api-test-runner.md` (after merge)
  - Exit Criteria:
    - [x] Versioning and changes recorded: none required.
    - [x] Release actions completed: none required.
    - [x] Documentation completed and entry points updated (README / docs index links).
    - [x
    ] Cleanup completed (archive progress, update index, mark DONE).

## Modules

- `skills/tools/testing/api-test-runner/scripts/api-test.sh`: Suite runner that executes REST/GraphQL cases and produces JSON results.
- `skills/tools/testing/api-test-runner/SKILL.md`: End-user docs (suite schema, examples, CI usage, safety rules).
- `skills/tools/testing/api-test-runner/assets/scaffold/setup/api`: Bootstrap template for committing `setup/api/` suite manifests in projects.
