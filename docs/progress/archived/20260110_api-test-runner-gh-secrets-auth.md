# codex-kit: API test runner: CI auth via GitHub Secrets (JWT login)

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-10 | 2026-01-17 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/14
- Planning PR: https://github.com/graysurf/codex-kit/pull/13
- Docs: [skills/tools/testing/api-test-runner/SKILL.md](../../../skills/tools/testing/api-test-runner/SKILL.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)
- Downstream validation (real project): https://github.com/Rytass/TunGroup/actions/runs/20879442172

## Addendum

### 2026-01-17

- Change: Update archived path references for the skill scaffold (`template/` -> `assets/scaffold/`).
- Reason: The skills directory layout was normalized; keep DONE docs accurate and reduce search noise.
- Impact: Documentation-only; no runtime behavior changes.
- Links:
  - `skills/tools/testing/api-test-runner/assets/scaffold/setup/api/suites`
  - [docs/progress/archived/20260117_skills-layout-normalization-and-audit.md](20260117_skills-layout-normalization-and-audit.md)

## Goal

- Ensure CI runs always use fresh JWTs by logging in at runtime using GitHub Secrets (avoid expired tokens and validate auth/permissions early).
- Support multiple auth profiles (e.g. admin/member) from a single JSON secret, and allow projects to choose REST or GraphQL login providers.
- Keep safety-by-default: never leak credentials/JWTs in stdout, JSON results, command snippets, or uploaded artifacts.

## Acceptance Criteria

- `skills/tools/testing/api-test-runner/scripts/api-test.sh` supports an optional suite-level `auth` block that enables runtime login using a single JSON secret env var (default: `API_TEST_AUTH_JSON`).
- Default behavior: if `auth` is configured but the secret env var is missing/empty, the runner fails fast with a clear error (no silent skipping).
- Multi-profile auth is supported: the runner detects which profiles are needed for the selected cases and logs in once per profile (cached for the run).
- Both login providers are supported (suite can use either):
  - REST login provider (build a temporary `*.request.json`, call `rest.sh`, extract token via `tokenJq`).
  - GraphQL login provider (build a temporary `*.variables.json`, call `gql.sh`, extract token via `tokenJq`).
- When `auth` is enabled, cases can reference a profile by using existing fields:
  - REST: `defaults.rest.token` and/or `cases[].token`
  - GraphQL: `defaults.graphql.jwt` and/or `cases[].jwt`
  And the runner injects the matching `ACCESS_TOKEN` for that case without requiring `tokens.local.env` / `jwts.local.env` files.
- Backwards compatible: suites without `auth` behave exactly as today (including using `--token/--jwt` profiles backed by `tokens(.local).env` / `jwts(.local).env`).
- `.github/workflows/api-test-runner.yml` includes a documented example job that passes `API_TEST_AUTH_JSON` (and gates the job when the secret is missing).
- No secret leakage:
  - Runner JSON output includes no tokens/passwords (verify via grep/jq checks).
  - No login response bodies are written under `out/api-test-runner/**` by default.

## Scope

- In-scope:
  - Extend suite schema v1 with optional `auth` configuration (no breaking changes).
  - Implement runtime login + token injection in `skills/tools/testing/api-test-runner/scripts/api-test.sh`.
  - Minor compatibility fixes in `skills/tools/testing/graphql-api-testing/scripts/gql.sh` required by downstream CI usage.
  - Provide an example suite + workflow snippet that demonstrate multi-profile auth using a single JSON secret.
  - Update docs (`skills/tools/testing/api-test-runner/SKILL.md` and guide) to document:
    - Secret JSON schema (recommended)
    - Suite `auth` configuration (REST / GraphQL provider)
    - CI usage patterns (single job vs matrix/tag selection)
- Out-of-scope:
  - Changes to `skills/tools/testing/rest-api-testing/scripts/rest.sh`.
  - Non-Bearer auth schemes (API keys, cookies, session auth), refresh-token flows, MFA/OTP, or browser-based logins.
  - Persisting tokens across jobs/runs; each CI job logs in independently.
  - Parallel execution, retries/backoff, and per-case timeouts (follow-up work).

## I/O Contract

### Input

- Suite manifest: `setup/api/suites/<suite>.suite.json`
- Secret (CI): `API_TEST_AUTH_JSON` (GitHub Secret exposed to the job env as a JSON string)
- Optional provider templates (committed; no secrets):
  - REST provider:
    - Login request template: `setup/rest/requests/login.request.json`
    - `auth.rest.credentialsJq`: jq expression that returns an object to merge into `.body`
    - `auth.rest.tokenJq`: jq expression evaluated against the login response JSON to extract the token
  - GraphQL provider:
    - Login operation: `setup/graphql/operations/login.graphql`
    - Login variables template: `setup/graphql/operations/login.variables.json`
    - `auth.graphql.credentialsJq`: jq expression that returns an object to merge into the variables JSON
    - `auth.graphql.tokenJq`: jq expression evaluated against the GraphQL response JSON to extract the token
