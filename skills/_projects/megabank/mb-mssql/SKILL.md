---
name: mb-mssql
description: Run PostgreSQL queries through the mb-mssql wrapper in $CODEX_TOOLS_PATH/project/mb-mssql/mb-mssql.zsh. Use when the user asks to query the MB Postgres database, inspect schemas/tables/columns, or execute SQL via mb-mssql/psql using the MB_PG* environment.
---

# Mb-mssql

## Overview

Use mb-mssql to run psql against the MB database using the values in `$CODEX_TOOLS_PATH/project/mb-mssql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source $CODEX_TOOLS_PATH/project/mb-mssql/mb-mssql.zsh
```

2) Run a query.

```
mb-mssql -c "SELECT 1;"
```

3) Run a file.

```
mb-mssql -f /path/to/query.sql
```

## Verification Checks

Run a lightweight query to confirm connectivity and basic output.

```
mb-mssql -c "SELECT current_database();"
```

If the function is missing, source the script again. If the connection fails, verify that all `MB_PG*` values exist in `$CODEX_TOOLS_PATH/project/mb-mssql/.env`.

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.
If a column or table name is unknown, inspect schema first with `information_schema` or `\d+`.
Do not print secrets from `.env` or echo `MB_PGPASSWORD`.

## Output and clarification rules

- Follow the shared template at `$CODEX_HOME/docs/templates/SQL_OUTPUT_TEMPLATE.md`.
