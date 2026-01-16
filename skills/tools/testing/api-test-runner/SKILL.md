---
name: api-test-runner
description: Run CI-friendly API test suites (REST + GraphQL) from a single manifest, delegating to rest.sh/gql.sh and emitting JSON (+ optional JUnit) results. Use when the user asks to reduce CI boilerplate and provide a simple, composable suite runner for other tools (pytest/node/LLM) to call.
---

# API Test Runner (REST + GraphQL)

## Contract

Prereqs:

- `bash` and `jq` available on `PATH`.
- REST runner: `skills/tools/testing/rest-api-testing/scripts/rest.sh` (requires `curl`).
- GraphQL runner: `skills/tools/testing/graphql-api-testing/scripts/gql.sh` (requires `xh`/`http`/`curl`).

Inputs:

- Suite selection: `--suite <name>` or `--suite-file <path>`.
- Optional filters/flags: `--tag`, `--allow-writes`, `--out`, `--junit`.
- Optional auth secret env (when configured in suite): `API_TEST_AUTH_JSON` (or custom `secretEnv`).

Outputs:

- JSON results always emitted to stdout.
- Optional files: `--out <path>` (results JSON) and `--junit <path>` (JUnit XML).
- Per-run logs/artifacts under `out/api-test-runner/<runId>/` when executed.

Exit codes:

- `0`: all selected cases passed
- `2`: one or more cases failed
- `1`: invalid inputs / schema / missing files

Failure modes:

- Missing/invalid suite or case files (JSON schema errors, missing request/op files).
- Missing dependencies (`jq`, `curl`, or no supported GraphQL HTTP client).
- Auth missing/invalid (401/403) or write-capable case blocked by safety defaults.

## Goal

Run a suite of API checks in CI (and locally) via a single manifest file, reusing existing callers:

- REST: `skills/tools/testing/rest-api-testing/scripts/rest.sh`
- GraphQL: `skills/tools/testing/graphql-api-testing/scripts/gql.sh`

The runner:

- Executes selected cases deterministically
- Produces machine-readable JSON results (and optional JUnit XML)
- Applies safe defaults (no secret leakage; guardrails for write-capable cases)

## TL;DR

Bootstrap a minimal `setup/api/` (when your repo already has `setup/rest` and/or `setup/graphql`):

```bash
mkdir -p setup
cp -R "$CODEX_HOME/skills/tools/testing/api-test-runner/template/setup/api" setup/
```

Bootstrap a runnable public-endpoint smoke suite (includes `setup/api`, `setup/rest`, `setup/graphql`):

```bash
cp -R "$CODEX_HOME/skills/tools/testing/api-test-runner/template/setup" .
```

Run a canonical suite:

```bash
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh --suite smoke-demo --out out/api-test-runner/results.json
```

Emit JUnit for CI reporters:

```bash
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh --suite smoke-demo --junit out/api-test-runner/junit.xml
```

Generate a human-friendly summary (CI logs + `$GITHUB_STEP_SUMMARY`), based on the results JSON:

```bash
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test-summary.sh \
  --in out/api-test-runner/results.json \
  --out out/api-test-runner/summary.md \
  --slow 5
```

Hide skipped cases (optional):

```bash
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test-summary.sh \
  --in out/api-test-runner/results.json \
  --hide-skipped
```

## Suite Manifests

Canonical locations searched by `--suite`:

- `tests/api/suites/*.suite.json`
- (fallback) `setup/api/suites/*.suite.json` (used by the bundled template)

Runner entrypoints:

- `--suite <name>` → resolves to `tests/api/suites/<name>.suite.json` (fallback: `setup/api/suites/...`); override the search dir with `API_TEST_SUITES_DIR`
- `--suite-file <path>` → explicit suite file path (use when the suite manifest is not in a canonical suites dir)

Notes:

