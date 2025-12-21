---
name: tun-mssql
description: Run SQL Server queries through the tun-mssql wrapper in ~/.codex/tools/tun-mssql/tun-mssql.zsh. Use when the user asks to query the TUN MSSQL database, inspect schemas/tables/columns, or execute SQL via tun-mssql/sqlcmd using the TUN_MSSQL_* environment.
---

# Tun-mssql

## Overview

Use tun-mssql to run sqlcmd against the TUN SQL Server database using the values in `~/.codex/tools/tun-mssql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source ~/.codex/tools/tun-mssql/tun-mssql.zsh
```

2) Run a query.

```
tun-mssql -Q "SELECT 1;"
```

3) Run a file.

```
tun-mssql -i /path/to/query.sql
```

## Verification Checks

Run a lightweight query to confirm connectivity and basic output.

```
tun-mssql -Q "SELECT DB_NAME();"
```

If the function is missing, source the script again. If the connection fails, verify that all `TUN_MSSQL_*` values exist in `~/.codex/tools/tun-mssql/.env`.

## Common Tasks

List tables:

```
tun-mssql -Q "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_SCHEMA, TABLE_NAME;"
```

Describe table columns:

```
tun-mssql -Q "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'companies' ORDER BY ORDINAL_POSITION;"
```

Count distinct values:

```
tun-mssql -Q "SELECT COUNT(DISTINCT name) AS company_count FROM dbo.companies;"
```

Export CSV:

```
tun-mssql -s "," -W -Q "SET NOCOUNT ON; SELECT TOP 10 * FROM dbo.companies;"
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `MERGE`, `TRUNCATE`, or schema changes.
If a schema, table, or column name is unknown, inspect `INFORMATION_SCHEMA` first.
Do not print secrets from `.env` or echo `TUN_MSSQL_PASSWORD`.
