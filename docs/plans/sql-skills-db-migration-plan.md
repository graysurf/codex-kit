# Plan: Consolidate DB tooling into SQL skills

## Overview
This plan removes DB-related entrypoints from `scripts/` and DB-related templates from `docs/`, consolidating them under `skills/tools/sql/`. Project-specific DB skills under `skills/_projects/` will become thin, DB-aware wrappers that delegate execution to `skills/tools/sql` (no duplicated connection tooling). Finally, `fr-psql` documentation will shift from generic SQL usage to a practical schema/data guide for the Finance Report database, sourced from live schema introspection.

## Scope
- In scope:
  - Delete `scripts/db-connect/` and migrate its functionality into `skills/tools/sql/_shared`.
  - Move `docs/templates/ASSISTANT_RESPONSE_TEMPLATE.md` into `skills/tools/sql/_shared` and update all references.
  - Rewrite `skills/_projects/*/scripts/*` DB wrappers to delegate to `skills/tools/sql` scripts.
  - Rewrite `skills/_projects/*/*/SKILL.md` DB skills to avoid repeating generic SQL tooling guidance.
  - Update `skills/_projects/finance-report/fr-psql/SKILL.md` to include a DB schema/data overview derived from safe introspection queries.
  - Keep `skills/_projects/qburger/qb-mysql/SKILL.md` DB-content-light (no schema deep-dive).
- Out of scope:
  - Rotating credentials, changing DB permissions, or altering production data.
  - Changing non-SQL skills or unrelated documentation.

## Assumptions (if any)
1. Repo tests remain the source of truth for regression (`scripts/test.sh`).
2. It is acceptable for `skills/_projects/*/scripts/*.zsh` to remain as convenience wrappers, as long as they delegate to `skills/tools/sql` (no separate connection implementation).
3. The Finance Report DB connection in `skills/_projects/finance-report/fr-psql.env` is reachable from this environment for schema introspection only.

## Sprint 1: Consolidate shared SQL tooling
**Goal**: Remove DB tooling from `scripts/` and `docs/` by consolidating into `skills/tools/sql/_shared` and updating callers.
**Demo/Validation**:
- Command(s): `scripts/test.sh`
- Verify:
  - `scripts/db-connect/` is deleted.
  - `docs/templates/ASSISTANT_RESPONSE_TEMPLATE.md` is deleted.
  - SQL skills still function and tests pass.

### Task 1.1: Migrate db-connect logic into SQL skills
- **Location**:
  - `skills/tools/sql/_shared/lib/db-connect-runner.sh`
  - `skills/tools/sql/sql-postgres/scripts/sql-postgres.sh`
  - `skills/tools/sql/sql-mysql/scripts/sql-mysql.sh`
  - `skills/tools/sql/sql-mssql/scripts/sql-mssql.sh`
  - `scripts/db-connect/psql.zsh`
  - `scripts/db-connect/mysql.zsh`
  - `scripts/db-connect/mssql.zsh`
- **Description**: Replace dependency on `scripts/db-connect/*.zsh` with a self-contained runner in `skills/tools/sql/_shared` (load env file, validate `PREFIX_*` vars, add brew client PATH when needed, and invoke `psql`/`mysql`/`sqlcmd` with correct flags).
- **Dependencies**:
  - none
- **Complexity**: 6
- **Acceptance criteria**:
  - `sql-postgres.sh`, `sql-mysql.sh`, `sql-mssql.sh` no longer reference `scripts/db-connect`.
  - Runner supports `--env-file /dev/null` (exported env-only mode).
  - Existing calling conventions still work (`--query`, `--file`, or pass-through args).
- **Validation**:
  - `rg -n \"scripts/db-connect\" skills/tools/sql -S` returns no matches.
  - `scripts/test.sh`

### Task 1.2: Move assistant response template into SQL skills
- **Location**:
  - `docs/templates/ASSISTANT_RESPONSE_TEMPLATE.md`
  - `skills/tools/sql/_shared/references/ASSISTANT_RESPONSE_TEMPLATE.md`
  - `skills/tools/sql/sql-postgres/SKILL.md`
  - `skills/tools/sql/sql-mysql/SKILL.md`
  - `skills/tools/sql/sql-mssql/SKILL.md`
  - `skills/_projects/finance-report/fr-psql/SKILL.md`
  - `skills/_projects/megabank/mb-mssql/SKILL.md`
  - `skills/_projects/qburger/qb-mysql/SKILL.md`
  - `skills/_projects/tun-group/tun-psql/SKILL.md`
  - `skills/_projects/tun-group/tun-mssql/SKILL.md`
- **Description**: Move the template out of `docs/templates/` into `skills/tools/sql/_shared/references/`, and update all SQL-related skills to reference the new location.
- **Dependencies**:
  - none
- **Complexity**: 3
- **Acceptance criteria**:
  - `docs/templates/ASSISTANT_RESPONSE_TEMPLATE.md` is deleted.
  - References point to `$CODEX_HOME/skills/tools/sql/_shared/references/ASSISTANT_RESPONSE_TEMPLATE.md`.
- **Validation**:
  - `test ! -f docs/templates/ASSISTANT_RESPONSE_TEMPLATE.md`
  - `rg -n \"ASSISTANT_RESPONSE_TEMPLATE\\.md\" -S skills | cat`
  - `scripts/test.sh`

