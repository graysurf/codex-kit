---
name: heuristic-error-inbox
description: Manage curated HEURISTIC_SYSTEM error-inbox lifecycle entries with judgment-first workflow guidance and deterministic helper commands.
---

# Heuristic Error Inbox

Use this skill when an unresolved HEURISTIC_SYSTEM workflow gap should be
created, verified, triaged, routed, or moved through its retained inbox lifecycle.

## Contract

Prereqs:

- Target workspace is a git work tree with `heuristic-system/error-inbox/`.
- `python3` is available on `PATH`.
- `skill-usage` is available when creating entries from a
  `skill-usage.record.json`; the record should already pass
  `skill-usage verify --out <record-dir> --format json`.
- Project preflight has passed before editing tracked inbox records.

Inputs:

- User request to create, verify, triage, route, or update a curated
  HEURISTIC_SYSTEM error inbox entry.
- Optional existing inbox entry path under `heuristic-system/error-inbox/`.
- Optional verified skill usage record directory for
  `new --from-skill-usage <record-dir>`.
- Optional lifecycle status: `open`, `triaged`, `planned`, `promoted`, or
  `wontfix`.
- Optional severity: `low`, `medium`, or `high`.
- Optional implementation plan, issue, PR/MR, operation record, or runbook link
  to preserve as lifecycle evidence.

Outputs:

- A concise recommendation about whether the gap warrants a retained inbox
  entry, duplicate update, plan routing, promotion, or accepted-risk closure.
- A curated Markdown entry under `heuristic-system/error-inbox/` when creation
  is appropriate.
- Deterministic script output for list, verify, new, and set-status operations
  in text or JSON.
- Validation evidence from the script and project checks before claiming the
  lifecycle update is complete.

Exit codes:

- `0`: success
- `1`: validation failure, duplicate entry detected, missing required entry
  content, or unsafe write target
- `2`: usage error

Failure modes:

- Requested entry would duplicate an existing slug, title, area, or evidence
  pointer; update the existing entry or ask the user before creating another.
- Entry lacks required sections, lifecycle status, severity, raw evidence
  pointer, workaround, promotion criteria, or next action.
- `skill-usage.record.json` is missing, malformed, unverified, or points to raw
  details that should stay linked rather than copied.
- Requested lifecycle status lacks a durable link or next action when the status
  is `planned`, `promoted`, or `wontfix`.
- The user is actually asking to implement the underlying bug fix; route that to
  `create-plan`, `execute-from-implementation-doc`, or the provider/domain skill
  instead of fixing it inside this inbox workflow.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh`

## Workflow

1. Decide whether a retained inbox entry is appropriate.
   - Use an entry when an important delivery, release, validation, evidence, or
     safety workflow gap remains unresolved.
   - Do not create an entry for a transient failure that was fixed immediately
     and covered by tests or an operation record.

2. Inspect the current inbox before writing.
   - Run:

     ```bash
     $AGENT_HOME/skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh list
     ```

   - Check for likely duplicates by slug, title, area, and evidence pointer.

3. Create or update one curated record.
   - From a verified `skill-usage` record:

     ```bash
     $AGENT_HOME/skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh \
       new --from-skill-usage <record-dir> --slug <slug>
     ```

   - For existing records, edit the Markdown only as needed or use
     `set-status` for lifecycle status changes.
   - Link raw records and summarize the failure; never copy raw logs, secrets,
     credentials, or terminal dumps into the committed inbox entry.

4. Verify before routing or reporting completion.
   - Run:

     ```bash
     $AGENT_HOME/skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh \
       verify heuristic-system/error-inbox/<entry>.md
     ```

   - For lifecycle status changes, preserve a concrete next action or durable
     outcome link.

5. Route implementation work outside this skill.
   - Use `create-plan` or `execute-from-implementation-doc` for planned fixes.
   - Use provider-specific PR/MR/release skills for delivery failures.
   - Promote fixed and validated lessons into operation records, tests, scripts,
     runbooks, or skill policy before marking an entry `promoted`.

## Command Surface

```bash
heuristic-error-inbox.sh list [--inbox-dir <dir>] [--status <csv>] [--format text|json]
heuristic-error-inbox.sh verify <entry.md> [--inbox-dir <dir>] [--format text|json]
heuristic-error-inbox.sh new --from-skill-usage <record-dir> --slug <slug> [--out-dir <dir>] [--severity low|medium|high] [--format text|json]
heuristic-error-inbox.sh set-status <entry.md> --status planned|promoted|wontfix|open|triaged [--link <path-or-url>] [--format text|json]
```

## Relationship To Later Skills

- `heuristic-operation-record` should be added only after at least one promoted
  inbox entry proves the promotion surface.
- `heuristic-compression-review` should be added only after enough records exist
  to group repeated lessons.
- Do not add a broad `heuristic-system-lifecycle` skill until the narrower
  inbox, operation-record, and compression workflows are stable.
