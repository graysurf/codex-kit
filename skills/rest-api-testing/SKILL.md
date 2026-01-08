---
name: rest-api-testing
description: Test REST APIs with repeatable, file-based requests under <project>/setup/rest, with per-project endpoint and Bearer token presets, using the bundled rest.sh (xh/httpie/curl + jq). Use when the user asks to manually call REST endpoints, replay requests reliably, add CI-friendly assertions, and record API test reports.
---

# REST API Testing

## Goal

Make REST API calls reproducible and CI-friendly via:

- `setup/rest/requests/*.request.json` (request + optional `expect` assertions)
- `setup/rest/endpoints.env` (+ optional `endpoints.local.env`)
- `setup/rest/tokens.env` (+ optional `tokens.local.env`)
- `setup/rest/prompt.md` (optional, committed; project context for LLMs)

## TL;DR (fast paths)

Call an existing request (JSON only):

```bash
$CODEX_HOME/skills/rest-api-testing/scripts/rest.sh \
  --env local \
  setup/rest/requests/<request>.request.json \
| jq .
```

If the endpoint requires auth, pass a token profile (from `setup/rest/tokens.local.env`) or use `ACCESS_TOKEN`:

```bash
# Token profile (requires REST_TOKEN_<NAME> to be non-empty in setup/rest/tokens.local.env)
$CODEX_HOME/skills/rest-api-testing/scripts/rest.sh --env local --token default setup/rest/requests/<request>.request.json | jq .

# Or: one-off token (useful for CI)
REST_URL="https://<host>" ACCESS_TOKEN="<token>" \
  $CODEX_HOME/skills/rest-api-testing/scripts/rest.sh --url "$REST_URL" setup/rest/requests/<request>.request.json | jq .
```

Replay the last run (history):

```bash
$CODEX_HOME/skills/rest-api-testing/scripts/rest-history.sh --command-only
```

Generate a report (includes a replayable `## Command` by default):

```bash
$CODEX_HOME/skills/rest-api-testing/scripts/rest-report.sh \
  --case "<test case name>" \
  --request setup/rest/requests/<request>.request.json \
  --env local \
  --run
```

## Flow (decision tree)

- If `setup/rest/prompt.md` exists → read it first for project-specific context.
- No `setup/rest/` yet → bootstrap from template:
  - `cp -R "$CODEX_HOME/skills/rest-api-testing/template/setup/rest" setup/`
- Have request file → run with `rest.sh`.
- Need a markdown report → use `rest-report.sh --run` (or `--response`).

## Notes (defaults)

- History is on by default: `setup/rest/.rest_history` (gitignored); one-off disable with `--no-history` (or `REST_HISTORY=0`).
- Requests can embed CI-friendly assertions:
  - `expect.status` (integer; required when `expect` is present)
  - `expect.jq` (optional; evaluated with `jq -e` against the JSON response)
- Prefer `--config-dir setup/rest` in automation for deterministic discovery.

## References

- Full guide (project template): `skills/rest-api-testing/references/REST_API_TESTING_GUIDE.md`
- Report template: `docs/templates/REST_API_TEST_OUTPUT_TEMPLATE.md`
- Progress plan: `docs/progress/20260108_rest-api-testing-skill.md`
