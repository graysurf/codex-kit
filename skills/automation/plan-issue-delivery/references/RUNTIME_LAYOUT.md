# Runtime Layout

This document defines the canonical runtime path layout for `plan-issue-delivery`.

## Root

- Fixed root: `RUNTIME_ROOT="$AGENT_HOME/out/plan-issue-delivery"`
- All generated artifacts and assigned worktrees must live under this root.

## Namespacing

- Repository slug: `<repo-slug>` derived from `owner/repo` (recommended form: `owner__repo`).
- Issue root:
  - `ISSUE_ROOT="$RUNTIME_ROOT/<repo-slug>/issue-<ISSUE_NUMBER>"`
- Sprint root:
  - `SPRINT_ROOT="$ISSUE_ROOT/sprint-<N>"`

## Required Artifacts

- Source plan path:
  - `PLAN_SOURCE_PATH="<repo>/docs/plans/...-plan.md"`
- Snapshot fallback (copied at sprint start):
  - `PLAN_SNAPSHOT_PATH="$ISSUE_ROOT/plan/plan.snapshot.md"`
- Sprint prompt outputs:
  - `TASK_PROMPT_PATH="$SPRINT_ROOT/prompts/<TASK_ID>.md"`
  - `PROMPT_MANIFEST_PATH="$SPRINT_ROOT/manifests/prompt-manifest.tsv"`
  - `TASK_SPEC_PATH="$SPRINT_ROOT/specs/sprint-task-spec.tsv"`

## Worktree Layout (Assigned Paths)

All assigned `WORKTREE` values must be absolute paths under:

- `WORKTREE_ROOT="$ISSUE_ROOT/worktrees"`

Execution-mode mapping:

- `pr-isolated`:
  - `"$WORKTREE_ROOT/pr-isolated/<TASK_ID>"`
- `pr-shared`:
  - `"$WORKTREE_ROOT/pr-shared/<PR_GROUP>"`
- `per-sprint`:
  - `"$WORKTREE_ROOT/per-sprint/sprint-<N>"`

## Dispatch Fallback Priority

Subagent plan references should be consumed in this order:

1. Assigned plan task section snippet/link/path (primary).
2. `PLAN_SNAPSHOT_PATH` (fallback).
3. `PLAN_SOURCE_PATH` (last fallback).

If these sources conflict, runtime-truth from the issue `Task Decomposition` row wins.

## Cleanup

`close-plan` must remove issue-assigned task worktrees under `"$ISSUE_ROOT/worktrees"`.
Any leftover worktree path fails the close gate.
