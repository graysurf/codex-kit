# Main-Agent Review Rubric

Purpose: canonical review method for main-agent decisions in issue-driven
delivery loops.

Applies to:

- `skills/workflows/issue/issue-pr-review`
- `skills/automation/issue-delivery`
- `skills/automation/plan-issue-delivery`
- plan-issue main-agent init prompt

## Review Owner

- Main-agent owns review and acceptance decisions.
- Subagent owns implementation changes on the assigned task lane.
- Main-agent must not implement product-code changes while reviewing.

## Review Inputs

- Runtime-truth task row from `Task Decomposition`
- Assigned task prompt / plan task snippet / dispatch record
- PR diff and current PR body
- Validation evidence from subagent
- PR CI / required checks status

## Review Method

1. Verify the review target
   - Confirm the PR matches the intended task lane (`Owner / Branch / Worktree /
     Execution Mode / PR`).
   - Confirm the issue row, dispatch artifacts, and PR all refer to the same
     task scope.

2. Pass hard gates first
   - PR linkage and lane facts are correct.
   - PR body hygiene passes.
   - Required validation evidence is present.
   - Required CI / checks are green, or a blocker is explicitly documented.

3. Review task fidelity
   - Compare the PR against assigned task scope and acceptance intent.
   - Confirm required scope is complete.
   - Reject hidden scope growth or unrelated changes.
   - For shared lanes, confirm each affected task row remains traceable.

4. Review change correctness
   - Check whether the implementation is behaviorally correct.
   - Check regression risk, interface consistency, failure paths, and edge
     cases.
   - Check whether tests/validation cover the actual risk of the change, not
     just a superficial happy path.

5. Review integration readiness
   - Confirm the PR does not depend on an unrelated unmerged lane unless that
     dependency is intentionally modeled.
   - Confirm merge will not block the next lane or sprint gate.
   - Confirm runtime-truth status/PR linkage remains coherent after the
     decision.

## Decision Rules

- `merge`
  - All hard gates pass.
  - Task fidelity is satisfied.
  - No unresolved blocker or integration risk remains.

- `request-followup`
  - Required scope is incomplete.
  - Evidence or tests are insufficient.
  - Behavior/regression risk is unresolved.
  - Integration risk or lane drift is present but still correctable on the same
    lane.

- `close-pr`
  - The PR is on the wrong lane.
  - The PR is superseded or intentionally replaced.
  - The work should not continue on this PR path.

## Execution Mapping

- Use `issue-pr-review request-followup` when the decision is
  `request-followup`.
- Use `issue-pr-review merge` when the decision is `merge`.
- Use `issue-pr-review close-pr` when the decision is `close-pr`.
- Mirror follow-up decisions into the issue timeline with the exact PR comment
  URL so the assigned subagent can continue on the same lane.
- After the decision is executed, apply the shared post-review outcome handling
  in `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`.
