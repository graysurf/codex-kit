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

Use the `heuristic-error-inbox` workflow skill when an agent needs to create,
verify, deduplicate, triage, update, or archive entries in this folder. Its
script can list active or archived entries, verify required sections and
lifecycle fields, create curated drafts from verified `skill-usage.record.json`
records, update status, and move completed records out of the active inbox.

## Lifecycle

- `open`: gap is known and not yet triaged.
- `triaged`: diagnosis and likely owner are known.
- `planned`: implementation source, issue, or plan exists.
- `promoted`: fixed and compressed into an operation record, test, script,
  runbook, or skill policy.
- `wontfix`: explicitly accepted risk.

When a gap is fixed, either update the inbox entry to `promoted` with a link to
the durable fix or move the durable summary into `operation-records/`.

Do not add `archived` as a lifecycle status. A completed entry remains
`promoted` or `wontfix`; archive state is represented by its location under
`heuristic-system/error-inbox/archive/YYYY/` plus an optional `Archive` section.

An entry is archive-ready only when:

- status is `promoted` or `wontfix`;
- durable outcome evidence is linked from the entry or supplied to the archive
  command;
- `Next Action` starts with `None.` and contains no remaining work; and
- any unrelated future follow-up has moved to a separate issue, plan, or source
  document.

Top-level `*.md` files are the active inbox. Archived records remain retained
evidence and can be listed explicitly with the workflow script.

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

## Archive

- Archived: YYYY-MM-DD
- Reason: <why this completed entry left the active inbox>
- Durable link: `<path-or-url>`
```

## Cleanup Rules

`heuristic-system/error-inbox/` is retained evidence, not temporary plan
coordination. Do not remove entries through broad `docs-plan-cleanup` or
durable-artifact cleanup unless the entry is promoted, closed, or explicitly
included in the user's cleanup scope.

Prefer archiving completed entries over deleting them. Archive moves should keep
the curated Markdown record and raw evidence pointers intact while keeping the
top-level inbox focused on actionable gaps.
