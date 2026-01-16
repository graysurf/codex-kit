# GraphQL API Testing Guide (Project Template)

Copy this file into your project and edit it to match your project-specific commands and operations.

Suggested destination:

- `docs/backend/graphql-api-testing-guide.md`

Copy command:

```bash
cp "$CODEX_HOME/skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md" \
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
- `setup/graphql/schema.env` (commit this; points to the schema SDL file)
- `setup/graphql/schema.gql` (commit this; schema SDL, recommended)
- `setup/graphql/prompt.md` (commit this; optional project context for LLMs)
- `setup/graphql/operations/*.graphql` operations (commit these)
- `setup/graphql/operations/*.json` variables (commit these, but keep secrets out)

Optional local-only overrides:

- `setup/graphql/endpoints.local.env` (do not commit; recommended to gitignore)
- `setup/graphql/jwts.local.env` (do not commit; real JWTs)
- `setup/graphql/schema.local.env` (do not commit; schema path override)
- `setup/graphql/gql.local.env` (do not commit; runtime toggles for history/report)
- `setup/graphql/operations/*.local.json` (do not commit; recommended to gitignore)
- `setup/graphql/.gql_history` (do not commit; command history)

### Project prompt (optional, for LLMs)

If you work with LLMs to generate operations/variables or to debug API behaviors, keep a short, factual prompt at:

- `setup/graphql/prompt.md`

Suggested contents (avoid secrets):

- What you want to test (features, key operations, expected invariants)
- Auth notes (how to obtain JWTs, required roles)
- DB tooling + structure (how to query, key tables/relations to verify)
- Other test utilities (admin UI, log dashboards, scripts, Postman/Bruno collections)

### Bootstrap (copy template)

To initialize `setup/graphql/` in a repo for the first time, copy the bundled template from Codex:

```bash
mkdir -p setup
cp -R "$CODEX_HOME/skills/tools/testing/graphql-api-testing/template/setup/graphql" setup/
```

The template includes a helper to turn a copied `gql.sh` history command into a report:

- `setup/graphql/api-report-from-cmd.sh` (requires `python3` or `python`)

Then fill local-only files (do not commit):

```bash
cp setup/graphql/jwts.local.env.example setup/graphql/jwts.local.env
cp setup/graphql/gql.local.env.example setup/graphql/gql.local.env
cp setup/graphql/operations/login.variables.local.json.example setup/graphql/operations/login.variables.local.json
```

Then edit committed project context (recommended if you use LLMs):

- `setup/graphql/prompt.md`

### Config discovery (setup_dir resolution)

Most commands assume a per-repo `setup/graphql/` directory. All scripts support `--config-dir setup/graphql`:

- `gql.sh` / `gql-report.sh` / `gql-history.sh` / `gql-schema.sh`

If `--config-dir` is omitted, scripts try to discover the setup dir by searching upward for known files (e.g. `endpoints.env`, `jwts.env`, `.gql_history`, `schema.env`).

Recommendation:

- In automation (LLM runs, CI-like scripts), always pass `--config-dir setup/graphql` for deterministic behavior.

### Runtime toggles (optional)

`setup/graphql/gql.local.env` is a convenience file for local runtime toggles (history/report). It is not loaded automatically.

- Load it in your shell:
  - `source setup/graphql/gql.local.env`
  - or via direnv (`.envrc`)

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

4) (Recommended) Configure schema (SDL)

If the repo commits its GraphQL schema SDL, LLMs can generate operations/variables even without separate API docs.

- Keep the schema file committed (recommended path: `setup/graphql/schema.gql`).
- Set the canonical path in `setup/graphql/schema.env` via `GQL_SCHEMA_FILE=...`.
  - If your repo keeps schema at repo root (e.g. `./schema.gql`): `GQL_SCHEMA_FILE=../../schema.gql`

Resolve the schema file path:

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-schema.sh --config-dir setup/graphql
```

Print the schema contents:

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-schema.sh --config-dir setup/graphql --cat
```

5) Prepare operation and variables files

Example structure:

- `setup/graphql/operations/login.graphql`
- `setup/graphql/operations/login.variables.json`

For list queries, prefer a reasonable page size to avoid “too little data” reports. By default, `gql.sh` / `gql-report.sh` normalize any numeric `limit` fields (including nested pagination inputs) to at least `GQL_VARS_MIN_LIMIT` (default: 5; set `GQL_VARS_MIN_LIMIT=0` to disable).

6) Call GraphQL operations (recommended: Codex skill script)

Tip: if you are not running from the repo root, add `--config-dir setup/graphql` to the commands below.

List envs:

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh --list-envs
```

List JWT profiles:

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh --list-jwts
```

Unauthenticated call (login):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh \
  --env local \
  setup/graphql/operations/login.graphql \
  setup/graphql/operations/login.variables.json \
| jq .
```

Authenticated call (select JWT profile; will auto-login if missing):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh \
  --env local \
  --jwt default \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq .
```

Manual token export (optional; example path, adjust to your schema):

```bash
export ACCESS_TOKEN="$(
  $CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh \
    --env local \
    setup/graphql/operations/login.graphql \
    setup/graphql/operations/login.variables.json \
  | jq -r '.data.<loginMutation>.accessToken'
)"
```

Authenticated call (ACCESS_TOKEN):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh \
  --env local \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq .
```

7) Generate a test report under `docs/`

Reports should include real data. If the response is empty and that’s not clearly intended/correct, adjust the query/variables (filters, time range, IDs) and re-run before writing the report.

```bash
export GQL_REPORT_DIR="docs" # optional (default: <project root>/docs; relative to <project root>)

$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-report.sh \
  --case "<test case name>" \
  --op setup/graphql/operations/<operation>.graphql \
  --vars setup/graphql/operations/<variables>.json \
  --env <local|staging|dev> \
  --jwt <default|admin|...> \
  --run
```

Use a saved response file instead of running (for replayability):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-report.sh \
  --case "<test case name>" \
  --op setup/graphql/operations/<operation>.graphql \
  --vars setup/graphql/operations/<variables>.json \
  --response setup/graphql/operations/<operation>.response.json
```

If you intentionally expect an empty/no-data result (or want a draft without running yet), pass `--allow-empty`.

If you already have a `gql.sh` command snippet (e.g. from `setup/graphql/.gql_history`), you can generate the report without manually rewriting it:

```bash
setup/graphql/api-report-from-cmd.sh '<paste a gql.sh command snippet>'
```

By default, `gql-report.sh` includes a copy/pasteable `gql.sh` command snippet in the report. Disable with `--no-command` or `GQL_REPORT_INCLUDE_COMMAND_ENABLED=false`. If the snippet uses `--url`, omit the URL value with `--no-command-url` or `GQL_REPORT_COMMAND_LOG_URL_ENABLED=false`.

8) CI / E2E (optional)

In CI, use `gql.sh` as the runner and `jq -e` as assertions (exit code is the contract):

```bash
set -euo pipefail

$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh \
  --config-dir setup/graphql \
  --env <local|staging|dev> \
  --jwt <default|admin|...> \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq -e '(.errors? | length // 0) == 0 and .data != null' >/dev/null
```

Notes:

- Many GraphQL servers return HTTP 200 even when `.errors` is present, so assert it explicitly.
- If you don’t want CI jobs to write history, add `--no-history` (or set `GQL_HISTORY_ENABLED=false`).

## Notes for stability

- Prefer “files + template command” (or `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh`) over ad-hoc one-liners: it reduces drift and quoting mistakes.
- If the repo commits its GraphQL schema SDL (recommended: `setup/graphql/schema.gql`), LLMs can generate operations/variables without separate API docs. Resolve it with:
  - `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-schema.sh --config-dir setup/graphql`
- `gql.sh` keeps a local history file at `setup/graphql/.gql_history` by default; extract the last entry for replay with:
  - `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-history.sh --command-only`
- History defaults and controls:
  - Defaults: enabled, logs both success/failure with exit code; rotates at 10 MB and keeps N old files.
  - One-off disable: `gql.sh --no-history ...`
  - Disable: `GQL_HISTORY_ENABLED=false`
  - Omit URL in history entries: `GQL_HISTORY_LOG_URL_ENABLED=false`
  - Size/rotation: `GQL_HISTORY_MAX_MB=10` (default), `GQL_HISTORY_ROTATE_COUNT=5`
- Variables defaults and controls:
  - If variables JSON contains numeric `limit` fields (including nested pagination inputs), scripts bump them to at least `GQL_VARS_MIN_LIMIT` (default: 5; set `GQL_VARS_MIN_LIMIT=0` to disable).
- Reports default to redacting common secrets (tokens/password fields). Use `gql-report.sh --no-redact` only when explicitly needed.
- Make test inputs deterministic when possible (avoid time-dependent filters unless explicitly testing them).
- Do not paste tokens/PII into reports; redact sensitive fields before committing.
- If an operation is a mutation (writes data), confirm before running it against shared/staging/prod environments.
