---
name: tun-mssql
description: Run SQL Server queries through the tun-mssql wrapper in $CODEX_TOOLS_PATH/project/tun-mssql/tun-mssql.zsh. Use when the user asks to query the TUN MSSQL database, inspect schemas/tables/columns, or execute SQL via tun-mssql/sqlcmd using the TUN_MSSQL_* environment.
---

# Tun-mssql

## Overview

Use tun-mssql to run sqlcmd against the TUN SQL Server database using the values in `$CODEX_TOOLS_PATH/project/tun-mssql/.env`. Favor read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Ensure the function is available.

```
source $CODEX_TOOLS_PATH/project/tun-mssql/tun-mssql.zsh
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

If the function is missing, source the script again. If the connection fails, verify that all `TUN_MSSQL_*` values exist in `$CODEX_TOOLS_PATH/project/tun-mssql/.env`.

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `MERGE`, `TRUNCATE`, or schema changes.
If a schema, table, or column name is unknown, inspect `INFORMATION_SCHEMA` first.
Do not print secrets from `.env` or echo `TUN_MSSQL_PASSWORD`.

## Output and clarification rules

- Follow the shared template at `$CODEX_HOME/docs/templates/SQL_OUTPUT_TEMPLATE.md`.
