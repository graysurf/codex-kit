---
name: fr-psql
description: Run PostgreSQL queries through the fr-psql wrapper in ~/.codex/tools/fr-psql/fr-psql.zsh. Use when the user asks to query the FR Postgres database, inspect schemas/tables/columns, or execute SQL via fr-psql/psql using the FR_PG* environment.
---

# Fr-psql

## Overview

Use fr-psql to run psql against the FR database using the values in `~/.codex/tools/fr-psql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source ~/.codex/tools/fr-psql/fr-psql.zsh
```

2) Run a query.

```
fr-psql -c "SELECT 1;"
```

3) Run a file.

```
fr-psql -f /path/to/query.sql
```

## Verification Checks

Run a lightweight query to confirm connectivity and basic output.

```
fr-psql -c "SELECT current_database();"
```

If the function is missing, source the script again. If the connection fails, verify that all `FR_PG*` values exist in `~/.codex/tools/fr-psql/.env`.

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.
If a column or table name is unknown, inspect schema first with `information_schema` or `\d+`.
Do not print secrets from `.env` or echo `FR_PGPASSWORD`.

## Output and clarification rules

- Follow the shared template at `skills/_templates/sql-output.md`.
