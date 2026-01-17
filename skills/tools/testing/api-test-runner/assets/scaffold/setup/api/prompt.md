# API Test Runner Prompt (Project Context)

This file is optional. If present, the `api-test-runner` skill can use it for project-specific context.

Keep it short, factual, and non-secret (do not paste real tokens, passwords, API keys, or customer data).

## Suites

- What suites exist (e.g. `smoke`, `read-only`, `write-local-only`):
- How to run in CI (which suite name + required env vars):

## Safety

- Which cases are write-capable (REST non-GET, GraphQL `mutation`):
- When writes are allowed (local only / explicit CI gates):

## Environments / Auth

- Where endpoints live (local/dev/staging/prod) and how CI provides URLs/tokens:
- Any constraints (rate limits, auth expiry, IP allowlists):