- Existing runner env overrides (unchanged): `API_TEST_REST_URL`, `API_TEST_GQL_URL`, `API_TEST_ALLOW_WRITES`, etc.

### Output

- Standard runner outputs (unchanged):
  - JSON results to stdout
  - Optional JSON file via `--out <path>` (recommended: `out/api-test-runner/*.json`)
  - Optional JUnit file via `--junit <path>`
  - Per-case response/stderr files under `out/api-test-runner/<runId>/` (excluding login provider outputs by default)

### Intermediate Artifacts

- Temp files created by the runner and removed after use:
  - Generated REST login request JSON (per profile)
  - Generated GraphQL login variables JSON (per profile)
- In-memory map: `profile -> access token` for the current run.

### Suite Auth Block (proposed schema additions)

Example (illustrative; exact fields to be finalized in Step 0):

```json
{
  "version": 1,
  "name": "auth-smoke",
  "auth": {
    "required": true,
    "secretEnv": "API_TEST_AUTH_JSON",
    "provider": "rest",
    "rest": {
      "loginRequestTemplate": "setup/rest/requests/login.request.json",
      "credentialsJq": ".profiles[$profile] | select(.) | { username, password }",
      "tokenJq": ".accessToken // .token // .jwt"
    },
    "graphql": {
      "loginOp": "setup/graphql/operations/login.graphql",
      "loginVarsTemplate": "setup/graphql/operations/login.variables.json",
      "credentialsJq": ".profiles[$profile] | select(.) | { email, password }",
      "tokenJq": ".data.login.accessToken // .data.login.token // .. | .accessToken? // .token? // empty"
    }
  },
  "defaults": {
    "rest": { "token": "member" },
    "graphql": { "jwt": "member" }
  },
  "cases": [
    { "id": "rest.me.member", "type": "rest", "token": "member", "request": "setup/rest/requests/me.request.json" },
    { "id": "graphql.me.admin", "type": "graphql", "jwt": "admin", "op": "setup/graphql/operations/me.graphql" }
  ]
}
```

## Design / Decisions

### Rationale

- Keep `rest.sh` and `gql.sh` unchanged: they remain the stable per-protocol callers, while `api-test.sh` becomes the single place that knows about CI auth/secrets and multi-profile needs.
- Use a single JSON secret (`API_TEST_AUTH_JSON`) to support many accounts/roles without requiring many GitHub Secrets or workflow edits.
- Use `jq`-based extraction and patching to adapt to project-specific login input shapes without hardcoding username/email/password conventions.
- Prefer per-case `ACCESS_TOKEN` injection (no token files) to reduce the chance of accidentally uploading tokens as artifacts.

### Risks / Uncertainties

- Project-specific login shapes vary (REST body vs GraphQL variables names; token field name/location).
  - Mitigation: suite-level `credentialsJq` + `tokenJq` are required; provide worked examples and validation errors that point to the failing profile/provider.
- Some auth flows require multi-step or additional headers (CSRF, OTP, captcha, device binding).
  - Mitigation: explicitly out-of-scope for this iteration; document constraints and recommended workarounds (pre-provisioned tokens via `ACCESS_TOKEN` for local-only debugging).
- GitHub Secrets JSON formatting/escaping pitfalls (newlines/quotes).
  - Mitigation: document a recommended schema + show a minimal, single-line JSON example; ensure the runner parses via `jq` from stdin.
