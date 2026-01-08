---
name: graphql-api-testing
description: Test GraphQL APIs with repeatable, file-based operations and variables under <project>/setup/graphql, with per-project endpoint presets in setup/graphql/endpoints.env, using the bundled gql.sh (xh/httpie/curl + jq). Use when the user asks to manually call GraphQL queries/mutations, fetch JWTs, replay requests reliably, and record API test reports.
---

# GraphQL API Testing

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
$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --env local \
  --jwt default \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq .
```

Generate a report (includes a replayable `## Command` by default):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql-report.sh \
  --case "<test case name>" \
  --op setup/graphql/operations/<operation>.graphql \
  --vars setup/graphql/operations/<variables>.json \
  --env local \
  --jwt default \
  --run
```

Replay the last run (history):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql-history.sh --command-only
```

Resolve committed schema SDL (for LLMs to author new operations):

```bash
$CODEX_HOME/skills/graphql-api-testing/scripts/gql-schema.sh --config-dir setup/graphql
```

## Flow (decision tree)

- If `setup/graphql/prompt.md` exists → read it first for project-specific context.
- No `setup/graphql/` yet → bootstrap from template:
  - `cp -R "$CODEX_HOME/skills/graphql-api-testing/template/setup/graphql" setup/`
- Have schema but no operation yet → resolve schema (`gql-schema.sh`) then add `setup/graphql/operations/<name>.graphql` + variables json.
- Have operation → run with `gql.sh`.
- Need a markdown report → use `gql-report.sh --run` (or `--response`).

## Notes (defaults)

- History is on by default: `setup/graphql/.gql_history` (gitignored); one-off disable with `--no-history` (or `GQL_HISTORY=0`).
- Reports include `## Command` by default; disable with `--no-command` (or `GQL_REPORT_INCLUDE_COMMAND=0`).
- Variables: any numeric `limit` fields (including nested pagination inputs) are normalized to at least `GQL_VARS_MIN_LIMIT` (default: 5; set `GQL_VARS_MIN_LIMIT=0` to disable).
- Prefer `--config-dir setup/graphql` in automation for deterministic discovery.

## CI / E2E (optional)

In CI, use `gql.sh` as the runner and `jq -e` as assertions (exit code is the contract):

```bash
set -euo pipefail

$CODEX_HOME/skills/graphql-api-testing/scripts/gql.sh \
  --config-dir setup/graphql \
  --env staging \
  --jwt ci \
  setup/graphql/operations/<operation>.graphql \
  setup/graphql/operations/<variables>.json \
| jq -e '(.errors? | length // 0) == 0 and .data != null' >/dev/null
```

Notes:

- Many GraphQL servers return HTTP 200 even when `.errors` is present, so assert it explicitly.
- If you don’t want CI jobs to write history, add `--no-history` (or set `GQL_HISTORY=0`).

## References

- Full guide (project template): `skills/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`
- Report template: `docs/templates/GRAPHQL_API_TEST_OUTPUT_TEMPLATE.md`
