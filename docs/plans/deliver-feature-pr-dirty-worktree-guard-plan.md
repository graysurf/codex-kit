# Plan: deliver-feature-pr dirty worktree guard

## Overview

Relax `deliver-feature-pr` from a hard clean-tree requirement to a risk-gated preflight that still
prevents unrelated changes from being swept into a feature PR. Keep the base-branch intent guard
and CI/close flow unchanged. Add explicit triage rules for staged/unstaged/untracked changes,
including an escalation path for uncertain scope.

## Scope

- In scope:
  - Update `deliver-feature-pr` contract/workflow text to allow dirty trees with guardrails.
  - Implement preflight classification for `staged`, `unstaged`, and `untracked` changes.
  - Add suspicious-signal detection and diff escalation when mixed status is present.
  - Add deterministic stop-and-confirm output when relevance cannot be determined.
  - Preserve existing base-branch guard and `wait-ci`/`close` behavior.
  - Add automated test coverage for preflight branch + worktree gating behavior.
- Out of scope:
  - Rewriting `create-feature-pr` workflow internals.
  - Auto-staging or auto-resetting files on behalf of the user.
  - Changing merge strategy or allowing CI bypass in delivery flow.

## Assumptions

1. The user often invokes `deliver-feature-pr` after implementation work already exists locally.
2. Filename triage is acceptable for single-status change sets unless suspicious signals are present.
3. If the agent cannot confidently classify changes as in-scope, it should stop and ask for
   confirmation rather than proceeding.

## Sprint 1: Specify policy and CLI contract

**Goal**: Encode dirty-worktree guard policy in skill documentation and command contract.

**Demo/Validation**:
- Command(s):
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr.py`
  - `rg -n "mixed-status|single-status|untracked|suspicious|stop-and-confirm|base" skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`
  - `plan-tooling validate --file docs/plans/deliver-feature-pr-dirty-worktree-guard-plan.md`
- Verify:
  - Skill contract remains valid after policy updates.
  - Documentation explicitly covers mixed state handling and escalation criteria.
  - Sprint 1 locks policy vocabulary; executable guardrail behavior is validated in Sprint 2 tests.

### Task 1.1: Update prereqs and failure modes for dirty-tree support
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`
- **Description**: Replace the absolute clean-tree prerequisite with a guarded policy. Document
  preflight branches for three states (`staged`, `unstaged`, `untracked`) and define the two main
  flows: mixed-status (deeper triage) and single-status (quick triage unless suspicious signals are
  hit). Keep branch-intent guard language unchanged.
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - `SKILL.md` no longer requires a globally clean tree before preflight.
  - Mixed and single-status handling rules are explicit and non-ambiguous.
  - Base branch guard remains a mandatory stop gate.
- **Validation**:
  - `rg -n "clean|dirty|mixed|untracked|base" skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`

### Task 1.2: Add suspicious-signal matrix and escalation policy
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`
- **Description**: Add a concrete suspicious-signal section covering at least: cross-domain path
  spread, infra/tooling-only edits unrelated to request, and same-file staged+unstaged overlap.
  Define required escalation: inspect diff for suspicious files, then stop and ask user when still
  uncertain.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Suspicious criteria are checkable and not purely subjective.
  - Same-file staged+unstaged is marked as high-risk by policy.
  - Policy explicitly says "uncertain -> stop and confirm."
- **Validation**:
  - `rg -n "suspicious|uncertain|staged\\+unstaged|escalat|confirm" skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`

### Task 1.3: Define stop-and-confirm output contract
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`
- **Description**: Specify a deterministic output payload when preflight blocks for ambiguity:
  include change-state summary, suspicious file list, why each file is suspicious, and the explicit
  confirmation prompt expected from user before proceeding.
- **Dependencies**:
  - Task 1.2
- **Complexity**: 3
- **Acceptance criteria**:
  - Blocking output fields are defined and reproducible.
  - Policy distinguishes "blocked for ambiguity" from hard command failures.
- **Validation**:
  - `rg -n "block|ambigu|suspicious files|confirmation|prompt" skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`

## Sprint 2: Implement preflight triage and guard behavior

**Goal**: Enforce new dirty-tree policy in `deliver-feature-pr.sh preflight`.

**Demo/Validation**:
- Command(s):
  - `bash -n skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "mixed_status or single_status or base_branch_guard"`
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "stop_and_confirm_payload"`
- Verify:
  - Preflight exits 0 only when policy conditions pass.
  - Ambiguous or suspicious mixed states exit non-zero with actionable guidance.
  - Blocked output includes change-state summary, suspicious files, reasons, and confirmation prompt.

### Task 2.1: Replace strict clean-tree check with state collector
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
- **Description**: Remove unconditional `require_clean_worktree` from preflight and add a reusable
  collector for staged/unstaged/untracked path sets using porcelain-safe git commands. Keep close
  command clean-tree behavior unchanged unless explicitly needed by policy.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Preflight no longer fails merely due to non-empty worktree.
  - Preflight can classify and report staged/unstaged/untracked counts.
  - `close` command still enforces clean tree before merge delegation.
- **Validation**:
  - `bash -n skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "state_summary"`

### Task 2.2: Extend tests for preflight state handling
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr.py`
  - `skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py`
- **Description**: Keep contract/entrypoint tests and add subprocess-based preflight tests in temp
  git repos to cover: mixed-status non-suspicious pass, mixed-status suspicious block, single-status
  fast pass, suspicious single-status escalation, same-file staged+unstaged high-risk handling,
  stop-and-confirm payload fields, and base-branch mismatch hard-fail.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 6