- REST cases point at `*.request.json` (same schema used by `rest.sh`).
- GraphQL cases point at `*.graphql` + variables `*.json` (same inputs used by `gql.sh`).
- Suite manifest location is independent from REST/GraphQL `configDir` (those can live under `tests/rest`, `tests/graphql`, etc).
- GraphQL write safety: if an operation file contains a `mutation` definition, the runner treats it as write-capable and requires `allowWrite=true` on the case.
- GraphQL default validation: when `allowErrors=false` and `expect.jq` is omitted, the runner requires `.data` to be a non-null object.
- Auth safety: `.auth.*.credentialsJq` must yield exactly one object (multiple matches fail fast).

### Suite schema v1

```json
{
  "version": 1,
  "name": "smoke",
  "defaults": {
    "env": "staging",
    "noHistory": true,
    "rest": { "configDir": "setup/rest", "url": "", "token": "" },
    "graphql": { "configDir": "setup/graphql", "url": "", "jwt": "" }
  },
  "cases": [
    {
      "id": "rest.health",
      "type": "rest",
      "tags": ["smoke"],
      "env": "",
      "noHistory": true,
      "allowWrite": false,
      "configDir": "",
      "url": "",
      "token": "",
      "request": "setup/rest/requests/health.request.json"
    },
    {
      "id": "rest.auth.login_then_me",
      "type": "rest-flow",
      "tags": ["smoke"],
      "env": "",
      "noHistory": true,
      "allowWrite": true,
      "configDir": "",
      "url": "",
      "loginRequest": "setup/rest/requests/login.request.json",
      "tokenJq": ".accessToken",
      "request": "setup/rest/requests/me.request.json"
    },
    {
      "id": "graphql.countries",
      "type": "graphql",
      "tags": ["smoke"],
      "env": "",
      "noHistory": true,
      "allowWrite": false,
      "allowErrors": false,
      "configDir": "",
      "url": "",
      "jwt": "",
      "op": "setup/graphql/operations/countries.graphql",
      "vars": "setup/graphql/operations/countries.variables.json",
      "expect": { "jq": "(.errors? | length // 0) == 0" }
    }
  ]
}
```

Notes:

- `defaults.*` are optional; per-case fields override `defaults`.
- `defaults.noHistory` (and case `noHistory`) map to `--no-history` on underlying `rest.sh` / `gql.sh`.
- `defaults.rest.configDir` / `defaults.graphql.configDir` default to `setup/rest` / `setup/graphql`.
- For REST and GraphQL endpoint selection, prefer `url` for CI determinism (avoids env preset drift).
- `rest-flow` runs `loginRequest` first, extracts a token (via `tokenJq`), then runs `request` with `ACCESS_TOKEN=<token>` (token is not printed in command snippets).

### Case cleanup (optional)

For write cases that create persistent resources (DB rows, uploaded files, etc), attach a `cleanup` block so the runner removes test artifacts after the case runs.

- `cleanup` can be an object (single step) or an array of steps.
- Each cleanup step must include `type`: `rest` or `graphql`.
- Cleanup steps run only when writes are allowed: `API_TEST_ALLOW_WRITES_ENABLED=true` (or `--allow-writes`) or when the effective `env` is `local`.

REST cleanup step fields:

- `method` (default: `DELETE`)
- `pathTemplate` (required; supports `{{var}}`)
- `vars` (optional): `{ "var": "<jq expr>" }` evaluated against the main response JSON
- `expectStatus` (or `expect.status`) optional; defaults to `204` for `DELETE`, otherwise `200`

GraphQL cleanup step fields:

- `op` (required)
- Variables (pick one):
  - `varsJq`: jq expression producing the variables object (evaluated against the main response JSON)
  - `varsTemplate` + `vars` (object mapping placeholders): `varsTemplate` is a JSON file that may contain `{{var}}` placeholders
  - `vars`: a variables JSON file path (static)
- `allowErrors` / `expect.jq`: same semantics as normal GraphQL cases (when `allowErrors=true`, `expect.jq` is required)

GraphQL create + delete example (cleanup uses the create response):

```json
{
  "id": "graphql.admin.createThing",
  "type": "graphql",
  "tags": ["write"],
  "allowWrite": true,
  "jwt": "admin",
  "op": "setup/graphql/operations/things.create.graphql",
  "vars": "setup/graphql/operations/things.create.variables.json",
  "expect": { "jq": ".data.createThing.thing.id != null" },
  "cleanup": {
    "type": "graphql",
    "op": "setup/graphql/operations/things.delete.graphql",
    "varsJq": "{ input: { id: .data.createThing.thing.id } }",
    "expect": { "jq": ".data.deleteThing.success == true" }
  }
}
```

