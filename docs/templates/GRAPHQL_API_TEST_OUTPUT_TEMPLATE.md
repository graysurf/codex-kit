# GraphQL API Test Output Template

Use this template for the `graphql-api-testing` skill.

## Output rules

- Always state the target endpoint selection (`--env <name>` / `--url <url>` / `GQL_URL=<url>`).
- Reference the exact operation/variables files used (prefer `setup/graphql/operations/*.graphql` + `setup/graphql/operations/*.json`).
- Include the executed command(s) in fenced `bash` blocks (do not include secrets).
- When pasting JSON (variables/response), format it in a fenced `json` block (prefer `jq -S .`).
- Do not produce a “no data” report: ensure the response includes at least one real data record/value, unless an empty/no-data result is the test intent or correct behavior (confirm with the user; use `gql-report.sh --allow-empty` only in that case).
- If generating a test report file, write it under `docs/` and include:
  - GraphQL Operation (`graphql` block)
  - Variables (`json` block, formatted)
  - Response (`json` block, formatted; redact tokens/passwords unless explicitly requested)

## Preferred report flow

- Generate a report with a real response (prefer `--run`; or `--response <file>` for replay):
  - `$CODEX_HOME/skills/graphql-api-testing/scripts/gql-report.sh`
- Draft/empty reports are blocked unless explicitly allowed (`--allow-empty`).
- Default output dir is `<project root>/docs`; override with `GQL_REPORT_DIR`.
