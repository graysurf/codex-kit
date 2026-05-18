# Heuristic System Retention Follow-Up Implementation Handoff

## Status

- Date: 2026-05-18
- Source type: discussion-to-implementation-doc
- Status: ready for implementation planning
- Intended next step: use this source to plan heuristic-system inbox completion,
  retention, operation-record, compression, and `skill-usage` write-locking
  follow-up.
- Recommended execution state:
  `docs/plans/heuristic-system-retention-follow-up/heuristic-system-retention-follow-up-execution-state.md`

## Purpose

Separate the heuristic-system follow-up discovered during the GitLab MR delivery
failure from the GitLab MR workflow bug itself. The GitLab MR workflow has been
fixed and validated; this document preserves the independent system-level gaps
for later implementation without keeping the GitLab inbox entry open.

The completion of
`heuristic-system/error-inbox/deliver-gitlab-mr-skipped-pipeline-and-cleanup.md`
also exposed a practical skill-design question: agents need a clear way to turn
a promoted inbox entry into a self-contained completion record without leaving
future-system follow-up text inside the completed entry.

## Confirmed Facts

- The GitLab MR workflow defect was fixed in agent-kit and delivered through
  GitHub PR #254.
- A live GitLab acceptance MR validated the fixed behavior:
  `gim/backend/livekit-agents!104`.
- The original GitLab MR incident exposed a separate system-level gap:
  high-impact `skill-usage` evidence can identify workflow gaps before there is
  a clear promotion/compression path.
- `heuristic-system/error-inbox/README.md` currently defines lifecycle statuses
  `open`, `triaged`, `planned`, `promoted`, and `wontfix`.
- `heuristic-error-inbox` now provides a workflow skill and deterministic script
  for listing, verifying, creating, and updating curated inbox entries.
- The `heuristic-system-skills` execution state intentionally deferred
  `heuristic-operation-record` and `heuristic-compression-review` until real
  inbox usage exists.
- `skill-usage.record.json` can be corrupted when multiple write commands target
  the same record directory concurrently. This was observed during the original
  GitLab MR evidence capture and again during later workflow evidence handling.
- The GitLab MR inbox entry is now completed as a GitLab-only record. It no
  longer links this future follow-up document; this document keeps the
  provenance link back to the completed entry instead.

## Decisions

- Treat GitLab MR workflow behavior and heuristic-system retention as separate
  problems.
- Close the GitLab MR inbox entry as promoted/resolved for the GitLab workflow
  without leaving future follow-up text inside that completed entry.
- Do not add a new `archived` lifecycle status unless a later plan explicitly
  updates the inbox script, tests, docs, and migration rules.
- Keep this document as the read-first source for future planning. Do not
  implement the heuristic-system follow-up in this step.
- Keep `skill-usage` concurrency handling split by ownership:
  agent-kit owns workflow policy and docs; nils-cli owns primitive-level
  deterministic file writing if locking or atomic updates are implemented.
- Prefer extending `heuristic-error-inbox` with completion/archive-readiness
  behavior before creating a separate broad lifecycle skill.

## Scope

- Define when a promoted inbox entry is considered resolved or archive-ready.
- Design the skill behavior needed to complete an inbox entry without carrying
  unrelated future work inside it.
- Decide whether every promoted inbox entry needs an operation record, or
  whether tests, scripts, skill docs, and runbooks can be sufficient durable
  promotion targets.
- Refine operation-record guidance and decide whether
  `heuristic-operation-record` should become a separate skill.
- Decide when compression review should happen and whether
  `heuristic-compression-review` needs its own skill/script surface.
- Add a durable guardrail for serial `skill-usage` writes and evaluate whether
  primitive-level file locking is required.

## Non-Scope

- Do not reopen the GitLab MR pipeline parsing, skipped-source-CI policy, or
  cleanup fixes.
- Do not create live GitLab or GitHub validation MRs/PRs for this follow-up
  before a plan exists.
- Do not commit raw `skill-usage.record.json` records as trackers.
- Do not add broad heuristic-system lifecycle automation before the narrow inbox,
  operation-record, and compression boundaries are clear.
- Do not implement nils-cli primitive changes inside agent-kit; create a paired
  nils-cli source/plan if primitive locking is selected.

## Implementation Boundaries

### Inbox Resolution And Archive Semantics

The current lifecycle uses `promoted` for fixed and compressed gaps. A later
implementation should either:

- keep `promoted` as the archive-ready state and require a clear durable link
  plus `Next Action: none`; or
- introduce an explicit archive mechanism only with script, tests, docs, and
  migration coverage.

The implementation must preserve the error-inbox rule that entries are curated
evidence, not raw logs.

### Candidate Skill Design

The first candidate should be an extension of `heuristic-error-inbox`, not a
new broad lifecycle skill. The likely behavior is a `complete` or
`archive-ready` workflow that helps an agent:

- verify the entry has a closed lifecycle status such as `promoted` or
  `wontfix`;
- verify the entry has no unresolved backlog, future follow-up, or next-action
  text;