REST cleanup example (delete by key extracted from the response):

```json
{
  "id": "rest.files.images.upload",
  "type": "rest",
  "tags": ["write"],
  "allowWrite": true,
  "token": "admin",
  "request": "setup/rest/requests/files.images.upload.request.json",
  "cleanup": {
    "type": "rest",
    "method": "DELETE",
    "pathTemplate": "/files/images/{{key}}",
    "vars": { "key": ".key" },
    "expectStatus": 204
  }
}
```

Note: `rest.sh` also supports per-request cleanup blocks; case-level `cleanup` is an alternative that can cover both REST + GraphQL in one suite.

## CI auth (GitHub Secrets / JWT login)

If your JWT expires, prefer logging in at runtime in CI using a suite-level `auth` block + a single JSON GitHub Secret.

How it works:

- You provide credentials via a JSON env var (default: `API_TEST_AUTH_JSON`).
- The runner logs in once per referenced profile (cached for the run) using either a REST or GraphQL login provider.
- For cases that specify `token` (REST) or `jwt` (GraphQL), the runner injects `ACCESS_TOKEN` for that case and does not rely on `tokens(.local).env` / `jwts(.local).env`.

Recommended secret schema (example):

```json
{
  "profiles": {
    "admin": { "username": "admin@example.com", "password": "..." },
    "member": { "username": "member@example.com", "password": "..." }
  }
}
```

Suite example (REST provider):

```json
{
  "version": 1,
  "name": "auth-smoke",
  "auth": {
    "provider": "rest",
    "secretEnv": "API_TEST_AUTH_JSON",
    "required": true,
    "rest": {
      "loginRequestTemplate": "setup/rest/requests/login.request.json",
      "credentialsJq": ".profiles[$profile] | select(.) | { username, password }",
      "tokenJq": ".accessToken"
    }
  },
  "defaults": {
    "noHistory": true,
    "rest": { "url": "https://<host>", "token": "member" },
    "graphql": { "url": "https://<host>/graphql", "jwt": "member" }
  },
  "cases": [
    { "id": "rest.me.member", "type": "rest", "token": "member", "request": "setup/rest/requests/me.request.json" },
    { "id": "graphql.me.admin", "type": "graphql", "jwt": "admin", "op": "setup/graphql/operations/me.graphql" }
  ]
}
```

Suite example (GraphQL provider):

```json
{
  "version": 1,
  "name": "auth-smoke",
  "auth": {
    "provider": "graphql",
    "secretEnv": "API_TEST_AUTH_JSON",
    "required": true,
    "graphql": {
      "loginOp": "setup/graphql/operations/login.ci.graphql",
      "loginVarsTemplate": "setup/graphql/operations/login.ci.variables.json",
      "credentialsJq": ".profiles[$profile] | select(.) | { email, password }",
      "tokenJq": ".. | objects | (.accessToken? // .access_token? // .token? // .jwt? // empty) | select(type==\"string\" and length>0) | ."
    }
  }
}
```

Defaults:

- Fail fast: if `auth` is configured but the secret env var is missing/empty, the runner exits `1` with a clear error.
- Optional override: set `auth.required=false` to disable suite auth when the secret is missing (useful for forks / local runs).

## Assertions

- REST: assertions live in the request file:
  - `expect.status` (required when `expect` is present)
  - `expect.jq` (optional; evaluated with `jq -e` against the JSON response)
- GraphQL:
  - Default: the runner enforces `.errors` is empty, plus optional per-case `expect.jq`.
  - `allowErrors: true`: skip the default no-errors check and rely on `expect.jq` (required) to assert the expected error(s), e.g. `.errors[0].extensions.code == "PHONE_VERIFICATION_INCOMPLETE"`.

## CLI flags

Core:

- `--suite <name>` / `--suite-file <path>`
- `--out <path>` (optional; JSON results file)
- `--junit <path>` (optional; JUnit XML)

