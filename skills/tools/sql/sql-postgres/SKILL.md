---
name: sql-postgres
description: Run PostgreSQL queries via psql using a prefix + env file convention.
---

# SQL Postgres

## Contract

Prereqs:

- `bash` available on `PATH`.
- `psql` available on `PATH` (or install via Homebrew; this skill will try to add `libpq/bin` to `PATH` when available).
- Connection settings provided via exported env vars and/or an env file.

Inputs:

- `--prefix <PREFIX>`: env var prefix (example: `FR` → `FR_PGHOST`, `FR_PGPORT`, ...).
- `--env-file <path>`: file to `source` for env vars (use `/dev/null` to rely on already-exported env vars).
- One of:
  - `--query "<sql>"` (maps to `psql --command`)
  - `--file <file.sql>` (maps to `psql -f`)
  - `-- <psql args...>` (pass-through to `psql`)

Outputs:

- Query results printed to stdout (from `psql`); diagnostics to stderr.

Exit codes:

- `0`: success
- non-zero: connection/auth/query error (from `psql` or wrapper)

Failure modes:

- Missing `psql`, missing required `<PREFIX>_PG*` env vars, or DB unreachable/auth failure.

## Overview

Use `sql-postgres` to run PostgreSQL queries via `psql` with a consistent `<PREFIX>_PG*` convention.

Prefer read-only queries unless the user explicitly requests data changes.

## Quick Start

1) Run a query:

```bash
$AGENTS_HOME/skills/tools/sql/sql-postgres/scripts/sql-postgres.sh \
  --prefix TEST \
  --env-file /dev/null \
  --query "select 1;"
```

2) Run a file:

```bash
$AGENTS_HOME/skills/tools/sql/sql-postgres/scripts/sql-postgres.sh \
  --prefix TEST \
  --env-file /dev/null \
  --file /path/to/query.sql
```

## Safety Rules

Ask before running `UPDATE`, `DELETE`, `INSERT`, `TRUNCATE`, or schema changes.

## Output and clarification rules

- Follow the shared template at `$AGENTS_HOME/skills/tools/sql/_shared/references/ASSISTANT_RESPONSE_TEMPLATE.md`.

## Scripts (only entrypoints)

- `$AGENTS_HOME/skills/tools/sql/sql-postgres/scripts/sql-postgres.sh`
