# Plan: Heuristic System Skills

## Overview

Add a narrow HEURISTIC_SYSTEM workflow skill family beginning with
`heuristic-error-inbox`. The first implementation slice gives agents a stable
entrypoint and deterministic helper script for listing, verifying, creating,
deduplicating, and updating curated `heuristic-system/error-inbox/` entries.
Operation-record promotion and compression review remain future slices until
the inbox workflow has real usage evidence.

## Read First

- Primary source: `docs/plans/heuristic-system-skills/heuristic-system-skills-discussion-source.md`
- Source type: `discussion-to-implementation-doc`
- Open questions carried into execution:
  - none; this plan resolves the source questions as execution assumptions.

## Scope

- In scope:
  - Add `skills/workflows/heuristic-system/heuristic-error-inbox/`.
  - Add a repo-local `heuristic-error-inbox.sh` entrypoint with deterministic
    list, verify, new, and set-status behavior.
  - Add focused tests and smoke specs for valid and invalid inbox fixtures.
  - Update maintained skill catalogs and HEURISTIC_SYSTEM docs that route inbox
    lifecycle work.
- Out of scope:
  - Fix GitLab MR pipeline parsing or cleanup behavior.
  - Add nils-cli primitives for heuristic-system records.
  - Implement `heuristic-operation-record`,
    `heuristic-compression-review`, or an umbrella lifecycle skill.
  - Auto-create inbox entries from hooks or copy raw logs into tracked records.

## Assumptions

1. The first skill name is `heuristic-error-inbox`, matching the source
   document's proposed skill and acceptance criteria.
2. Script output supports plain text by default and JSON with `--format json`
   where the command returns machine-consumable results.
3. Duplicate detection starts with stable low-risk signals: entry slug, title,
   area, and raw evidence pointer.
4. The `heuristic-operation-record` and `heuristic-compression-review` skills
   should stay documented as future slices, not implemented in this pass.

## Sprint 1: Inbox Workflow Slice

**Goal**: Land the first usable HEURISTIC_SYSTEM inbox workflow skill with a
validated deterministic script and docs routing.
**Demo/Validation**:

- Command(s):
  - `scripts/check.sh --tests -- -k 'heuristic_system or heuristic_error_inbox'`
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`
  - `bash scripts/ci/stale-skill-scripts-audit.sh --check`
  - `scripts/check.sh --entrypoint-ownership`
- Verify:
  - Skill contract validates.
  - Script can list and verify committed inbox entries.
  - Test fixtures cover missing sections, invalid status, missing evidence, and
    duplicate detection.

### Task 1.1: Skill Contract And Area

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/SKILL.md`
  - `skills/workflows/heuristic-system/README.md`
  - `README.md`
- **Description**: Add the workflow skill contract, area landing doc, and public
  catalog row while keeping the skill judgment-oriented and narrow.
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - The skill metadata concisely describes when to use it.
  - The contract separates skill judgment from deterministic script checks.
  - Future operation/compression skills are mentioned only as later slices.
- **Validation**:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/workflows/heuristic-system/heuristic-error-inbox/SKILL.md`
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/workflows/heuristic-system/heuristic-error-inbox`

### Task 1.2: Inbox Script

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh`
  - `skills/workflows/heuristic-system/heuristic-error-inbox/bin/heuristic_error_inbox.py`
- **Description**: Implement `list`, `verify`, `new`, and `set-status`
  commands for curated inbox records. Keep writes scoped to a single entry and
  link raw evidence instead of copying raw records.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - `list` reports tracked inbox entries and lifecycle status.
  - `verify` rejects invalid statuses, missing required sections, missing
    evidence pointers, and likely duplicates.
  - `new --from-skill-usage <record-dir> --slug <slug>` creates a curated draft
    from a verified `skill-usage.record.json`.
  - `set-status` updates only the status line and, when provided, records a
    lifecycle link in the next action.
- **Validation**:
  - `scripts/check.sh --tests -- -k heuristic_error_inbox`

### Task 1.3: Tests, Smoke Specs, And Routing Docs

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/tests/test_workflows_heuristic_system_heuristic_error_inbox.py`
  - `tests/script_specs/skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh.json`
  - `HEURISTIC_SYSTEM.md`
  - `heuristic-system/README.md`
  - `heuristic-system/error-inbox/README.md`
  - `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `CHANGELOG.md`
- **Description**: Cover the new behavior with skill-local tests and script
  smoke specs, then update maintained docs that currently route agents to manual
  inbox handling.
- **Dependencies**:
  - Task 1.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Tests cover valid and invalid fixture entries.
  - Script smoke includes help plus at least one non-mutating command.
  - Docs point future agents to `heuristic-error-inbox` for lifecycle work.
- **Validation**:
  - `scripts/check.sh --tests -- -k 'heuristic_system or heuristic_error_inbox'`
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`

## Sprint 2: Future Lifecycle Compression

**Goal**: Use real inbox workflow runs to decide whether operation-record and
compression review skills are ready.
**Demo/Validation**:

- Command(s):
  - `heuristic-error-inbox.sh list`
  - `heuristic-error-inbox.sh verify heuristic-system/error-inbox/<entry>.md`
- Verify:
  - At least one real inbox entry has been created, triaged, planned, promoted,
    or closed through the new workflow.

### Task 2.1: Operation Record Promotion Design

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-operation-record/SKILL.md`
  - `skills/workflows/heuristic-system/heuristic-operation-record/scripts/heuristic-operation-record.sh`
  - `heuristic-system/operation-records/heuristic-error-inbox-promotion.md`
- **Description**: After real inbox usage, decide whether
  `heuristic-operation-record` should become a separate skill and script.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 3
- **Acceptance criteria**:
  - Promotion workflow is based on observed inbox usage, not speculative
    architecture.
  - Raw runtime evidence stays linked, not copied.
- **Validation**:
  - To be defined in the follow-up source document or execution state.

### Task 2.2: Compression Review Design

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-compression-review/SKILL.md`
  - `skills/workflows/heuristic-system/heuristic-compression-review/scripts/heuristic-compression-review.sh`
  - `HEURISTIC_SYSTEM.md`
- **Description**: Decide whether a periodic
  `heuristic-compression-review` entrypoint is useful after enough entries exist
  to group repeated lessons.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 2
- **Acceptance criteria**:
  - Recommendations keep the skill surface smaller after compression.
  - The workflow does not overlap `docs-plan-cleanup` or
    `durable-artifact-cleanup`.
- **Validation**:
  - To be defined after Sprint 1 adoption evidence exists.

## Testing Strategy

- Unit: skill-local Python tests for parsing, verification, duplicate detection,
  record creation, and status updates.
- Integration: repo `scripts/check.sh --tests -- -k 'heuristic_system or heuristic_error_inbox'`,
  docs freshness, markdown lint, entrypoint ownership, and stale script specs.
- E2E/manual: run `heuristic-error-inbox.sh list` and verify the existing
  GitLab MR skipped-pipeline inbox entry without mutating it.

## Risks & gotchas

- Script logic must not decide whether a gap deserves an entry; that judgment
  belongs in the skill.
- Generated drafts must summarize and link raw evidence, not copy raw logs.
- Duplicate detection should be useful but conservative; ambiguous matches
  should warn instead of silently updating the wrong entry.
- The first slice should not grow into a generic HEURISTIC_SYSTEM lifecycle
  skill before real inbox usage validates the surface.

## Rollback plan

- Remove the new `heuristic-error-inbox` skill directory, script specs, and
  catalog/doc references.
- Keep the source handoff and execution state until rollback validation records
  what was removed and why.