- verify durable evidence links exist for the completed scope;
- optionally record that separate follow-up has moved to a new source document,
  but keep that pointer in the new source document rather than the completed
  entry;
- preserve the inbox entry as a self-contained completion record.

A separate `heuristic-operation-record` skill should be considered only if
operation-record creation becomes larger than an inbox completion helper should
own.

### Operation Records

Operation records should summarize durable lessons from real workflow signals.
The implementation should decide whether operation records are mandatory for
all promoted inbox entries or only for incidents whose durable lesson is broader
than a local test/script/doc fix.

### Compression Review

Compression review should reduce retained records into smaller durable rules.
It should not duplicate `docs-plan-cleanup` or `durable-artifact-cleanup`.
Compression should prefer updates to skills, scripts, tests, runbooks, and
primitive contracts over accumulating narrative records.

### Skill Usage Write Safety

The immediate workflow rule is simple: never run multiple `skill-usage` write
commands against the same record directory in parallel. A later implementation
should decide whether that is enough, or whether nils-cli should provide
file-locking or atomic update guarantees.

## Requirements

- A future implementer can decide how to mark promoted inbox entries as resolved
  without re-reading the GitLab MR incident.
- The GitLab MR inbox entry remains closed for GitLab workflow work after this
  follow-up is split out.
- Completed inbox entries can stand alone without linking unrelated future work.
- The follow-up preserves the distinction between incident-specific workflow
  bugs and cross-workflow heuristic-system gaps.
- Any lifecycle status or archive semantic change must update the
  `heuristic-error-inbox` script, tests, and docs together.
- Any `skill-usage` locking change must identify whether agent-kit docs or the
  nils-cli primitive owns the durable fix.

## Acceptance Criteria

- A plan links this document under `Read First` before heuristic-system follow-up
  implementation begins.
- Inbox lifecycle docs clearly explain how a promoted entry becomes resolved or
  archive-ready.
- The GitLab MR inbox entry remains promoted, GitLab-only, and free of
  unrelated future follow-up text.
- The new completion/archive behavior is designed either as an extension to
  `heuristic-error-inbox` or as a clearly justified narrower skill.
- Operation-record guidance explains when a retained operation record is
  required and when tests/scripts/docs are enough.
- `skill-usage` write safety has either documented serial-write guidance or
  primitive-level locking/atomic update tests.
- Validation covers the affected heuristic-system inbox docs/scripts and the
  skill-usage guidance path.

## Validation Plan

Recommended commands for a future implementation:

```bash
scripts/check.sh --tests -- -k 'heuristic_system or heuristic_error_inbox or skill_usage'
scripts/check.sh --docs
scripts/check.sh --markdown
scripts/check.sh --all
```

If nils-cli primitive changes are selected, add the paired nils-cli validation
commands in the future plan.

## Risks And Guardrails

- Do not weaken the inbox lifecycle by treating unresolved gaps as archived.
- Do not leave future work in a completed inbox entry just to preserve
  traceability; put the provenance link in the new follow-up source instead.
- Do not require operation records for every tiny local fix if a focused test or
  skill-doc update is the better durable artifact.
- Do not let compression produce more narrative surface than it removes.
- Do not hide `skill-usage` corruption risk behind agent discipline if
  primitive-level locking is cheap and reliable.

## Execution

- Recommended next artifact:
  `docs/plans/heuristic-system-retention-follow-up/heuristic-system-retention-follow-up-plan.md`
- Recommended execution-state path:
  `docs/plans/heuristic-system-retention-follow-up/heuristic-system-retention-follow-up-execution-state.md`
- Current execution status: not started.

## Retention Intent

This document is temporary implementation source material. After the follow-up
lands, promote durable lessons into `HEURISTIC_SYSTEM.md`,
`heuristic-system/README.md`, `heuristic-system/error-inbox/README.md`,
operation records, workflow skill docs, tests, or nils-cli primitive docs as
appropriate. Then this plan-source folder can be cleaned up through the normal
plan cleanup flow.

## Open Questions

- Should `archived` become a first-class lifecycle status, or should `promoted`
  plus a durable link and no next action remain the archive-ready state?
- Should inbox completion be a new command on `heuristic-error-inbox`, or a
  separate narrow skill only for close/archive readiness?
- Should `heuristic-operation-record` be a separate skill, or is the current
  retained record convention sufficient?
- How many inbox entries are enough to justify `heuristic-compression-review`?
- Should `skill-usage` concurrency safety be enforced in agent-kit policy only,
  or in the nils-cli primitive with file locking or atomic writes?

## Read-First References

- `heuristic-system/error-inbox/deliver-gitlab-mr-skipped-pipeline-and-cleanup.md`
- `heuristic-system/error-inbox/README.md`
- `heuristic-system/README.md`
- `HEURISTIC_SYSTEM.md`
- `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`
- `docs/plans/heuristic-system-skills/heuristic-system-skills-execution-state.md`
- `docs/plans/gitlab-mr-pipeline-cleanup/gitlab-mr-pipeline-cleanup-execution-state.md`

## Recommended Next Artifact

Use `create-plan` on this source document when the heuristic-system retention
follow-up is ready to implement.
