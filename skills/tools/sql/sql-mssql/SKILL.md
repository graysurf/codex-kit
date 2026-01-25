---
name: sql-mssql
description: Run SQL Server queries via sqlcmd using a prefix + env file convention.
---

# SQL MSSQL

## Contract

Prereqs:

- `bash` available on `PATH`.
- `sqlcmd` available on `PATH` (or install via Homebrew; this skill will try to add `mssql-tools18/bin` to `PATH` when available).
- Connection settings provided via exported env vars and/or an env file.

Inputs:

- `--prefix <PREFIX>`: env var prefix (example: `MB` → `MB_MSSQL_HOST`, `MB_MSSQL_PORT`, ...).
- `--env-file <path>`: file to `source` for env vars (use `/dev/null` to rely on already-exported env vars).
- One of:
  - `--query "<sql>"` (maps to `sqlcmd -Q`)
  - `--file <file.sql>` (maps to `sqlcmd -i`)
  - `-- <sqlcmd args...>` (pass-through to `sqlcmd`)

Outputs:

- Query results printed to stdout (from `sqlcmd`); diagnostics to stderr.

Exit codes:

- `0`: success
- non-zero: connection/auth/query error (from `sqlcmd` or wrapper)

Failure modes:

- Missing `sqlcmd`, missing required `<PREFIX>_MSSQL_*` env vars, or DB unreachable/auth failure.

## Overview

Use `sql-mssql` to run SQL Server queries via `sqlcmd` with a consistent `<PREFIX>_MSSQL_*` convention.

Optional extras supported by this skill:

- `<PREFIX>_MSSQL_TRUST_CERT`: set to `1|true|yes` to pass `-C` to `sqlcmd`.
- `<PREFIX>_MSSQL_SCHEMA`: passed as `-v schema=<schema>` to `sqlcmd`.

Prefer read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Run a query:

```bash
$CODEX_HOME/skills/tools/sql/sql-mssql/scripts/sql-mssql.sh \
  --prefix TEST \
  --env-file /dev/null \
  --query "select 1;"
```

2) Run a file:

```bash
$CODEX_HOME/skills/tools/sql/sql-mssql/scripts/sql-mssql.sh \
  --prefix TEST \
  --env-file /dev/null \
  --file /path/to/query.sql
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `MERGE`, `TRUNCATE`, or schema changes.

## Output and clarification rules

- Follow the shared template at `$CODEX_HOME/skills/tools/sql/_shared/references/ASSISTANT_RESPONSE_TEMPLATE.md`.

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/tools/sql/sql-mssql/scripts/sql-mssql.sh`
