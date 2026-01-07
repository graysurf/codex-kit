# GraphQL API Testing Guide (Project Template)

Copy this file into your project and edit it to match your project-specific commands and operations.

Suggested destination:

- `docs/backend/graphql-api-testing-guide.md`

Copy command:

```bash
cp "$CODEX_HOME/skills/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md" \
  "docs/backend/graphql-api-testing-guide.md"
```

## Purpose

This guide documents how to run manual API tests for a GraphQL server and how to record results as a markdown report.

## Recommended tools

- Browser (exploration): open your GraphQL endpoint in a browser to use Apollo Sandbox (docs, autocomplete, history).
- CLI (repeatable calls): HTTPie (`http`) or `xh`, plus `jq` for formatting and extracting fields.
- GUI clients (optional): Insomnia / Postman / Bruno (good for saved environments + collections).

## Project setup (per repo)

Store project-specific, non-secret templates under `setup/graphql/`:

- `setup/graphql/endpoints.env` (commit this)
- `setup/graphql/jwts.env` (commit this; placeholders only)
- `setup/graphql/operations/*.graphql` operations (commit these)
- `setup/graphql/operations/*.json` variables (commit these, but keep secrets out)

Optional local-only overrides:

- `setup/graphql/endpoints.local.env` (do not commit; recommended to gitignore)
- `setup/graphql/jwts.local.env` (do not commit; real JWTs)
- `setup/graphql/operations/*.local.json` (do not commit; recommended to gitignore)
- `setup/graphql/.gql_history` (do not commit; command history)

### Bootstrap (copy template)

To initialize `setup/graphql/` in a repo for the first time, copy the bundled template from Codex:

```bash
mkdir -p setup
cp -R "$CODEX_HOME/skills/graphql-api-testing/template/setup/graphql" setup/
```

Then fill local-only files (do not commit):

```bash
cp setup/graphql/jwts.local.env.example setup/graphql/jwts.local.env
cp setup/graphql/operations/login.variables.local.json.example setup/graphql/operations/login.variables.local.json
```

## Steps

1) Start the API server (project-specific)

```bash
# Example
# yarn serve:api
```

2) Configure endpoint presets (local/staging/dev)

Edit `setup/graphql/endpoints.env` to match your environments. Example:

```bash
GQL_ENV_DEFAULT=local

GQL_URL_LOCAL=http://localhost:<port>/graphql
# GQL_URL_DEV=https://<dev-host>/graphql
# GQL_URL_STAGING=https://<staging-host>/graphql
```

3) (Optional) Configure JWT profiles

Put placeholders in `setup/graphql/jwts.env` and real tokens in `setup/graphql/jwts.local.env` (gitignored). Example:

```bash
GQL_JWT_DEFAULT="<your token>"
GQL_JWT_ADMIN="<admin token>"
```

Select a profile with `--jwt <name>` (or `GQL_JWT_NAME=<name>`; you can also put `GQL_JWT_NAME=<name>` in `jwts.local.env`). If the selected JWT is missing/empty, `gql.sh` falls back to calling `setup/graphql/operations/login.graphql` to fetch one (requires `jq`).

4) Prepare operation and variables files

Example structure:

- `setup/graphql/operations/login.graphql`
- `setup/graphql/operations/login.variables.json`

5) Call GraphQL operations (recommended: Codex skill script)

List envs:

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh --list-envs
```

List JWT profiles:

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh --list-jwts
```

Unauthenticated call (login):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  setup/graphql/operations/login.graphql \
  setup/graphql/operations/login.variables.json \
| jq .
```

Authenticated call (select JWT profile; will auto-login if missing):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  --jwt default \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq .
```

Manual token export (optional; example path, adjust to your schema):

```bash
export ACCESS_TOKEN="$(
  $CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
    --env local \
    setup/graphql/operations/login.graphql \
    setup/graphql/operations/login.variables.json \
  | jq -r '.data.<loginMutation>.accessToken'
)"
```

Authenticated call (ACCESS_TOKEN):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq .
```

6) Generate a test report under `docs/`

Reports should include real data. If the response is empty and that’s not clearly intended/correct, adjust the query/variables (filters, time range, IDs) and re-run before writing the report.

```bash
export GQL_REPORT_DIR="docs" # optional (default: <project root>/docs; relative to <project root>)

$CODEX_HOME/skills/graphql-api-testing/scripts/gql-report.sh \
  --case "<test case name>" \
  --op setup/graphql/operations/<operation>.graphql \
  --vars setup/graphql/operations/<variables>.json \
  --env <local|staging|dev> \
  --jwt <default|admin|...> \
  --run
```

Use a saved response file instead of running (for replayability):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql-report.sh \
  --case "<test case name>" \
  --op setup/graphql/operations/<operation>.graphql \
  --vars setup/graphql/operations/<variables>.json \
  --response setup/graphql/operations/<operation>.response.json
```

If you intentionally expect an empty/no-data result (or want a draft without running yet), pass `--allow-empty`.

By default, `gql-report.sh` includes a copy/pasteable `gql.sh` command snippet in the report. Disable with `--no-command` or `GQL_REPORT_INCLUDE_COMMAND=0`. If the snippet uses `--url`, omit the URL value with `--no-command-url` or `GQL_REPORT_COMMAND_LOG_URL=0`.

## Notes for stability

- Prefer “files + template command” (or `$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh`) over ad-hoc one-liners: it reduces drift and quoting mistakes.
- Make test inputs deterministic when possible (avoid time-dependent filters unless explicitly testing them).
- Do not paste tokens/PII into reports; redact sensitive fields before committing.
