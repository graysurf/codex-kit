# Plan: Heuristic System Retention Follow-Up

## Overview

Implement the next HEURISTIC_SYSTEM retention slice by making completed
`error-inbox` entries explicitly archive-ready and movable out of the active
inbox. The plan keeps the existing lifecycle statuses, extends
`heuristic-error-inbox` with deterministic archive checks, and updates docs/tests
so fixed entries do not keep inflating the top-level backlog. Operation records,
compression guidance, and `skill-usage` write-safety policy are refined in the
same pass without moving primitive-level locking into agent-kit.

## Read First

- Primary source: `docs/plans/heuristic-system-retention-follow-up/heuristic-system-retention-follow-up-discussion-source.md`
- Source type: `discussion-to-implementation-doc`
- Open questions carried into execution:
  - Confirm whether the physical archive location should remain under
    `heuristic-system/error-inbox/archive/` or move to a sibling
    `heuristic-system/archive/error-inbox/` before implementation starts.

## Scope

- In scope: `heuristic-error-inbox` archive-readiness semantics, a deterministic
  archive command, lifecycle docs, operation-record decision guidance,
  compression guidance, `skill-usage` serial-write policy, focused tests, and
  script smoke specs.
- Out of scope: nils-cli primitive locking changes, broad heuristic-system
  lifecycle automation, reopening the fixed GitLab MR delivery defect, and
  changing GitLab/GitHub provider workflow behavior.

## Assumptions

1. Do not add an `archived` lifecycle status in this implementation. Closed
   entries stay `promoted` or `wontfix`; archive state is represented by location
   and optional archive metadata.
2. The active inbox is the top-level `heuristic-system/error-inbox/*.md` set.
   Archived entries move under `heuristic-system/error-inbox/archive/YYYY/` by
   default so normal list/triage output stays small.
3. A closed entry can be archived only when it has durable outcome evidence,
   `Next Action` clearly says no action remains, and unresolved follow-up has
   been moved to another source document or issue.
4. Operation records are not mandatory for every promoted entry. They are
   required only when the retained signal has cross-skill value, repeated
   behavior, or a broader durable lesson than the local fix already captures.
5. `skill-usage` file locking remains a nils-cli primitive concern. This plan
   adds agent-kit serial-write policy and creates a handoff note only if
   implementation discovers primitive-level locking is still required.

## Sprint 1: Archive Semantics And Policy

**Goal**: Define a small, testable archive model that prevents the active
`error-inbox` from becoming a stale backlog.
**Demo/Validation**:

- Command(s): `scripts/check.sh --docs`, `scripts/check.sh --markdown`
- Verify: docs explain active vs archived inbox entries, archive prerequisites,
  and why no new lifecycle status is introduced.

**PR grouping intent**: group
**Execution Profile**: parallel-x2

### Task 1.1: Define active and archived inbox semantics

- **Location**:
  - `HEURISTIC_SYSTEM.md`
  - `heuristic-system/README.md`
  - `heuristic-system/error-inbox/README.md`
- **Description**: Document that top-level `error-inbox/*.md` files are the
  active backlog and archived records live under
  `heuristic-system/error-inbox/archive/YYYY/`. Define archive prerequisites:
  status is `promoted` or `wontfix`, durable outcome link exists, `Next Action`
  has no remaining work, and any future-system follow-up lives outside the
  completed entry.
- **Dependencies**:
  - none
- **Complexity**: 3
- **Acceptance criteria**:
  - Existing lifecycle statuses remain `open`, `triaged`, `planned`,
    `promoted`, and `wontfix`.
  - Docs distinguish active backlog from archived retained evidence.
  - Docs explicitly say archiving does not delete curated evidence or raw
    evidence pointers.
- **Validation**:
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`

### Task 1.2: Update the heuristic-error-inbox skill contract

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/SKILL.md`
  - `skills/workflows/heuristic-system/README.md`
- **Description**: Extend the skill contract with archive-readiness behavior,
  archive failure modes, and command surface expectations. Make it clear that
  implementation fixes still route outside the inbox skill.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 2
