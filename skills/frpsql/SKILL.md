---
name: frpsql
description: Run PostgreSQL queries through the frpsql wrapper in ~/.codex/tools/frpsql/frpsql.sh. Use when the user asks to query the FR Postgres database, inspect schemas/tables/columns, or execute SQL via frpsql/psql using the FR_PG* environment.
---

# Frpsql

## Overview

Use frpsql to run psql against the FR database using the values in `~/.codex/tools/frpsql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source ~/.codex/tools/frpsql/frpsql.sh
```

2) Run a query.

```
frpsql -c "SELECT 1;"
```

3) Run a file.

```
frpsql -f /path/to/query.sql
```

## Verification Checks

Run a lightweight query to confirm connectivity and basic output.

```
frpsql -c "SELECT current_database();"
```

If the function is missing, source the script again. If the connection fails, verify that all `FR_PG*` values exist in `~/.codex/tools/frpsql/.env`.

## Common Tasks

List tables:

```
frpsql -c '\dt'
```

Describe table columns:

```
frpsql -c '\d+ companies'
```

Portable column listing:

```
frpsql -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'companies' ORDER BY ordinal_position;"
```

Count distinct values:

```
frpsql -c "SELECT COUNT(DISTINCT name) AS company_count FROM companies;"
```

Export CSV:

```
frpsql -c '\copy (SELECT * FROM companies LIMIT 10) TO STDOUT WITH CSV HEADER'
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.
If a column or table name is unknown, inspect schema first with `information_schema` or `\d+`.
Do not print secrets from `.env` or echo `FR_PGPASSWORD`.
