# REST API Test Output Template

Use this template for the `rest-api-testing` skill.

## Output rules

- Always state the target endpoint selection (`--env <name>` / `--url <url>` / `REST_URL=<url>`).
- Reference the exact request file used (prefer `setup/rest/requests/*.request.json`).
- Include the executed command(s) in fenced `bash` blocks (do not include secrets).
- When pasting JSON (request/response), format it in a fenced `json` block (prefer `jq -S .`).
- If the request includes `expect`, record whether assertions passed:
  - `expect.status`
  - `expect.jq` (if present)
- Do not paste tokens/PII into reports; redact sensitive fields unless explicitly requested.

## Preferred report flow

- Generate a report with a real response (prefer `--run`; or `--response <file>` for replay):
  - `$CODEX_HOME/skills/tools/testing/rest-api-testing/scripts/rest-report.sh`
- Default output dir is `<project root>/docs`; override with `REST_REPORT_DIR`.
