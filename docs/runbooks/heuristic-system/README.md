# Heuristic System Runbooks

This directory keeps durable records and runbooks for agent-kit heuristic-system
operation. It is for compressed learning that should remain discoverable after
temporary `docs/plans/` coordination artifacts are cleaned up.

## Error Inbox

Unresolved but important workflow gaps live under `error-inbox/`. Each entry is a
curated tracker for a failure that should not disappear with local `out/`
evidence but has not yet been fixed, accepted, or promoted.

Do not copy raw runtime evidence into inbox entries. Link or summarize retained
records from their project evidence locations.

## Operation Records

Operation records live under `operation-records/`. Each record should summarize a
real workflow signal, the retained evidence used to diagnose it, the durable fix,
validation, and the retention decision.

Do not copy raw runtime evidence into this directory. Link or summarize retained
records from their project evidence locations.

## Retention Flow

Use this flow for workflow failures:

1. Keep raw evidence in `out/` or the tool-defined evidence location.
2. Create an `error-inbox/` entry only when an unresolved gap is important enough
   to survive cleanup.
3. Promote to `operation-records/` after the gap is fixed and validated.
4. Delete or archive temporary `docs/plans/` coordination docs only after the
   durable lesson is represented in maintained docs, tests, scripts, or records.
