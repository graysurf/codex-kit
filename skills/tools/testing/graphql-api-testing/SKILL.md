---
name: graphql-api-testing
description: Test GraphQL APIs with repeatable, file-based operations and variables under <project>/setup/graphql, with per-project endpoint presets in setup/graphql/endpoints.env, using the bundled api-gql binary. Use when the user asks to manually call GraphQL queries/mutations, fetch JWTs, replay requests reliably, and record API test reports.
---

# GraphQL API Testing

## Contract

Prereqs:

- `$CODEX_HOME/skills/tools/testing/graphql-api-testing/bin/api-gql` available (or `api-gql` on `PATH`).
- `jq` recommended for pretty-printing/assertions (optional).
- `setup/graphql/` exists (or bootstrap from template) with operations, vars, and optional endpoint/jwt presets.

Inputs:

- Operation + variables: `setup/graphql/operations/<op>.graphql` and `setup/graphql/operations/<vars>.json`.
- Optional flags/env: `--env`, `--url`, `--jwt`, `--config-dir`, `--no-history` (plus `GQL_URL`, `ACCESS_TOKEN`,
  `GQL_JWT_VALIDATE_ENABLED`, `GQL_JWT_VALIDATE_STRICT`, `GQL_JWT_VALIDATE_LEEWAY_SECONDS`).

Outputs:

- Response JSON printed to stdout; errors printed to stderr.
- Optional history file under `setup/graphql/.gql_history` (gitignored; disabled via `--no-history`).
- Optional markdown report via `api-gql report`.

Exit codes:

- `0`: request completed successfully
- non-zero: invalid inputs/missing files/http error/client error

Failure modes:

- Invalid GraphQL/variables JSON, or missing config files.
- Auth missing/invalid (JWT) or network/timeout/connection failures.

## Goal

Make GraphQL API calls reproducible via:

- `setup/graphql/operations/*.graphql` + `*.json` (operations + variables)
- `setup/graphql/endpoints.env` (+ optional `endpoints.local.env`)
- `setup/graphql/jwts.env` (+ optional `jwts.local.env`)
- `setup/graphql/schema.env` (+ committed schema SDL, e.g. `schema.gql`)
- `setup/graphql/prompt.md` (optional, committed; project context for LLMs: what to test, DB tooling, other test utilities)

## TL;DR (fast paths)

Call an existing operation:

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/bin/api-gql call \
  --env local \
  --jwt default \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq .
```

Generate a report (includes a replayable `## Command` by default):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/bin/api-gql report \
  --case "<test case name>" \
  --op setup/graphql/operations/<operation>.graphql \
  --vars setup/graphql/operations/<variables>.json \
  --env local \
  --jwt default \
  --run
```

Generate a report from a copied `api-gql`/`gql.sh` command snippet (no manual rewriting):

```bash
$CODEX_HOME/commands/api-report-from-cmd '<paste an api-gql/gql.sh command snippet>'
```

If your repo bootstrapped `setup/graphql/` from the template, you can also use:

- `setup/graphql/api-report-from-cmd.sh '<paste an api-gql/gql.sh command snippet>'`

Replay the last run (history):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/bin/api-gql history --command-only
```

Resolve committed schema SDL (for LLMs to author new operations):

```bash
$CODEX_HOME/skills/tools/testing/graphql-api-testing/bin/api-gql schema --config-dir setup/graphql
```

## Flow (decision tree)

- If `setup/graphql/prompt.md` exists → read it first for project-specific context.
- No `setup/graphql/` yet → bootstrap from template:
- `cp -R "$CODEX_HOME/skills/tools/testing/graphql-api-testing/assets/scaffold/setup/graphql" setup/`
- Have schema but no operation yet → resolve schema (`api-gql schema`) then add `setup/graphql/operations/<name>.graphql` + variables json.
- Have operation → run with `api-gql call`.
- Need a markdown report → use `api-gql report --run` (or `--response`).

## Notes (defaults)

- History is on by default: `setup/graphql/.gql_history` (gitignored); one-off disable with `--no-history` (or `GQL_HISTORY_ENABLED=false`).
- Reports include `## Command` by default; disable with `--no-command` (or `GQL_REPORT_INCLUDE_COMMAND_ENABLED=false`).
- Variables: any numeric `limit` fields (including nested pagination inputs) are normalized to at least `GQL_VARS_MIN_LIMIT` (default: 5; set `GQL_VARS_MIN_LIMIT=0` to disable).
- Prefer `--config-dir setup/graphql` in automation for deterministic discovery.

## CI / E2E (optional)

In CI, use `api-gql call` as the runner and `jq -e` as assertions (exit code is the contract):

```bash
set -euo pipefail

$CODEX_HOME/skills/tools/testing/graphql-api-testing/bin/api-gql call \
  --config-dir setup/graphql \
  --env staging \
  --jwt ci \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq -e '(.errors? | length // 0) == 0 and .data != null' >/dev/null
```

Notes:

- Many GraphQL servers return HTTP 200 even when `.errors` is present, so assert it explicitly.
- If you don’t want CI jobs to write history, add `--no-history` (or set `GQL_HISTORY_ENABLED=false`).

## References

- Full guide (project template): `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`
- Report contract: `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_CONTRACT.md`
- Report template: `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TEST_REPORT_TEMPLATE.md`
