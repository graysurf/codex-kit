# Heuristic System Records

This root directory keeps retained records for agent-kit heuristic-system
operation. It is intentionally outside `docs/` because these entries are
system-level feedback loops, not ordinary project documentation or temporary
coordination artifacts.

Use `HEURISTIC_SYSTEM.md` for the framework overview and this directory for
curated records that should remain discoverable after temporary `docs/plans/`
coordination artifacts are cleaned up.

## Error Inbox

Unresolved but important workflow gaps live as top-level files under
`error-inbox/`. Each entry is a curated tracker for a failure that should not
disappear with local `out/` evidence but has not yet been fixed, accepted, or
promoted.

Completed entries stay retained but should not keep inflating the active inbox.
After an entry is `promoted` or `wontfix`, has durable outcome links, and has no
remaining next action, archive it under `error-inbox/archive/YYYY/`.

Do not copy raw runtime evidence into inbox entries. Link or summarize retained
records from their project evidence locations.

Use the `heuristic-error-inbox` workflow skill for inbox lifecycle work such as
listing active or archived entries, verifying required sections, creating
curated entries from verified `skill-usage.record.json` records, updating
lifecycle status, and archiving completed records.

## Operation Records

Operation records live under `operation-records/`. Each record should summarize a
real workflow signal, the retained evidence used to diagnose it, the durable fix,
validation, and the retention decision.

Do not create an operation record for every promoted inbox entry. Tests, scripts,
runbooks, or skill policy are enough when they fully capture a local fix. Use an
operation record when the retained lesson is repeated, cross-skill, audit-worthy,
or broader than the local change.

Do not copy raw runtime evidence into this directory. Link or summarize retained
records from their project evidence locations.

## Retention Flow

Use this flow for workflow failures:

1. Keep raw evidence in `out/` or the tool-defined evidence location.
2. Create an `error-inbox/` entry only when an unresolved gap is important enough
   to survive cleanup.
3. Verify or update inbox entries through `heuristic-error-inbox` before routing
   follow-up implementation work.
4. Promote or close the entry after the gap is fixed, validated, or accepted.
5. Compress the lesson into the smallest durable form: test, script, runbook,
   skill policy, primitive contract, or operation record.
6. Archive the completed inbox entry under `error-inbox/archive/YYYY/` when it
   has durable outcome links and no remaining next action.
7. Delete or archive temporary `docs/plans/` coordination docs only after the
   durable lesson is represented in maintained docs, tests, scripts, or records.
