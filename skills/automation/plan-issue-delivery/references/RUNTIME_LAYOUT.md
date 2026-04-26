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

- Review evidence template path:
  - `REVIEW_EVIDENCE_TEMPLATE_PATH="$AGENT_HOME/skills/workflows/issue/issue-pr-review/references/REVIEW_EVIDENCE_TEMPLATE.md"`
- Decision-scoped review evidence artifact path:
  - `REVIEW_EVIDENCE_PATH="$SPRINT_ROOT/reviews/<TASK_ID>-<decision>.md"`
- Source plan path:
  - `PLAN_SOURCE_PATH="<repo>/docs/plans/...-plan.md"`
- Snapshot fallback (copied at sprint start):
  - `PLAN_SNAPSHOT_PATH="$ISSUE_ROOT/plan/plan.snapshot.md"`
- Plan-branch reference artifact (written after `start-plan` runtime init):
  - `PLAN_BRANCH_REF_PATH="$ISSUE_ROOT/plan/plan-branch.ref"`
  - Expected value: one canonical branch name (for example `plan/issue-123`)
- Final integration PR record artifact:
  - `PLAN_INTEGRATION_PR_PATH="$ISSUE_ROOT/plan/plan-integration-pr.md"`
  - Expected fields: integration PR number/URL, head/base branches, merge status
- Final integration PR mention record artifact:
  - `PLAN_INTEGRATION_MENTION_PATH="$ISSUE_ROOT/plan/plan-integration-mention.url"`
  - Expected value: plan issue comment URL that mentions `#<integration-pr-number>`
- Sprint prompt outputs:
  - `TASK_PROMPT_PATH="$SPRINT_ROOT/prompts/<TASK_ID>.md"`
  - `PROMPT_MANIFEST_PATH="$SPRINT_ROOT/manifests/prompt-manifest.tsv"`
  - `TASK_SPEC_PATH="$SPRINT_ROOT/specs/sprint-task-spec.tsv"`
- Task-scoped dispatch record:
  - `DISPATCH_RECORD_PATH="$SPRINT_ROOT/manifests/dispatch-<TASK_ID>.json"`
  - Expected keys: `task_id`, `task_prompt_path`, `plan_snapshot_path`, `worktree`, `branch`,
    `execution_mode`, `pr_group`, `base_branch`, `workflow_role`, optional `runtime_name`, optional `runtime_role`,
    optional `runtime_role_fallback_reason`

## Static Prompt Sources

`plan-issue` 0.8.0 does not emit main/subagent init snapshot files. These
prompts remain static agent-kit sources used by humans or runtime adapters:

- `$AGENT_HOME/prompts/plan-issue-delivery-main-agent-init.md`
- `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`

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

## Branch Contract

- Resolve `DEFAULT_BRANCH` once for the issue (for example `main`).
- Create `PLAN_BRANCH` from `DEFAULT_BRANCH` after `start-plan` and persist it to
  `PLAN_BRANCH_REF_PATH`.
- Sprint PRs must target `PLAN_BRANCH` (`baseRefName == PLAN_BRANCH`) at
  `ready-sprint` and `accept-sprint` gates.
- The only PR targeting `DEFAULT_BRANCH` in this workflow is the final
  integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`).
- Before `close-plan`, main-agent must post one plan issue comment that mentions
  the final integration PR and persist the comment URL at
  `PLAN_INTEGRATION_MENTION_PATH`.
- After each successful `accept-sprint`, main-agent syncs local `PLAN_BRANCH`
  (`git fetch origin --prune` -> `git switch` -> `git pull --ff-only`).
- After successful `close-plan`, main-agent syncs local `DEFAULT_BRANCH`
  (`git fetch origin --prune` -> `git switch` -> `git pull --ff-only`).

## Cleanup

`close-plan` must remove issue-assigned task worktrees under `"$ISSUE_ROOT/worktrees"`. Any leftover worktree path fails the close gate.
