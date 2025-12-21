---
name: fr-api-doc-playbook
description: Test FinanceReport GraphQL APIs and produce API docs with real responses. Use when asked to run or validate FinanceReport GraphQL queries/mutations, obtain JWTs, verify data with fr-psql, or draft API documentation from actual API responses.
---

# FinanceReport API Doc Playbook

## Load the playbook

- Read `../../Project/rytass/FinanceReport/setup/fr-api-doc-playbook.md` relative to `~/.config/codex-kit` (default cwd).
- Do not proceed until the file is fully read. If missing or cwd differs, resolve the absolute path or ask.

## Follow it exactly

- Use the playbook steps for env setup, JWT login, API startup, curl requests, and doc format.
- Keep full JSON responses; do not truncate or paraphrase.
- If errors occur, fix and re-run until a successful response is obtained before writing docs.

## Source of truth

- The playbook is authoritative; do not improvise alternative flows unless asked.
