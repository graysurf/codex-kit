# Task Lane Continuity

Purpose: canonical continuity policy for issue-related workflows.

Applies to:

- `skills/workflows/issue/issue-lifecycle`
- `skills/workflows/issue/issue-pr-review`
- `skills/workflows/issue/issue-subagent-pr`
- `skills/automation/issue-delivery`
- `skills/automation/plan-issue-delivery`
- plan-issue main/subagent init prompts

## Canonical Lane Model

- `Task Decomposition` is the runtime execution source of truth.
- Once a task is assigned, the canonical task lane is defined by:
  - `Owner`
  - `Branch`
  - `Worktree`
  - `Execution Mode`
  - `PR`
- For `pr-shared` and `per-sprint`, multiple task rows may share one lane.
- A review request or clarification request does not create a new lane by
  itself.

## Continuity Rule

- Initial implementation, clarification, CI fixes, and review follow-up stay on
  the same assigned lane until merge/close.
- Main-agent remains orchestration/review-only.
- Subagent remains implementation owner for the assigned lane.
- Do not invent replacement branch/worktree/PR facts just because work pauses
  and resumes.
- Merge or close ends the active lane; after `close-pr`, future work requires
  explicit replacement or unblock handling before implementation resumes.

## Blocker Handling

- If required context is missing/conflicting, or an external dependency blocks
  forward progress, stop and preserve current lane facts.
- Return a blocker packet with:
  - confirmed task-lane facts
  - exact missing/conflicting input or external blocker
  - current status (`blocked` or `in-progress`)
  - exact next unblock action needed
- Use `blocked` while the lane is waiting on clarification or another external
  unblock.
- Use `in-progress` while the lane is actively implementing, fixing CI, or
  addressing requested follow-up.

## Reassignment Rule

- Reassignment is explicit, not implicit.
- Default follow-up path is back to the current task-lane owner.
- Replacement subagent dispatch is allowed only when the original subagent
  cannot continue or when lane facts must intentionally change.
- When reassigning, preserve the issue row and existing PR linkage unless the
  row is intentionally updated first.

## Practical Effect

- Main-agent should route clarification and review follow-up back to the same
  lane by default.
- Subagent should re-enter the assigned worktree/branch/PR lane when it already
  exists.
- New worktree/branch/PR creation should happen only when the assigned lane
  does not exist yet, or after explicit reassignment.
- A closed lane must not be resumed implicitly; treat it as retired until
  main-agent updates the authoritative row or declares an explicit replacement.