- **Acceptance criteria**:
  - The skill describes `archive` as a lifecycle helper, not a broad
    heuristic-system lifecycle mode.
  - The command surface documents active listing and archived listing behavior.
  - Failure modes cover attempts to archive open/planned entries, entries with
    remaining next actions, missing durable links, or duplicate archive targets.
- **Validation**:
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`

### Task 1.3: Lock policy expectations with docs tests

- **Location**:
  - `tests/test_heuristic_system_docs.py`
- **Description**: Add focused doc assertions for active inbox semantics, archive
  prerequisites, and the operation-record exception rule.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
- **Complexity**: 2
- **Acceptance criteria**:
  - Tests fail if docs stop explaining archive-ready semantics.
  - Tests fail if docs imply every promoted entry needs an operation record.
- **Validation**:
  - `scripts/check.sh --tests -- tests/test_heuristic_system_docs.py`

## Sprint 2: Deterministic Archive Command

**Goal**: Add script support that verifies and moves completed inbox entries out
of the active top-level folder.
**Demo/Validation**:

- Command(s): `scripts/check.sh --tests -- -k heuristic_error_inbox`
- Verify: `heuristic-error-inbox.sh archive` accepts only closed entries,
  writes/moves deterministic archive output, and `list` does not show archived
  records unless requested.

**PR grouping intent**: group
**Execution Profile**: serial

### Task 2.1: Add archive parsing and archive-readiness helpers

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/bin/heuristic_error_inbox.py`
- **Description**: Add helpers to parse `Next Action`, detect closed statuses,
  identify durable non-raw evidence links, compute archive destinations, and
  render archive metadata. Keep the checks conservative and explain any
  non-obvious regex limits in tests rather than comments.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
  - Task 1.3
- **Complexity**: 4
- **Acceptance criteria**:
  - Closed statuses are limited to `promoted` and `wontfix`.
  - `Next Action` bodies beginning with `None.` are treated as no remaining
    action; active instructions are rejected.
  - Durable evidence can be supplied by existing non-raw evidence links or an
    explicit archive command link.
  - Archive destination defaults to
    `heuristic-system/error-inbox/archive/YYYY/<slug>.md`.
- **Validation**:
  - `scripts/check.sh --tests -- -k heuristic_error_inbox`

