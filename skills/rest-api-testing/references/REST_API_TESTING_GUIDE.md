# REST API Testing Guide (Project Template)

Copy this file into your project and edit it to match your project-specific commands and requests.

Suggested destination:

- `docs/backend/rest-api-testing-guide.md`

Copy command:

```bash
cp "$CODEX_HOME/skills/rest-api-testing/references/REST_API_TESTING_GUIDE.md" \
  "docs/backend/rest-api-testing-guide.md"
```

## Purpose

This guide documents how to run manual API tests for a REST server and how to record results as a markdown report.

## Recommended tools

- CLI (repeatable calls): `xh` / HTTPie (`http`) / `curl`, plus `jq` for formatting and assertions.
- GUI clients (optional): Insomnia / Postman / Bruno (good for saved environments + collections).

## Project setup (per repo)

Store project-specific, non-secret templates under `setup/rest/`:

- `setup/rest/endpoints.env` (commit this)
- `setup/rest/tokens.env` (commit this; placeholders only)
- `setup/rest/prompt.md` (commit this; optional project context for LLMs)
- `setup/rest/requests/*.request.json` (commit these, but keep secrets out)

Optional local-only overrides:

- `setup/rest/endpoints.local.env` (do not commit; recommended to gitignore)
- `setup/rest/tokens.local.env` (do not commit; real tokens)
- `setup/rest/requests/*.local.json` (do not commit; recommended to gitignore)
- `setup/rest/.rest_history` (do not commit; command history)

### Bootstrap (copy template)

To initialize `setup/rest/` in a repo for the first time, copy the bundled template from Codex:

```bash
mkdir -p setup
cp -R "$CODEX_HOME/skills/rest-api-testing/template/setup/rest" setup/
```

## Request file schema (JSON only)

Each request lives at:

- `setup/rest/requests/<name>.request.json`

Schema:

- `method` (required; HTTP method, e.g. `GET`, `POST`)
- `path` (required; relative path only, starts with `/`, does not include scheme/host)
- `query` (optional; JSON object; encoded into URL query params)
- `headers` (optional; JSON object; Authorization is managed by CLI/token profiles)
- `body` (optional; JSON value; sent as request body)
- `expect` (optional; CI/E2E assertions):
  - `status` (required when `expect` is present; integer; typically `200`)
  - `jq` (optional; jq expression evaluated with `jq -e` against the JSON response)

## Steps

1) Start the API server (project-specific)

```bash
# Example
# yarn serve:api
```

2) Configure endpoint presets (local/staging/dev)

Edit `setup/rest/endpoints.env` to match your environments. Example:

```bash
REST_ENV_DEFAULT=local

REST_URL_LOCAL=http://localhost:<port>
# REST_URL_DEV=https://<dev-host>
# REST_URL_STAGING=https://<staging-host>
```

3) (Optional) Configure token profiles

Put placeholders in `setup/rest/tokens.env` and real tokens in `setup/rest/tokens.local.env` (gitignored). Example:

```bash
REST_TOKEN_DEFAULT="<your token>"
REST_TOKEN_ADMIN="<admin token>"
```

4) Call REST requests (recommended: Codex skill script)

Tip: if you are not running from the repo root, add `--config-dir setup/rest` to the commands below.

```bash
$CODEX_HOME/skills/rest-api-testing/scripts/rest.sh \
  --env local \
  --token default \
  setup/rest/requests/<request>.request.json \
| jq .
```

5) (Optional) Use built-in assertions for CI/E2E

Add `expect` to the request file:

```json
{
  "method": "GET",
  "path": "/health",
  "expect": { "status": 200, "jq": ".ok == true" }
}
```

Then run the request; the script should exit non-zero on assertion failure.

## Notes for stability

- Prefer “files + script” over ad-hoc one-liners: it reduces drift and quoting mistakes.
- Keep secrets out of request files; use `*.local.*` for local-only overrides.
