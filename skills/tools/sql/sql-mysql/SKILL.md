---
name: sql-mysql
description: Run MySQL queries via mysql client using a prefix + env file convention.
---

# SQL MySQL

## Contract

Prereqs:

- `bash` available on `PATH`.
- `mysql` client available on `PATH` (or install via Homebrew; this skill will try to add `mysql-client/bin` to `PATH` when available).
- Connection settings provided via exported env vars and/or an env file.

Inputs:

- `--prefix <PREFIX>`: env var prefix (example: `QB` → `QB_MYSQL_HOST`, `QB_MYSQL_PORT`, ...).
- `--env-file <path>`: file to `source` for env vars (use `/dev/null` to rely on already-exported env vars).
- One of:
  - `--query "<sql>"` (maps to `mysql -e`)
  - `--file <file.sql>` (runs file via stdin redirection)
  - `-- <mysql args...>` (pass-through to `mysql`)

Outputs:

- Query results printed to stdout (from `mysql`); diagnostics to stderr.

Exit codes:

- `0`: success
- non-zero: connection/auth/query error (from `mysql` or wrapper)

Failure modes:

- Missing `mysql`, missing required `<PREFIX>_MYSQL_*` env vars, or DB unreachable/auth failure.

## Overview

Use `sql-mysql` to run MySQL queries via `mysql` with a consistent `<PREFIX>_MYSQL_*` convention.

Prefer read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Run a query:

```bash
$AGENTS_HOME/skills/tools/sql/sql-mysql/scripts/sql-mysql.sh \
  --prefix TEST \
  --env-file /dev/null \
  --query "select 1;"
```

2) Run a file:

```bash
$AGENTS_HOME/skills/tools/sql/sql-mysql/scripts/sql-mysql.sh \
  --prefix TEST \
  --env-file /dev/null \
  --file /path/to/query.sql
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.

## Output and clarification rules

- Follow the shared template at `$AGENTS_HOME/skills/tools/sql/_shared/references/ASSISTANT_RESPONSE_TEMPLATE.md`.

## Scripts (only entrypoints)

- `$AGENTS_HOME/skills/tools/sql/sql-mysql/scripts/sql-mysql.sh`
