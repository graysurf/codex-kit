# Heuristic System Skills Implementation Handoff

## Status

- Status: ready for plan generation
- Date: 2026-05-18
- Source: user discussion about turning HEURISTIC_SYSTEM lifecycle handling into skills and later nils-cli primitives
- Intended next step: create an implementation plan, then implement the initial skill family slice

## Purpose

Create a small HEURISTIC_SYSTEM workflow skill family so agents can act on
`heuristic-system/error-inbox/` and related lifecycle records through stable
entrypoints instead of re-reading the framework docs and improvising every time.

The first practical problem is inbox handling: a future agent should be able to
use a skill to create, update, triage, verify, and route
`heuristic-system/error-inbox/` entries. The broader direction is a lifecycle
loop for inbox entries, operation records, compression, and later nils-cli
primitive extraction.

## Confirmed Facts

- `HEURISTIC_SYSTEM.md` defines agent-kit as an agent-facing heuristic-system
  framework made of skills, scripts, runbooks, evidence records, tests, and
  guardrails. [F1]
- The HEURISTIC_SYSTEM loop is evidence-first: capture result or failure,
  diagnose from concrete evidence, fix or work around the issue, promote useful
  lessons, and compress repeated local patches into simpler contracts, tests,
  scripts, or runbooks. [F1]
- `heuristic-system/error-inbox/` is retained evidence for important unresolved
  workflow gaps. It is not a raw log archive and should contain curated,
  redacted summaries. [F2]
- Existing inbox lifecycle statuses are `open`, `triaged`, `planned`,
  `promoted`, and `wontfix`. [F2]
- `skill-usage.record.v1` is already implemented as a nils-cli primitive for
  deterministic writing, redaction, schema validation, and JSON envelope
  behavior. [F3]
- Policy judgment, record requirements, promotion, and compression remain in
  agent-kit skills and runbooks rather than the `skill-usage` primitive. [F3]
- Prior adoption guidance favors selective primitive extraction into nils-cli
  after local skill/script behavior has proven useful, not cloning a whole
  external workflow architecture. [M1]

## Decisions

- Build a HEURISTIC_SYSTEM workflow skill family, not a single oversized
  catch-all skill.
- Start with `heuristic-error-inbox` because it solves the immediate repeated
  task: handling entries under `heuristic-system/error-inbox/`.
- Keep initial deterministic support as repo-local skill scripts. Promote to a
  nils-cli primitive only after the command surface has been exercised on real
  entries and stable tests.
- Treat the skill family itself as part of the heuristic-system loop: implement
  a narrow slice, run it on real workflow gaps, observe friction, then compress
  the lessons into clearer skills, scripts, tests, or primitives.
- Keep repo docs and skill content in English.

## Proposed Skill Family

### `heuristic-error-inbox`

Purpose: manage unresolved HEURISTIC_SYSTEM gaps under
`heuristic-system/error-inbox/`.

Responsibilities:

- Decide whether a gap warrants an inbox entry.
- Create a curated entry from a verified `skill-usage.record.json`, an existing
  failure note, or a user-provided summary.
- Verify required sections, status enum, severity, evidence pointer, workaround,
  promotion criteria, and next action.
- Detect likely duplicate entries by slug, title, area, or evidence pointer.
- Update lifecycle status from `open` through `planned`, `promoted`, or
  `wontfix`.
- Route implementation work to `create-plan`, a provider-specific skill, or a
  domain workflow; do not fix every bug itself.

Initial script surface:

```bash
heuristic-error-inbox.sh list
heuristic-error-inbox.sh verify <entry.md>
heuristic-error-inbox.sh new --from-skill-usage <record-dir> --slug <slug>
heuristic-error-inbox.sh set-status <entry.md> --status planned --link <path-or-url>
```

### `heuristic-operation-record`

Purpose: promote fixed or accepted HEURISTIC_SYSTEM gaps into compressed
operation records under `heuristic-system/operation-records/`.

Responsibilities:

- Convert a resolved inbox entry into an operation-record draft.
- Verify that the durable fix, validation, and retention decision are present.
- Mark the source inbox entry `promoted` or `wontfix` with a link to the durable
  outcome.
- Ensure raw runtime records remain linked, not copied.

Initial script surface:

```bash
heuristic-operation-record.sh verify <record.md>
heuristic-operation-record.sh promote --from-inbox <entry.md> --slug <slug>
```

### `heuristic-compression-review`

Purpose: periodically review accumulated inbox and operation records, group
repeated lessons, and recommend durable compression.

Responsibilities:

- List open, triaged, planned, promoted, and stale entries.
- Group related failures by skill, script, failure class, or evidence pointer.
- Recommend whether the durable fix should be a `SKILL.md` update, reference
  doc, test, script, hook guard, or nils-cli primitive.
- Keep the skill surface smaller after compression rather than building a pile
  of one-off exceptions.

Initial script surface:

```bash
heuristic-compression-review.sh report
heuristic-compression-review.sh report --status open,triaged
```

### Later Candidate: `heuristic-system-lifecycle`

Purpose: orchestrate the whole lifecycle when a user explicitly asks for a
HEURISTIC_SYSTEM maintenance pass.

This should not be implemented first. It is useful only after the narrower
inbox, operation-record, and compression skills have stable contracts. Until
then, an umbrella lifecycle skill would hide too much judgment and overlap with
`create-plan`, `execute-from-implementation-doc`, and durable cleanup skills.

## Scope

Initial implementation should include:

- Add a new `skills/workflows/heuristic-system/` skill family area.
- Implement `heuristic-error-inbox` first, with a small script and tests.
- Add placeholder or minimal handoff docs for `heuristic-operation-record` and
  `heuristic-compression-review` only if useful for discoverability.
- Update skill catalogs or README surfaces that enumerate workflow skills.
- Add tests that verify the new skill contract text, script behavior, and path
  conventions.
- Use the existing GitLab MR skipped-pipeline inbox entry as read-first context,
  but avoid mutating it in tests unless a temp fixture is used.

## Non-Scope

- Do not fix GitLab MR pipeline parsing or close-cleanup behavior in this
  implementation source. That work should get its own plan or execution lane.
- Do not implement a nils-cli primitive in the first slice.
- Do not auto-create inbox entries from hooks. Hooks may remind; skills and
  agents own judgment.
- Do not copy raw logs, raw `skill-usage.record.json`, secrets, or credentials
  into committed inbox or operation-record files.
- Do not make a single generic skill that handles all HEURISTIC_SYSTEM work.

## Implementation Boundaries

- Skills own workflow framing, classification, severity, lifecycle decisions,
  routing, and human-readable record quality.
- Repo-local scripts own deterministic Markdown checks, status changes,
  duplicate scanning, safe field extraction, and machine-readable reports.
- nils-cli primitives should later own stable deterministic behavior only after
  the local script surface proves durable.
- `skill-usage` remains the primitive for raw skill invocation evidence; new
  heuristic-system scripts must link to verified records rather than duplicate
  the `skill-usage` schema.
- Script writes to one evidence record or entry should be serial, not parallel.

## Requirements

- A future agent can invoke `heuristic-error-inbox` for a user request such as
  "handle the current heuristic-system/error-inbox gap" and get clear workflow
  steps.
- A future agent can verify an inbox entry before using it as plan input.
- A future agent can create a curated inbox entry from a verified
  `skill-usage.record.json` without copying raw logs.
- A future agent can update status to `planned`, `promoted`, or `wontfix` while
  preserving evidence links and next action clarity.
- The workflow must route implementation sequencing to `create-plan` or
  execution workflows instead of embedding full task plans inside inbox entries.
- The skill family should make later nils-cli extraction easier by keeping the
  script command surface small and deterministic.

## Acceptance Criteria

- `heuristic-error-inbox` exists as a workflow skill with concise trigger
  metadata, contract, workflow, command surface, failure modes, and output rules.
- A repo-local script can list and verify inbox entries under
  `heuristic-system/error-inbox/`.
- Tests cover valid and invalid inbox entry fixtures, including status enum,
  required sections, missing evidence, and duplicate-detection behavior when
  practical.
- Existing docs that mention HEURISTIC_SYSTEM inbox handling point to the new
  skill when an agent needs to perform lifecycle work.
- The implementation preserves the framework boundary from
  `HEURISTIC_SYSTEM.md`: skills hold judgment, scripts/primitives hold
  deterministic checks.
- Validation passes through focused tests plus the repo's docs and markdown
  checks.

## Validation Plan

Run at least:

```bash
scripts/check.sh --tests -- -k 'heuristic_system or heuristic_error_inbox'
scripts/check.sh --docs
scripts/check.sh --markdown
```

Before reporting implementation complete, run:

```bash
scripts/check.sh --all
```

If workflow or tool entrypoint scripts are added, also run the entrypoint drift
guards required by `DEVELOPMENT.md`.

## Risks And Guardrails

- Risk: the skill family becomes too broad and overlaps every improvement
  workflow. Guardrail: keep `heuristic-error-inbox`, `heuristic-operation-record`,
  and `heuristic-compression-review` narrow.
- Risk: scripts encode judgment that belongs in the skill. Guardrail: scripts
  should validate and transform; skills should decide.
- Risk: committed records leak raw logs or secrets. Guardrail: generated entries
  must summarize and link raw evidence instead of copying it.
- Risk: nils-cli extraction happens too early. Guardrail: require at least a few
  real local uses and stable tests before creating a primitive.
- Risk: lifecycle records become stale. Guardrail: `heuristic-compression-review`
  should make stale open entries visible and push resolved entries toward
  `promoted` or `wontfix`.

## Execution

- Recommended execution state path:
  `docs/plans/heuristic-system-skills/heuristic-system-skills-execution-state.md`
- Recommended next artifact:
  `docs/plans/heuristic-system-skills/heuristic-system-skills-plan.md`
- Recommended next workflow: use `create-plan` or `create-plan-rigorous` with
  this document under `Read First`.

## Retention Intent

This document is a plan-source handoff. It may be deleted by durable artifact
cleanup after implementation completes and the durable knowledge is represented
in maintained skill docs, scripts, tests, and HEURISTIC_SYSTEM records.

## Open Questions

- Should the first skill name be `heuristic-error-inbox` or shorter
  `heuristic-inbox`?
- Should `heuristic-operation-record` be implemented in the first pass or left
  as a documented next skill after the first promotion case?
- Should script reports use plain text first, JSON first, or both from day one?
- What minimum duplicate-detection heuristic is useful without overfitting to
  current entries?

## Read First References

- [F1] `HEURISTIC_SYSTEM.md`
- [F2] `heuristic-system/error-inbox/README.md`
- [F3] `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`
- [M1] Memory note: prior primitive adoption guidance keeps deterministic
  evidence capture in primitives while skills own judgment and workflow framing.

## Recommended Next Artifact

Create an implementation plan that uses this document as the primary source and
starts with `heuristic-error-inbox`. Include the remaining skill family as
future slices so the first implementation stays narrow while preserving the
broader HEURISTIC_SYSTEM direction.
