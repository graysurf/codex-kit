---
name: graphql-api-testing
description: Test GraphQL APIs with repeatable, file-based operations and variables under <project>/setup/graphql, with per-project endpoint presets in setup/graphql/endpoints.env, using the bundled gql.sh (xh/httpie/curl + jq). Use when the user asks to manually call GraphQL queries/mutations, fetch JWTs, replay requests reliably, and record API test reports.
---

# GraphQL API Testing

## Goal

Make GraphQL API calls reproducible (for humans and LLMs) by standardizing:

- Operation files: `setup/graphql/*.graphql`
- Variables files: `setup/graphql/*.json`
- Endpoint presets: `setup/graphql/endpoints.env` (+ optional `endpoints.local.env` overrides)
- JWT presets: `setup/graphql/jwts.env` (+ optional `jwts.local.env` with real tokens)
- A single caller: `$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh`

## Project conventions (per repo)

In each project, keep non-secret templates under `setup/graphql/` (commit these):

- `setup/graphql/login.graphql`
- `setup/graphql/login.variables.json`
- `setup/graphql/endpoints.env`
- `setup/graphql/jwts.env`

If credentials/tokens must be private, use local-only files (gitignored):

- `setup/graphql/*.local.json` (variables)
- `setup/graphql/endpoints.local.env` (endpoint overrides)
- `setup/graphql/jwts.local.env` (real JWTs)

## Project guide (optional)

If a repo wants a project-local markdown guide under `docs/`, copy the template and edit it:

```bash
cp "$CODEX_HOME/skills/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md" \
  "docs/backend/graphql-api-testing-guide.md"
```

## Quick start

1) Decide the endpoint.

- Prefer using `--env <name>` and define presets per project in `setup/graphql/endpoints.env`.
- For per-developer overrides (e.g. different local port), create `setup/graphql/endpoints.local.env` (keep it uncommitted).
- You can still override with `--url <url>` or `GQL_URL=<url>`.
- You can list presets with: `$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh --list-envs`

2) (Optional) Configure JWT profiles under `setup/graphql/`.

- Put non-secret placeholders in `setup/graphql/jwts.env` (commit this).
- Put real tokens in `setup/graphql/jwts.local.env` (gitignored).
- Select a profile with `--jwt <name>` or `GQL_JWT_NAME=<name>`.
- List profiles with: `$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh --list-jwts`

If no JWT is found for the selected profile, `gql.sh` falls back to calling `setup/graphql/login.graphql` to fetch one (requires `jq`).

3) Run an operation.

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  --jwt default \
  setup/graphql/<operation>.graphql \
  setup/graphql/<variables>.json \
| jq .
```

## Manual token export (optional)

If you prefer manual control, you can still call login and export `ACCESS_TOKEN`:

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  setup/graphql/login.graphql \
  setup/graphql/login.variables.json \
| jq .
```

Extract and reuse `accessToken` for subsequent calls:

```bash
export ACCESS_TOKEN="$(
  $CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
    --env local \
    setup/graphql/login.graphql \
    setup/graphql/login.variables.json \
  | jq -r '.data.<loginMutation>.accessToken'
)"
```

Authenticated call pattern:

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  setup/graphql/<operation>.graphql \
  setup/graphql/<variables>.json \
| jq .
```

## Reporting

When the user asks for a manual API test report, write it under `docs/` and include:

- Operation (`.graphql`)
- Variables (`.json`)
- Full JSON response (redact tokens/PII)

Prefer generating the report via script (auto-fills date + formats JSON):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql-report.sh \
  --case "<test case name>" \
  --op setup/graphql/<operation>.graphql \
  --vars setup/graphql/<variables>.json \
  --env <local|staging|dev> \
  --jwt <default|admin|...> \
  --run
```

Notes:

- `gql-report.sh` redacts `accessToken` / `refreshToken` / `password` by default; use `--no-redact` only if explicitly requested.
- Default report output dir is `<project root>/docs`; override with `GQL_REPORT_DIR` (relative paths are resolved from `<project root>`).

## Safety rules

- Do not paste JWTs/refresh tokens into committed docs; redact them.
- If an operation mutates data, confirm with the user before running it against shared/staging/prod.

## Output

- Follow `$CODEX_HOME/docs/templates/GRAPHQL_API_TEST_OUTPUT_TEMPLATE.md`.
