---
name: qbmysql
description: Run MySQL queries through the qbmysql wrapper in ~/.codex/tools/qbmysql/qbmysql.sh. Use when the user asks to query the QB MySQL database, inspect schemas/tables/columns, or execute SQL via qbmysql/mysql using the QB_MYSQL_* environment.
---

# Qbmysql

## Overview

Use qbmysql to run mysql against the QB database using the values in `~/.codex/tools/qbmysql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source ~/.codex/tools/qbmysql/qbmysql.sh
```

2) Run a query.

```
qbmysql -e "SELECT 1;"
```

3) Run a file.

```
qbmysql < /path/to/query.sql
```

## Verification Checks

Run a lightweight query to confirm connectivity and basic output.

```
qbmysql -e "SELECT DATABASE();"
```

If the function is missing, source the script again. If the connection fails, verify that all `QB_MYSQL_*` values exist in `~/.codex/tools/qbmysql/.env`.

## Common Tasks

List tables:

```
qbmysql -e "SHOW TABLES;"
```

Describe table columns:

```
qbmysql -e "DESCRIBE companies;"
```

Portable column listing:

```
qbmysql -e "SELECT column_name FROM information_schema.columns WHERE table_name = 'companies' ORDER BY ordinal_position;"
```

Count distinct values:

```
qbmysql -e "SELECT COUNT(DISTINCT name) AS company_count FROM companies;"
```

Export CSV:

```
qbmysql --batch --raw -e "SELECT * FROM companies LIMIT 10;"
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.
If a column or table name is unknown, inspect schema first with `information_schema` or `DESCRIBE`.
Do not print secrets from `.env` or echo `QB_MYSQL_PASSWORD`.
