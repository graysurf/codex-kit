# Skill Usage Recording v1

Status: Active docs-first convention

## Purpose

Skill usage records make explicit skill execution traceable without relying on
hidden model memory or scattered session notes. They capture the skill boundary,
intent, outcome, validation, linked evidence, and failure handling that future
agents need when a workflow repeats or breaks.

This convention is intentionally compact. Existing typed evidence records remain
the source of truth for detailed test, browser, canary, review, or model-check
evidence.

## When To Record

Create a `skill-usage.record.v1` record when all are true:

- A named skill is explicitly invoked by the user or selected by the agent.
- The skill performs file edits, tool/API calls, validation, delivery, external
  lookup, or durable artifact creation.
- The project rules allow retaining local evidence for the workflow.

No record is required for a purely conversational prompt-style skill when it does
not touch files, tools, external sources, validation, or durable artifacts, unless
the user asked for retained evidence.

## Storage

Use this retention precedence:

1. Prefer the nearest project-defined evidence path from `AGENTS.md`, project
   docs, or workflow-specific policy.
2. If none exists, use a project-scoped run directory:

```bash
agent-out project --topic skill-usage --mkdir
```

3. Use `$AGENT_HOME/out/` only as a home-scope fallback, not as the default
   source of truth for target project evidence.

Store the top-level invocation envelope as `skill-usage.record.json`. Link typed
child evidence by path instead of copying it into the envelope.

Do not commit raw runtime records by default. Commit only curated records when
they are intentionally part of a review, incident, audit, or documentation
fixture, or when they have been compressed into durable docs, tests, or skill
failure modes. Project-local `AGENTS.md` files can override retention and
artifact paths.

## Record Envelope

The canonical schema id is `skill-usage.record.v1`. A record must identify:

- skill path or skill id;
- trigger and intent;
- working directory;
- start time and outcome status;
- artifacts and linked evidence;
- validation or an explicit validation waiver;
- follow-up items when work remains.

Use `docs/runbooks/skills/skill-usage-record-v1.schema.json` as the draft JSON
schema and `scripts/skills/validate_skill_usage_record.py` for repo-local
validation.

Minimal success example:

```json
{
  "schema": "skill-usage.record.v1",
  "skill": "skills/workflows/conversation/discussion-to-implementation-doc",
  "started_at": "2026-05-17T21:00:00+08:00",
  "cwd": "/Users/terry/.config/agent-kit",
  "trigger": "user_explicit",
  "intent": "write implementation handoff",
  "inputs": {
    "user_request_summary": "Create a durable implementation handoff",
    "referenced_files": [],
    "external_sources": []
  },
  "outcome": {
    "status": "pass",
    "summary": "Created implementation handoff"
  },
  "artifacts": [
    "docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md"
  ],
  "linked_records": [],
  "validation": [
    {
      "command": "scripts/check.sh --docs",
      "status": "pass",
      "summary": "Docs freshness passed"
    }
  ],
  "follow_up": []
}
```

## Failure Records

When a skill, script, command, dependency, or external service fails during the
skill workflow, add one item to `failures`.

Each failure must include:

- `phase`: `preflight`, `execution`, `validation`, `cleanup`, or `delivery`;
- `symptom`: what failed;
- `classification`: one of `skill_contract`, `script_bug`,
  `missing_dependency`, `external_service`, `project_state`, `user_scope`, or
  `unknown`;
- `diagnosis`: why the agent believes it failed;
- `handling`: what the agent did next;
- `result`: `fixed`, `worked_around`, `blocked`, or `accepted_risk`;
- verifying evidence when available.

Example:

```json
{
  "phase": "validation",
  "command": "scripts/check.sh --docs",
  "exit_code": 1,
  "symptom": "Docs freshness check failed",
  "classification": "project_state",
  "diagnosis": "The new runbook introduced an undocumented script path.",
  "handling": "Updated the script index and reran docs validation.",
  "result": "fixed",
  "artifacts": ["scripts/README.md"]
}
```

## Linked Evidence

Do not duplicate specialized records. Link them from `linked_records`.

