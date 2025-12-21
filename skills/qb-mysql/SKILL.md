---
name: qb-mysql
description: Run MySQL queries through the qb-mysql wrapper in ~/.codex/tools/qb-mysql/qb-mysql.zsh. Use when the user asks to query the QB MySQL database, inspect schemas/tables/columns, or execute SQL via qb-mysql/mysql using the QB_MYSQL_* environment.
---

# Qb-mysql

## Overview

Use qb-mysql to run mysql against the QB database using the values in `~/.codex/tools/qb-mysql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source ~/.codex/tools/qb-mysql/qb-mysql.zsh
```

2) Run a query.

```
qb-mysql -e "SELECT 1;"
```

3) Run a file.

```
qb-mysql < /path/to/query.sql
```

## Verification Checks

Run a lightweight query to confirm connectivity and basic output.

```
qb-mysql -e "SELECT DATABASE();"
```

If the function is missing, source the script again. If the connection fails, verify that all `QB_MYSQL_*` values exist in `~/.codex/tools/qb-mysql/.env`.

## Common Tasks

List tables:

```
qb-mysql -e "SHOW TABLES;"
```

Describe table columns:

```
qb-mysql -e "DESCRIBE companies;"
```

Portable column listing:

```
qb-mysql -e "SELECT column_name FROM information_schema.columns WHERE table_name = 'companies' ORDER BY ordinal_position;"
```

Count distinct values:

```
qb-mysql -e "SELECT COUNT(DISTINCT name) AS company_count FROM companies;"
```

Export CSV:

```
qb-mysql --batch --raw -e "SELECT * FROM companies LIMIT 10;"
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.
If a column or table name is unknown, inspect schema first with `information_schema` or `DESCRIBE`.
Do not print secrets from `.env` or echo `QB_MYSQL_PASSWORD`.