- **Acceptance criteria**:
  - New tests assert both exit codes and key stderr/stdout markers per branch.
  - Existing contract tests remain green.
  - Stop-and-confirm payload fields are asserted in tests.
- **Validation**:
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests`

### Task 2.3: Implement mixed-status triage with diff escalation
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
- **Description**: If staged and unstaged coexist, run filename triage first. For suspicious files,
  inspect minimal diffs to refine classification. If uncertainty remains, emit block output and exit
  1 instead of continuing. Ensure same-file staged+unstaged overlap is always escalated.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 1.2
  - Task 1.3
- **Complexity**: 7
- **Acceptance criteria**:
  - Mixed-status runs filename-first triage and only escalates suspicious paths.
  - Same-file staged+unstaged always triggers deeper inspection.
  - Ambiguous outcomes stop with a clear user-confirmation action.
- **Validation**:
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "mixed_status or same_file_overlap or stop_and_confirm_payload"`

### Task 2.4: Implement single-status fast path with suspicious fallback
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
- **Description**: For all-staged, all-unstaged, or all-untracked states, allow fast filename
  review pass and proceed when no suspicious signals appear. If suspicious signals are detected,
  follow the same escalation-and-confirm path as mixed-status mode.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 1.2
- **Complexity**: 5
- **Acceptance criteria**:
  - Single-status sets can pass preflight after quick triage.
  - Suspicious single-status sets do not auto-pass and must escalate.
  - Preflight log clearly indicates which path (fast or escalated) was used.
- **Validation**:
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "single_status_fast_path or single_status_escalation"`

### Task 2.5: Preserve and sequence base-branch guard after triage
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
- **Description**: Keep existing base branch intent check (`current == --base`) as mandatory guard.
  Ensure messaging differentiates branch mismatch, suspicious ambiguity block, and normal pass.
- **Dependencies**:
  - Task 2.3
  - Task 2.4
- **Complexity**: 4
- **Acceptance criteria**:
  - Base branch mismatch still hard-fails with explicit action guidance.
  - Successful triage does not bypass branch guard.
  - Exit semantics remain compatible with current workflow callers.
- **Validation**:
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "base_branch_guard"`

## Sprint 3: Add tests and rollout safeguards

**Goal**: Ensure policy changes are testable and safe to adopt.

**Demo/Validation**:
- Command(s):
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py`
  - `scripts/check.sh --skills`
- Verify:
  - Operator-facing docs match the tested stop-and-confirm payload and branch-guard behavior.
  - Skill and plan checks pass before PR.

### Task 3.1: Add operator-facing examples to SKILL workflow section
- **Location**:
  - `skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`
- **Description**: Add concise examples for the three preflight outcomes (pass, ambiguity-block,
  branch-mismatch block) so operators can quickly interpret results and decide next action.
- **Dependencies**:
  - Task 2.5
- **Complexity**: 2
- **Acceptance criteria**:
  - Workflow section includes at least one example per outcome class.
  - Ambiguity-block example includes stop-and-confirm payload fields from Task 1.3.
  - Examples align with script output wording and exit behavior.
- **Validation**:
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr.py`
  - `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py -k "stop_and_confirm_payload"`

### Task 3.2: Full lint and plan/tooling validation gate
- **Location**:
  - `docs/plans/deliver-feature-pr-dirty-worktree-guard-plan.md`
  - `skills/workflows/pr/feature/deliver-feature-pr/SKILL.md`
  - `skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh`
- **Description**: Run plan and repo skill checks after implementation to ensure no contract drift.
  Capture failures and fix before opening PR. Confirm this plan remains executable for
  `/execute-plan-parallel` dependency parsing.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 3
- **Acceptance criteria**:
  - `plan-tooling validate` passes for this plan file.
  - Skill checks pass for modified files.
- **Validation**:
  - `plan-tooling validate --file docs/plans/deliver-feature-pr-dirty-worktree-guard-plan.md`
  - `scripts/check.sh --plans`
  - `scripts/check.sh --skills`

## Dependencies and parallelization

- Critical path:
  - Task 1.1 -> Task 1.2 -> Task 1.3 -> Task 2.1 -> Task 2.2 -> (Task 2.3 + Task 2.4 in parallel)
    -> Task 2.5 -> Task 3.1 -> Task 3.2
- Parallelizable window:
  - Task 2.3 and Task 2.4 can run in parallel once Task 2.1/Task 2.2/Task 1.2 are complete.

## Testing Strategy

- Unit: subprocess-level script tests in
  `skills/workflows/pr/feature/deliver-feature-pr/tests/test_workflows_pr_feature_deliver_feature_pr_preflight.py`
  for each preflight decision branch.
- Integration: run `deliver-feature-pr.sh preflight` in temporary git repos with controlled file
  state transitions.
- E2E/manual: run full `deliver-feature-pr` flow in a sandbox repo to confirm PR lifecycle still
  works with dirty-tree preflight enabled.

## Risks & gotchas

- Filename heuristics may over-block legitimate edits until suspicious criteria are calibrated.
- Diff escalation must avoid noisy or expensive full-repo scanning on large change sets.
- Policy text and script behavior can drift without paired test assertions on key output markers.
- Existing users accustomed to strict clean-tree failure may need updated guidance.

## Rollback plan

1. Revert `deliver-feature-pr.sh` preflight to `require_clean_worktree` hard-fail behavior.
2. Restore `SKILL.md` contract to the previous clean-tree prerequisite wording.
3. Remove or quarantine new preflight behavior tests if they enforce the new policy.
4. Re-run `python3 -m pytest -q skills/workflows/pr/feature/deliver-feature-pr/tests` and
   `scripts/check.sh --skills` to verify rollback integrity.