If a failure remains unresolved but is important enough to survive local `out/`
cleanup, create a curated HEURISTIC_SYSTEM error inbox entry under
`heuristic-system/error-inbox/` and point it back to this raw
record. Use the `heuristic-error-inbox` workflow skill for creation,
verification, deduplication, and lifecycle status updates. Do not commit the raw `skill-usage.record.json` as the tracker.

Supported child evidence includes:

- `test-first-evidence.json` for before/after test evidence or waivers.
- `browser-session.json` for active browser QA evidence.
- `canary-check.json` for one local command canary.
- `review-evidence.json` for normalized findings and validation records.
- `model-cross-check.json` for primary/checker observations.

## Promotion Ladder

Usage records are a learning input, not a permanent policy pile. Promote repeated
or high-impact failures through this ladder:

| Signal | Durable action |
| --- | --- |
| First isolated failure | Record it in `skill-usage.record.v1` and cite final validation. |
| Repeated failure in one skill | Add or update `Failure modes` in `SKILL.md` or `references/`. |
| Reproducible failure | Add a focused test, fixture, or smoke script. |
| Cross-skill failure | Add a shared primitive, guardrail, or runbook section. |
| Unclear workflow policy | Update the relevant workflow skill or home-scope policy after review. |

## Compression

Periodic maintenance should compress retained records into durable rules:

1. Review records for one skill or workflow family.
2. Group failures by classification and root cause.
3. Preserve only records still needed as audit evidence.
4. Convert repeated lessons into `SKILL.md`, references, tests, scripts,
   primitives, or runbooks.
5. Keep the resulting skill surface smaller and clearer than the raw history.

## Validation

Validate a record with:

```bash
skill-usage verify --out <record-dir> --format json
```

Use the local checkout fallback from `skills/tools/workflow-evidence/skill-usage/SKILL.md`
only when the released PATH binary is absent or older than nils-cli 0.8.5:

```bash
cargo run --locked --manifest-path /path/to/nils-cli/Cargo.toml \
  -p nils-agent-workflow-primitives --bin skill-usage -- \
  verify --out <record-dir> --format json
```

The primitive rejects records missing outcome status, required failure
classification, failure records for non-pass outcomes, or final validation when
validation is required. The repo-local
`scripts/skills/validate_skill_usage_record.py` validator remains a
transition/reference fallback only.

## Primitive Boundary

`skill-usage.record.v1` is promoted to the nils-cli `skill-usage` primitive in
the `nils-agent-workflow-primitives` crate and is available in nils-cli 0.8.5 or
newer. Keep deterministic writing, redaction, schema validation, and JSON
envelope behavior in nils-cli. Keep workflow judgment, record requirements,
promotion, and compression policy in agent-kit skills and runbooks.

Command surface:

- `skill-usage init`
- `skill-usage link-record`
- `skill-usage record-failure`
- `skill-usage record-validation`
- `skill-usage record-outcome`
- `skill-usage verify`
- `skill-usage show`

## Hook-Assisted Reminder

Codex hooks may remind agents when a prompt appears to invoke a high-impact
workflow skill such as PR delivery, release, CI repair, web QA, issue review, or
bug/security automation. The hook is intentionally advisory only:

- It does not create directories or write `skill-usage.record.json`.
- It does not infer final outcome, validation status, failures, or artifacts.
- It does not replace this runbook, the calling skill contract, or project
  retention policy.

When the reminder applies and the record criteria above are met, the active
workflow should call the `skill-usage` primitive directly, link typed child
evidence when available, record validation and outcome, then run
`skill-usage verify --out <record-dir> --format json`.

## Prompt-Style Skills

Do not create a second schema for conversational prompt-style skills yet. Use the
normal `skill-usage.record.v1` schema only when the skill produces durable
artifacts, uses tools, performs external lookup, or validates work.

For rare lightweight retained cases, use `validation_required=false` plus a clear
`validation_waiver` instead of introducing a separate record type.

## Remaining Work

- Pilot generated failure records in real workflows.
- Promote one repeated failure into durable `SKILL.md`, test, script, primitive,
  or runbook guidance after enough operational evidence exists.