- Accidental secret leakage (stderr, saved response files, command snippets).
  - Mitigation: never print the secret env var; do not persist login response bodies by default; mask sensitive args in command snippets; add a post-run “redaction check” recipe.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Align on constraints: single JSON secret; support REST and GraphQL login providers; do not change `rest.sh` / `gql.sh`.
    - [x] Align on implementation locus: add functionality to `api-test.sh` + update workflow template (no feature implementation in this PR).
    - [x] Define a proposed suite `auth` block shape and a recommended secret schema (documented in this file).
  - Artifacts:
    - `docs/progress/20260110_api-test-runner-gh-secrets-auth.md` (this file)
    - Example schema snippet + verification recipes (embedded in this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (see sections above).
    - [x] Data flow and I/O contract are defined (suite -> pre-login -> per-case token injection -> results).
    - [x] Risks and mitigations are documented (see “Risks / Uncertainties”).
    - [x] Minimal verification recipes are defined (see Step 3 Exit Criteria).
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Extend `api-test.sh` to parse optional `auth` block and resolve needed profiles from selected cases.
    - [x] Implement REST login provider:
      - Build temp login request JSON by merging credentials from `API_TEST_AUTH_JSON` via `credentialsJq`.
      - Call `rest.sh` and extract token via `tokenJq`.
    - [x] Implement GraphQL login provider:
      - Build temp login variables JSON by merging credentials from `API_TEST_AUTH_JSON` via `credentialsJq`.
      - Call `gql.sh` and extract token via `tokenJq`.
    - [x] Inject `ACCESS_TOKEN` per case when its `token/jwt` matches a resolved profile (do not pass `--token/--jwt` in that mode).
    - [x] Update `.github/workflows/api-test-runner.yml` with an auth suite example job gated on `API_TEST_AUTH_JSON`.
    - [x] Update docs (`skills/tools/testing/api-test-runner/SKILL.md` + guide) with the new `auth` config and CI snippets.
  - Artifacts:
    - `skills/tools/testing/api-test-runner/scripts/api-test.sh`
    - `.github/workflows/api-test-runner.yml`
    - `skills/tools/testing/api-test-runner/SKILL.md`
    - `skills/tools/testing/api-test-runner/references/API_TEST_RUNNER_GUIDE.md`
    - `skills/tools/testing/api-test-runner/assets/scaffold/setup/api/suites/*.suite.json` (new example suite)
  - Exit Criteria:
    - [x] A suite using `auth` can run end-to-end when `API_TEST_AUTH_JSON` is provided.
      - Command: `skills/tools/testing/api-test-runner/scripts/api-test.sh --suite <auth-suite> --out out/api-test-runner/results.json`
    - [x] Runner output and artifacts contain no credential/JWT leakage (see Step 3 checks).
    - [x] Docs include a copy/paste CI snippet and the recommended secret JSON schema.
- [ ] Step 2: Expansion / integration
  - Reason: Optional follow-ups; core goal is validated in a downstream real project and can be shipped as-is.
  - Work Items:
    - [x] Implement the decided default: `auth` configured + secret missing -> fail fast with a clear error.
    - [ ] ~~(Optional follow-up) Add a mode to skip auth-required cases when secret is missing.~~ Reason: prefer explicit workflow gating; keep fail-fast default.
    - [x] Improve error messages for `credentialsJq` / `tokenJq` failures (include provider+profile context; never echo secret values).
    - [ ] ~~Add deterministic ordering for pre-login (stable by profile name) and explicit caching semantics.~~ Reason: case order is already deterministic; caching is per-profile per-run.
    - [x] Add docs/examples for matrix runs (split suite by `--tag` for parallelism).
  - Artifacts:
    - `skills/tools/testing/api-test-runner/scripts/api-test.sh`
    - `skills/tools/testing/api-test-runner/SKILL.md`
  - Exit Criteria:
    - [x] Common branches are covered: missing secret, missing profile, login fail, token extraction fail, selection filters.
    - [x] Compatible with existing runner behavior (no `auth` block unchanged).
    - [x] Required migrations/backfills: None.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Local validation with a real `API_TEST_AUTH_JSON` (demo API):
      - Run an auth suite and confirm REST and/or GraphQL cases pass for at least two profiles.
    - [x] Safety validation (no leakage):
      - Ensure results JSON does not contain known token substrings.
      - Ensure command snippets do not contain secrets.
      - Ensure workflow artifacts do not include per-case response bodies by default.
  - Artifacts:
    - `out/api-test-runner/*.json` (results)
    - `out/api-test-runner/<runId>/*.stderr.log` (errors only; no secrets)
  - Exit Criteria:
    - [x] Commands executed with results recorded (local or CI):
      - `API_TEST_AUTH_JSON='...' skills/tools/testing/api-test-runner/scripts/api-test.sh --suite <auth-suite> --out out/api-test-runner/auth.results.json`
    - [x] Leakage checks pass (examples; adapt as needed):
      - `jq -r '..|strings|select(test(\"eyJ\"))' out/api-test-runner/auth.results.json` returns no output
      - `rg -n \"API_TEST_AUTH_JSON|Authorization: Bearer\" out/api-test-runner -S` returns no output
    - [x] Evidence exists (results JSON + CI logs) and is linked from the implementation PR (downstream: Rytass/TunGroup CI run).
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Ship implementation PR(s); update this progress file status to `DONE`; move to `docs/progress/archived/` via `close-progress-pr`.
  - Artifacts:
    - `docs/progress/archived/20260110_api-test-runner-gh-secrets-auth.md`
  - Exit Criteria:
    - [x] Versioning and changes recorded: None (no tracked `version.json` / `CHANGELOG` in this repo).
    - [x] Release actions completed: None (repo-local tooling change; no tag required unless desired).
    - [x] Documentation completed and entry points updated: `skills/tools/testing/api-test-runner/SKILL.md`, `docs/progress/README.md`.
    - [x] Cleanup completed: progress status `DONE`, archived file moved, follow-ups captured.

## Modules

- `skills/tools/testing/api-test-runner/scripts/api-test.sh`: suite auth parsing, pre-login, per-case token injection, and no-leak guarantees.
- `.github/workflows/api-test-runner.yml`: CI example(s) for `API_TEST_AUTH_JSON`-driven login and multi-profile coverage.
- `skills/tools/testing/api-test-runner/SKILL.md`: user-facing documentation for `auth` block and CI usage.
