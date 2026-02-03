---
name: rest-api-testing
description: Test REST APIs with repeatable, file-based requests under <project>/setup/rest, with per-project endpoint and Bearer token presets, using the bundled api-rest CLI. Use when the user asks to manually call REST endpoints, replay requests reliably, add CI-friendly assertions, and record API test reports.
---

# REST API Testing

## Contract

Prereqs:

- `api-rest` available on `PATH` (install via `brew install nils-cli`).
- `jq` recommended for pretty-printing/assertions (optional).
- `setup/rest/` exists (or bootstrap from template) with requests and optional endpoint/token presets.

Inputs:

- Request file path: `setup/rest/requests/<name>.request.json`.
- Optional flags/env (runner): `--env`, `--url`, `--token`, `--config-dir`, `--no-history` (plus `REST_URL`, `ACCESS_TOKEN`,
  `REST_JWT_VALIDATE_ENABLED`, `REST_JWT_VALIDATE_STRICT`, `REST_JWT_VALIDATE_LEEWAY_SECONDS`).

Outputs:

- Response JSON (or raw response) printed to stdout; errors printed to stderr.
- Optional history file under `setup/rest/.rest_history` (gitignored; disabled via `--no-history`).
- Optional markdown report via `api-rest report`.

Exit codes:

- `0`: request completed successfully (and assertions, if present, passed)
- non-zero: invalid inputs/missing files/http error/assertion failure

Failure modes:

- Missing `curl`, invalid request JSON, or missing endpoint configuration (`REST_URL` / endpoints env).
- Auth missing/invalid (`ACCESS_TOKEN` / token profile) causing 401/403.
- Network/timeout/connection failures.

## Goal

Make REST API calls reproducible and CI-friendly via:

- `setup/rest/requests/*.request.json` (request + optional `expect` assertions)
- `setup/rest/endpoints.env` (+ optional `endpoints.local.env`)
- `setup/rest/tokens.env` (+ optional `tokens.local.env`)
- `setup/rest/prompt.md` (optional, committed; project context for LLMs)

## TL;DR (fast paths)

Call an existing request (JSON only):

```bash
api-rest call \
  --env local \
  setup/rest/requests/<request>.request.json \
| jq .
```

If the endpoint requires auth, pass a token profile (from `setup/rest/tokens.local.env`) or use `ACCESS_TOKEN`:

```bash
# Token profile (requires REST_TOKEN_<NAME> to be non-empty in setup/rest/tokens.local.env)
api-rest call --env local --token default setup/rest/requests/<request>.request.json | jq .

# Or: one-off token (useful for CI)
REST_URL="https://<host>" ACCESS_TOKEN="<token>" \
  api-rest call --url "$REST_URL" setup/rest/requests/<request>.request.json | jq .
```

Replay the last run (history):

```bash
api-rest history --command-only
```

Generate a report (includes a replayable `## Command` by default):

```bash
api-rest report \
  --case "<test case name>" \
  --request setup/rest/requests/<request>.request.json \
  --env local \
  --run
```

Generate a report from a copied `api-rest`/`rest.sh` command snippet (no manual rewriting):

```bash
api-rest report-from-cmd '<paste an api-rest/rest.sh command snippet>'
```

## Flow (decision tree)

- If `setup/rest/prompt.md` exists → read it first for project-specific context.
- No `setup/rest/` yet → bootstrap from template:
  - `cp -R "$CODEX_HOME/skills/tools/testing/rest-api-testing/assets/scaffold/setup/rest" setup/`
- Have request file → run with `api-rest call`.
- Need a markdown report → use `api-rest report --run` (or `--response`).

## Notes (defaults)

- History is on by default: `setup/rest/.rest_history` (gitignored); one-off disable with `--no-history` (or `REST_HISTORY_ENABLED=false`).
- Requests can embed CI-friendly assertions:
  - `expect.status` (integer; required when `expect` is present)
  - `expect.jq` (optional; evaluated with `jq -e` against the JSON response)
- Reports redact common secret-like fields by default (e.g. `Authorization`, `Cookie`, `accessToken`); use `--no-redact` only when necessary.
- Prefer `--config-dir setup/rest` in automation for deterministic discovery.

## References

- Full guide (project template): `skills/tools/testing/rest-api-testing/references/REST_API_TESTING_GUIDE.md`
- Report contract: `skills/tools/testing/rest-api-testing/references/REST_API_TEST_REPORT_CONTRACT.md`
- Report template: `skills/tools/testing/rest-api-testing/references/REST_API_TEST_REPORT_TEMPLATE.md`
- Progress plan: `docs/progress/20260108_rest-api-testing-skill.md`