### Task 2.2: Implement archive and archived listing behavior

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/bin/heuristic_error_inbox.py`
  - `skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh`
- **Description**: Add `archive <entry.md>` with `--link`, `--reason`,
  `--archive-root`, `--date`, `--dry-run`, and `--format text|json` options.
  Update `list` with an explicit `--include-archived` option while preserving
  default active-only output.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 5
- **Acceptance criteria**:
  - `archive --dry-run` reports the destination and readiness result without
    moving files.
  - `archive` refuses open, triaged, planned, malformed, duplicate, or still
    actionable entries.
  - Successful archive moves the file, preserves its content, and adds or updates
    a small `Archive` section with date, reason, and durable link when provided.
  - `list` excludes archived entries by default and includes them with
    `--include-archived`.
- **Validation**:
  - `scripts/check.sh --tests -- -k heuristic_error_inbox`

### Task 2.3: Cover archive behavior in skill tests

- **Location**:
  - `skills/workflows/heuristic-system/heuristic-error-inbox/tests/test_workflows_heuristic_system_heuristic_error_inbox.py`
- **Description**: Add fixture entries for promoted, wontfix, active, malformed,
  missing-link, and duplicate-destination cases.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Tests cover successful archive move for `promoted` and `wontfix`.
  - Tests cover rejection for non-closed statuses and actionable `Next Action`
    content.
  - Tests cover list default active-only behavior and `--include-archived`.
  - Tests cover dry-run output and duplicate archive target protection.
- **Validation**:
  - `scripts/check.sh --tests -- skills/workflows/heuristic-system/heuristic-error-inbox/tests/test_workflows_heuristic_system_heuristic_error_inbox.py`

### Task 2.4: Update script smoke specs

- **Location**:
  - `tests/script_specs/skills/workflows/heuristic-system/heuristic-error-inbox/scripts/heuristic-error-inbox.sh.json`
- **Description**: Update help expectations for the new command surface and add
  a smoke case that exercises a safe archive dry-run against the existing
  promoted GitLab MR entry.
- **Dependencies**:
  - Task 2.2
  - Task 2.3
- **Complexity**: 2
- **Acceptance criteria**:
  - Smoke specs recognize `archive` in help output.
  - Dry-run smoke validates archive readiness without moving tracked files.
- **Validation**:
  - `scripts/check.sh --tests -- -m script_smoke -k heuristic`

## Sprint 3: Operation Records, Compression, And Write Safety

**Goal**: Keep retained learning useful by defining when records are compressed,
when operation records are required, and how agents must serialize skill usage
writes.
**Demo/Validation**:

- Command(s):
  `scripts/check.sh --tests -- -k 'heuristic_system or skill_usage'`,
  `scripts/check.sh --docs`, `scripts/check.sh --markdown`
- Verify: docs preserve the boundary between active inbox, archived entries,
  operation records, compression, and nils-cli primitive responsibilities.

**PR grouping intent**: group
**Execution Profile**: parallel-x2

### Task 3.1: Refine operation-record decision guidance

- **Location**:
  - `HEURISTIC_SYSTEM.md`
  - `heuristic-system/README.md`
  - `heuristic-system/error-inbox/README.md`
  - `heuristic-system/operation-records/github-pr-required-check-gating.md`
- **Description**: Document when a fixed inbox entry should become an operation
  record and when tests, scripts, docs, or skill policy are enough durable
  compression.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 3
- **Acceptance criteria**:
  - Docs avoid forcing operation records for small local fixes.
  - Docs still require operation records for broad lessons, repeated failures,
    or audit-worthy heuristic-system loops.
  - The existing operation record remains a valid example of a broader retained
    lesson.
- **Validation**:
  - `scripts/check.sh --tests -- tests/test_heuristic_system_docs.py`
  - `scripts/check.sh --docs`

### Task 3.2: Add lightweight compression review rules

- **Location**:
  - `HEURISTIC_SYSTEM.md`
  - `heuristic-system/README.md`
  - `skills/workflows/heuristic-system/README.md`
  - `skills/workflows/heuristic-system/heuristic-error-inbox/SKILL.md`
- **Description**: Add a small compression checklist instead of introducing
  `heuristic-compression-review` immediately. Trigger a future dedicated skill
  only after repeated records prove the command surface.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 3
- **Acceptance criteria**:
  - Compression guidance names concrete actions: update skill policy, add tests,
    improve scripts, archive closed entries, or create operation records.
  - Docs identify a threshold for revisiting a dedicated compression skill, such
    as multiple related archived entries in one workflow family.
  - Guidance does not duplicate `docs-plan-cleanup` or
    `durable-artifact-cleanup`.
- **Validation**:
  - `scripts/check.sh --docs`
  - `scripts/check.sh --markdown`

### Task 3.3: Document skill-usage serial-write safety

- **Location**:
  - `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `skills/tools/workflow-evidence/skill-usage/SKILL.md`
- **Description**: Add a workflow rule that agents must not run multiple
  `skill-usage` write commands against the same record directory concurrently.
  Keep deterministic file locking and atomic writes assigned to nils-cli, with a
  separate paired plan only if implementation discovers policy is insufficient.
- **Dependencies**:
  - none
- **Complexity**: 3
- **Acceptance criteria**:
  - Docs state the serial-write rule near the command surface.
  - Docs preserve the primitive boundary: agent-kit owns policy, nils-cli owns
    deterministic writing.
  - No raw `skill-usage.record.json` records are committed as trackers.
- **Validation**:
  - `scripts/check.sh --tests -- tests/test_skill_usage_record_validator.py`
  - `scripts/check.sh --docs`

## Sprint 4: Integration Validation And Plan Cleanup Readiness

**Goal**: Prove the completed flow works end to end and leave a clear cleanup
path for temporary plan coordination artifacts.
**Demo/Validation**:

