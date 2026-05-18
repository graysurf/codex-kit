# Heuristic System Framework

## Purpose

agent-kit is an agent-facing Heuristic System framework. It gives agents a
maintainable operating layer made of skills, scripts, runbooks, evidence
records, tests, and guardrails.

The framework does not train model weights. It lets agents improve the working
system around the model: when a workflow succeeds, fails, or needs correction,
the durable lesson can become clearer skill policy, a validation check, a
script, a test, a primitive, or a runbook update.

## Read This When

Read this document before:

- creating, updating, reviewing, or removing tracked skills;
- changing skill contracts, scripts, references, tests, or workflow primitives;
- designing new evidence, failure-handling, or recovery conventions;
- explicitly using a skill whose behavior depends on retained evidence,
  failure handling, or promotion of lessons into durable repo knowledge.

This document is required for `skill-dev` context through `agent-docs`. It is
recommended read-first context for explicit skill use until a dedicated
`skill-use` context exists.

## System Shape

A healthy agent-kit Heuristic System has these parts:

| Part | Role |
| --- | --- |
| Skills | Human-readable workflow policy, judgment boundaries, and usage contracts. |
| Scripts and primitives | Deterministic execution, validation, evidence capture, and guardrails. |
| Tests and checks | Regression protection for old capabilities and workflow contracts. |
| Evidence records | Redacted records of failures, waivers, validation, review, and browser/API activity. |
| Runbooks | Stable operating knowledge that should outlive one session. |
| Memory | Personal setup and recurring preferences only; not project state or factual proof. |

## Core Loop

Use this loop when a skill workflow produces new operational knowledge:

1. Run the skill within the active project rules.
2. Capture the relevant result, failure, validation, or waiver.
3. Diagnose failures from concrete evidence before changing policy or code.
4. Fix or work around the issue within scope.
5. Promote repeated lessons into a durable location.
6. Compress accumulated local patches into simpler contracts, tests, scripts, or
   runbooks.

The goal is not to record everything. The goal is to preserve useful learning
where a future agent can verify and reuse it.

## Promotion Ladder

Promote workflow lessons by durability:

| Signal | Preferred durable form |
| --- | --- |
| One-off execution result | Runtime evidence or final response summary. |
| Repeated skill failure | `Failure modes` entry or reference doc update. |
| Reproducible bug | Focused test, script smoke fixture, or regression case. |
| Cross-skill behavior | Shared runbook, primitive, or guardrail. |
| Stable project policy | `AGENTS.md`, project docs, or repo-local runbook. |
| Personal recurring preference | Memory, when allowed by the memory policy. |

Do not promote secrets, raw credentials, unredacted logs, or temporary task
state into durable docs or memory.

## Operation Records

Use curated operation records when a retained workflow failure is important
enough to prove that the heuristic loop actually operated. Keep raw runtime
records in their evidence location; commit only the compressed record that names
the signal, evidence, diagnosis, promotion decision, durable fix, validation, and
retention outcome.

Store operation records under `docs/runbooks/heuristic-system/operation-records/`
when they should remain visible after temporary plan or execution documents are
cleaned up.

## Compression Rule

Heuristic Systems decay when they only grow. When a skill accumulates several
local exceptions, retries, or failure notes, compress them:

1. Group the records by root cause.
2. Keep the smallest stable rule that explains the group.
3. Replace repeated prose with a test, guardrail, or script when practical.
4. Remove or archive obsolete coordination notes only after the durable lesson is
   represented elsewhere.
5. Keep the public skill surface smaller and clearer after compression.

## Boundaries

- Skills own workflow framing, judgment, and repo-local policy.
- Primitives own deterministic record writing, validation, redaction, and
  machine-checkable execution when available.
- `agent-docs` owns read-first context selection and hard-gate preflight.
- Runtime evidence is not automatically a repo artifact; commit only curated
  evidence or docs that project policy expects to retain.
- A skill should not self-modify without normal review, validation, and version
  control boundaries.

## Relationship To Skill Usage Recording

The implemented convention for automatic skill usage records lives at
`docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`.

Use the nils-cli `skill-usage` primitive for deterministic record writing,
validation, redaction, and linked evidence. This root document defines the
durable framework concept and the required read-first boundary for skill
development.