Selection:

- `--only <id1,id2,...>`
- `--skip <id1,id2,...>`
- `--tag <tag>` (repeatable; all tags must match)

Control:

- `--fail-fast` (stop after first failure)
- `--continue` (continue after failures; default)

## CI examples

Generic shell (write JSON + JUnit as CI artifacts):

```bash
$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh \
  --suite smoke \
  --out out/api-test-runner/results.json \
  --junit out/api-test-runner/junit.xml
```

GitHub Actions (runs the bundled public smoke suite using the template bootstrap):

- Example workflow file: `.github/workflows/api-test-runner.yml`

If you want to run your own suite in CI, replace the bootstrap step with your repo’s committed `setup/api/`.

Notes:

- Keep `out/api-test-runner/results.json` as the primary machine-readable artifact.
- Only upload per-case response files as artifacts if they are known to be non-sensitive.

### GitHub Actions: matrix sharding by tags

For large suites, you can split a single suite into multiple CI jobs by tagging cases and running the runner in a matrix.

Suite tagging pattern (make shard tags mutually exclusive):

```json
{
  "cases": [
    { "id": "graphql.health", "type": "graphql", "tags": ["staging", "shard:0"], "op": "..." },
    { "id": "graphql.notifications", "type": "graphql", "tags": ["staging", "shard:1"], "op": "..." }
  ]
}
```

Workflow example:

```yaml
strategy:
  fail-fast: false
  matrix:
    shard: ["0", "1"]

steps:
  - name: Run suite shard
    env:
      CODEX_HOME: ${{ github.workspace }}
      API_TEST_AUTH_JSON: ${{ secrets.API_TEST_AUTH_JSON }}
    run: |
      skills/tools/testing/api-test-runner/scripts/api-test.sh \
        --suite my-suite \
        --tag staging \
        --tag "shard:${{ matrix.shard }}" \
        --out "out/api-test-runner/results.shard-${{ matrix.shard }}.json" \
        --junit "out/api-test-runner/junit.shard-${{ matrix.shard }}.xml"
```

Notes:

- `--tag` is repeatable and uses AND semantics (a case must include all tag filters to run).
- Make shard tags mutually exclusive to avoid duplicate coverage across jobs.
- Use per-shard output filenames to avoid artifact collisions.

## Safety defaults

Write-capable cases are denied by default.

- REST write detection: HTTP methods other than `GET`/`HEAD`/`OPTIONS`.
- GraphQL write detection: operation type `mutation` (best-effort).

Allow writes only when:

- The case has `allowWrite: true`, AND
- Either:
  - effective `env` is `local`, OR
  - the runner is invoked with `--allow-writes` (or `API_TEST_ALLOW_WRITES_ENABLED=true`).

## Results

- JSON results are always emitted to stdout (single JSON object). A one-line summary is emitted to stderr.
- Use `--out <path>` to also write the JSON results to a file.
- Use `--junit <path>` to write a JUnit XML report.

### Result JSON schema (v1)

Top-level fields:

- `version`: integer
- `suite`: suite name
- `suiteFile`: path to suite file (relative to repo root)
- `runId`: timestamp id
- `startedAt` / `finishedAt`: UTC timestamps
- `outputDir`: output directory (relative to repo root)
- `summary`: `{ total, passed, failed, skipped }`
- `cases[]`: per-case status objects

Per-case fields:

- `id`, `type`, `status` (`passed|failed|skipped`), `durationMs`
- `tags` (array)
- `command` (replayable snippet; no secrets)
- `message` (reason for fail/skip; stable-ish tokens)
- `assertions` (GraphQL only; includes `defaultNoErrors` and optional `jq`)
- `stdoutFile` / `stderrFile` (paths under `out/api-test-runner/<runId>/` when executed)

Exit codes:

- `0`: all selected cases passed
- `2`: one or more cases failed
- `1`: invalid inputs / schema / missing files

## References

- Guide: `skills/tools/testing/api-test-runner/references/API_TEST_RUNNER_GUIDE.md`
- Progress plan: `docs/progress/archived/20260109_ci-api-test-runner.md`
