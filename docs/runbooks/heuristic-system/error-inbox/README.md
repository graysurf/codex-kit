# Heuristic System Error Inbox

This folder holds versioned summaries of important workflow gaps that were
observed but not fixed in the same turn. It prevents important failures from
being lost when local `out/` evidence is cleaned or unavailable.

This is not a raw log archive. Commit only curated, redacted summaries that a
future agent can triage.

## Entry Criteria

Create an inbox entry when any of these are true:

- A delivery, release, merge, safety, validation, or evidence gate produced a
  gap that was not fixed immediately.
- The same failure class appears more than once.
- The user explicitly asks to keep the issue for later improvement.
- A workaround was used and future agents need to know the unresolved risk.

Do not create an entry for transient failures that were immediately fixed and
covered by tests or an operation record.

## Lifecycle

- `open`: gap is known and not yet triaged.
- `triaged`: diagnosis and likely owner are known.
- `planned`: implementation source, issue, or plan exists.
- `promoted`: fixed and compressed into an operation record, test, script,
  runbook, or skill policy.
- `wontfix`: explicitly accepted risk.

When a gap is fixed, either update the inbox entry to `promoted` with a link to
the durable fix or move the durable summary into `operation-records/`.

## Entry Template

```markdown
# <Short Gap Title>

## Status

- Status: open | triaged | planned | promoted | wontfix
- First observed: YYYY-MM-DD
- Area: <skill/script/runbook/tooling>
- Severity: low | medium | high

## Signal

<What failed, in one concise paragraph.>

## Evidence

- Raw record: `<out/.../skill-usage.record.json>`
- Summary: <short command, PR, log, or artifact summary>

## Impact

<Why this matters for future agents or delivery.>

## Current Workaround

<If any.>

## Promotion Criteria

<What would justify a test, script fix, runbook update, skill policy change, or
operation record.>

## Next Action

<One concrete next step.>
```

## Cleanup Rules

`docs/runbooks/heuristic-system/error-inbox/` is retained evidence, not
temporary plan coordination. Do not remove entries through broad
`docs-plan-cleanup` or durable-artifact cleanup unless the entry is promoted,
closed, or explicitly included in the user's cleanup scope.
