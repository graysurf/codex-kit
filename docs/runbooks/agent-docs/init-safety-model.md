# Agent Doc Init Safety Model

## Scope

- Defines safety guarantees for `agent-doc-init`.
- Applies to both home-level and project-level baseline initialization.

## Safety contract

1. Default mode is non-destructive dry-run.
2. Write operations require explicit `--apply`.
3. Overwrite operations require explicit `--force` and are rejected without `--apply`.
4. Baseline scaffold defaults to `--missing-only` to avoid touching existing files.
5. Project extension edits use deterministic upsert (`agent-docs add`) instead of manual file edits.

## Deterministic flow

1. Run `agent-docs baseline --check --target <scope> --format json`.
2. If missing required docs exist, run `agent-docs scaffold-baseline`:
   - default path: `--missing-only`
   - overwrite path: `--force`
3. Optionally apply `agent-docs add` entries for `--project-required`.
4. Re-run baseline check and emit fixed summary fields.

## Failure model

- Dependency error:
  - `agent-docs` missing from `PATH` -> exit `1`.
- Usage/safety violation:
  - invalid option shape or unsupported context
  - `--force` without `--apply`
  - exits `2`.
- Config/runtime error from `agent-docs`:
  - invalid `AGENT_DOCS.toml` schema
  - permission denied during writes
  - unrecoverable I/O error
  - exits non-zero (propagated as runtime failure).

## Escalation path

1. Run dry-run first and inspect summary.
2. If required docs are missing, run apply mode without `--force`.
3. Use `--force` only when intentional overwrite is required.
4. Validate with strict baseline check after apply:
   - `agent-docs baseline --check --target all --strict --format text`