### Task 1.3: Update tests/specs for removed db-connect scripts
- **Location**:
  - `tests/script_specs/scripts/db-connect/mysql.zsh.json`
  - `tests/script_specs/scripts/db-connect/psql.zsh.json`
  - `tests/script_specs/scripts/db-connect/mssql.zsh.json`
  - `docs/progress/archived/20260113_script-smoke-tests.md`
- **Description**: Remove or migrate smoke specs that target `scripts/db-connect/*` to the new SQL skill scripts, and update any documentation that would otherwise reference deleted paths.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - No tracked tests/specs refer to `scripts/db-connect/`.
  - Script smoke continues to validate DB client argv wiring via existing stubs.
- **Validation**:
  - `rg -n \"scripts/db-connect\" -S tests docs --glob '!docs/progress/**' --glob '!docs/plans/**'` returns no matches.
  - `scripts/test.sh`

## Sprint 2: Rewrite project DB skills to delegate + improve FR DB docs
**Goal**: Make `skills/_projects` DB skills thin wrappers over `skills/tools/sql`, and make `fr-psql` docs DB-content-focused.
**Demo/Validation**:
- Command(s): `scripts/test.sh`
- Verify:
  - `skills/_projects/*/scripts/*.zsh` no longer sources `scripts/db-connect`.
  - `fr-psql` skill doc includes a schema cheat sheet.

### Task 2.1: Rewrite project wrappers to delegate to SQL skills
- **Location**:
  - `skills/_projects/finance-report/scripts/fr-psql.zsh`
  - `skills/_projects/megabank/scripts/mb-mssql.zsh`
  - `skills/_projects/tun-group/scripts/tun-psql.zsh`
  - `skills/_projects/tun-group/scripts/tun-mssql.zsh`
  - `skills/_projects/qburger/scripts/qb-mysql.zsh`
- **Description**: Replace wrapper implementations with thin functions that call the corresponding `skills/tools/sql` scripts, pre-binding `--prefix` and `--env-file` to the project env file. Preserve existing function names (`fr-psql`, `mb-mssql`, etc.) for ergonomics.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - No wrapper sources `scripts/db-connect/*.zsh`.
  - Passing through native client args continues to work (e.g., `fr-psql -c ...`, `mb-mssql -Q ...`).
- **Validation**:
  - `scripts/test.sh`

### Task 2.2: Refocus project SKILL.md content (avoid generic tooling)
- **Location**:
  - `skills/_projects/finance-report/fr-psql/SKILL.md`
  - `skills/_projects/megabank/mb-mssql/SKILL.md`
  - `skills/_projects/tun-group/tun-psql/SKILL.md`
  - `skills/_projects/tun-group/tun-mssql/SKILL.md`
  - `skills/_projects/qburger/qb-mysql/SKILL.md`
- **Description**: Update project DB skills documentation to be project/DB-specific: what this DB contains, key schemas/tables, safe query starting points, and common pitfalls. Keep `qb-mysql` light (no schema deep-dive) per connectivity constraints.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 7
- **Acceptance criteria**:
  - Each project skill clearly states how to run queries via `skills/tools/sql`.
  - `fr-psql` SKILL.md includes a schema/table cheat sheet to reduce repeated schema discovery.
- **Validation**:
  - `bash skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/_projects/finance-report/fr-psql/SKILL.md`
  - `scripts/test.sh`

### Task 2.3: Remove obsolete project DB lib (if unused)
- **Location**:
  - `skills/_projects/_libs/zsh/db-connect.zsh`
- **Description**: If project wrappers no longer source the shared db-connect lib, delete it and remove any remaining references.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 2
- **Acceptance criteria**:
  - No tracked files reference `skills/_projects/_libs/zsh/db-connect.zsh`.
- **Validation**:
  - `rg -n \"skills/_projects/_libs/zsh/db-connect\\.zsh\" -S skills scripts tests docs --glob '!docs/plans/**'` returns no matches.
  - `scripts/test.sh`

### Task 2.4: Add FR DB schema introspection notes via live queries
- **Location**:
  - `skills/_projects/finance-report/fr-psql/SKILL.md`
- **Description**: Use `fr-psql` to run safe introspection queries (`information_schema`, `pg_catalog`) to list the key schemas, tables, and important columns; then curate a compact “cheat sheet” section in the skill doc for repeated use.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 8
- **Acceptance criteria**:
  - `fr-psql` SKILL.md includes: primary schema name(s), top tables list, key columns, and a few canonical query patterns.
  - No secrets are printed in the doc (never paste credentials or raw sensitive rows).
- **Validation**:
  - Manual sanity: run 2–3 introspection queries and confirm doc matches.
  - `scripts/test.sh`

## Testing Strategy
- Unit: rely on existing skill governance tests and script regression harness.
- Integration: script smoke tests for SQL skill entrypoints using existing `tests/stubs/bin/*` client stubs.
- E2E/manual: optional live `fr-psql` introspection queries (read-only; schema-only).

## Risks & gotchas
- Deleting `scripts/db-connect/` may break undiscovered local workflows; mitigate by providing a clear mapping from old `codex_*_run` usage to `skills/tools/sql` scripts.
- Env files are shell-sourced; ensure the new runner is strict and avoids echoing secrets.
- FR schema introspection could be slow on large catalogs; keep queries bounded and focused.

## Rollback plan
- Restore `scripts/db-connect/` from git history if any dependency is missed.
- Restore `docs/templates/ASSISTANT_RESPONSE_TEMPLATE.md` and revert references to it if the new shared template path proves awkward.
- Re-run `scripts/test.sh` to confirm rollback stability.