- Command(s): `scripts/check.sh --all`
- Verify: active inbox listing is small, archived entries are still retrievable,
  docs/tests agree, and the source discussion folder has a cleanup path after
  implementation lands.

**PR grouping intent**: per-sprint
**Execution Profile**: serial

### Task 4.1: Validate the existing promoted GitLab MR entry as archive-ready

- **Location**:
  - `heuristic-system/error-inbox/archive/2026/deliver-gitlab-mr-skipped-pipeline-and-cleanup.md`
  - `skills/workflows/heuristic-system/heuristic-error-inbox/bin/heuristic_error_inbox.py`
- **Description**: Use the new archive command against the existing promoted
  GitLab MR entry, then verify the archived record remains retrievable while the
  top-level active inbox stays small.
- **Dependencies**:
  - Task 2.4
  - Task 3.1
  - Task 3.2
  - Task 3.3
- **Complexity**: 2
- **Acceptance criteria**:
  - Dry-run reports archive-ready before moving the GitLab MR entry.
  - `list` no longer shows it by default and `list --include-archived` still
    finds it after the archive move.
  - The execution state records the archive command and archived path.
- **Validation**:
  - `heuristic-error-inbox.sh list --include-archived --format json`

### Task 4.2: Run the full repo maintenance gate

- **Location**:
  - `scripts/check.sh`
  - `docs/plans/heuristic-system-retention-follow-up/heuristic-system-retention-follow-up-execution-state.md`
- **Description**: Create or update the execution-state ledger during
  implementation, record targeted and full validation, and run the repository
  maintenance gate before reporting the implementation complete.
- **Dependencies**:
  - Task 4.1
- **Complexity**: 2
- **Acceptance criteria**:
  - Execution state records completed tasks, validation commands, archive
    decision, and any nils-cli follow-up.
  - `scripts/check.sh --all` passes or any blocker is recorded with concrete
    command output and next action.
  - Temporary source and plan documents are marked eligible for normal plan
    cleanup only after durable lessons have landed.
- **Validation**:
  - `scripts/check.sh --all`

## Testing Strategy

- Unit: focused Python tests for archive-readiness parsing, archive moves,
  active vs archived listing, duplicate target protection, and rejection of
  still-actionable entries.
- Integration: script smoke specs for help output, active list output, verify,
  and archive dry-run on the promoted GitLab MR entry.
- Docs: `tests/test_heuristic_system_docs.py`, `scripts/check.sh --docs`, and
  `scripts/check.sh --markdown`.
- Full gate: `scripts/check.sh --all` before claiming implementation complete.

## Risks & gotchas

- Archive semantics can hide unfinished work if the command only checks status.
  Mitigation: require closed status, no remaining next action, and durable
  outcome evidence before moving files.
- Physical archive moves can break links from older docs or memories. Mitigation:
  keep archive paths stable, make list support `--include-archived`, and update
  any repo-local references touched by this plan.
- Requiring operation records for every fix would move bloat from inbox to
  operation records. Mitigation: make operation records conditional on broader
  durable value.
- Too much compression tooling too early can create another workflow surface to
  maintain. Mitigation: add checklist guidance first and defer a dedicated
  `heuristic-compression-review` skill until repeated cases prove it.
- `skill-usage` corruption is a primitive-level risk. Mitigation: add immediate
  serial-write policy in agent-kit and create a nils-cli follow-up only if the
  policy is not enough.
- Existing promoted entries may contain historical prose such as findings tables
  or backlog sections with all items done. Mitigation: archive checks should
  reject active `Next Action` content, but avoid broad whole-file keyword scans
  that would create false positives.

## Rollback plan

- Revert the `archive` command and tests if the archive-readiness contract proves
  too ambiguous.
- Move any archived entries back to `heuristic-system/error-inbox/` and remove
  their `Archive` sections if the physical archive layout changes before merge.
- Restore docs to the current lifecycle model: `promoted` and `wontfix` remain
  closed statuses, with no active/archive split.
- Leave nils-cli primitive behavior untouched unless a separate nils-cli plan is
  explicitly created and validated.
