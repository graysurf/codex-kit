---
name: plan-issue-delivery-loop
description: "Orchestrate plan-driven issue delivery by sprint: split plan tasks, dispatch subagent PR work, enforce acceptance gates, and advance to the next sprint without main-agent implementation."
---

# Plan Issue Delivery Loop

## Contract

Prereqs:

- Run inside (or have access to) the target git repository.
- `plan-tooling` available on `PATH` for plan parsing/linting.
- `gh` available on `PATH`, and `gh auth status` succeeds.
- Base orchestration scripts exist:
  - `$AGENT_HOME/skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh`
  - `$AGENT_HOME/skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh`

Inputs:

- Plan file path (`docs/plans/...-plan.md`).
- Plan issue number (after `start-plan` creates the single issue).
- Sprint number for sprint orchestration commands.
- Approval comment URL (`https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`) for:
  - sprint acceptance record comments
  - final plan issue close gate
- Optional repository override (`--repo <owner/repo>`).
- Optional PR grouping controls:
  - `--pr-grouping per-task|manual|auto` (default: `per-task`)
  - `--pr-group <task-or-plan-id>=<group>` (repeatable; for `manual`)

Outputs:

- Plan-scoped task-spec TSV generated from all plan tasks (all sprints) for one issue.
- Sprint-scoped task-spec TSV generated per sprint for subagent dispatch hints, including `pr_group`.
- Exactly one GitHub Issue for the whole plan (`1 plan = 1 issue`).
- Sprint progress tracked on that issue via comments + task decomposition rows/PR links.
- Dispatch hints can open one shared PR for multiple ordered/small tasks when grouped.
- Final issue close only after plan-level acceptance and merged-PR close gate.

Exit codes:

- `0`: success
- `1`: runtime failure / gate failure
- `2`: usage error

Failure modes:

- Plan file missing, sprint missing, or selected sprint has zero tasks.
- Required commands missing (`plan-tooling`, `python3`, `gh` via delegated scripts).
- Approval URL invalid.
- Final plan close gate fails (task status/PR merge not satisfied).
- Attempted transition to a next sprint that does not exist.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh`

## Workflow

1. Plan issue bootstrap (one-time)
   - `start-plan`: parse the full plan, generate one task decomposition covering all sprints, and open one plan issue.
2. Sprint execution loop (repeat on the same plan issue)
   - `start-sprint`: generate sprint task TSV, post sprint-start comment, emit subagent dispatch hints (supports grouped PR dispatch).
   - `ready-sprint`: post sprint-ready comment for sprint-level review/acceptance on the same issue.
   - `accept-sprint`: record sprint acceptance (comment only); plan issue remains open.
   - `next-sprint`: record current sprint acceptance and immediately start the next sprint on the same issue.
3. Plan close (one-time)
   - `ready-plan`: request final plan review using issue-delivery-loop review helper.
   - `close-plan`: run the plan-level close gate and close the single plan issue after final approval.

## Full Skill Flow

1. Confirm the plan file exists and passes `plan-tooling validate`.
2. Run `start-plan` to open exactly one GitHub issue for the whole plan (`1 plan = 1 issue`).
3. Run `start-sprint` for Sprint 1 on that same issue:
   - main-agent posts sprint kickoff comment
   - main-agent chooses PR grouping (`per-task`, `manual`, `auto`) and emits dispatch hints
   - subagents create worktrees/PRs and implement tasks
4. While sprint work is active, use issue task rows + PR links for traceability, and optionally `status-plan` for snapshots.
5. When sprint work is ready, run `ready-sprint` to record a sprint review/acceptance request comment.
6. After sprint acceptance is confirmed, run `accept-sprint` to record the approval comment URL on the plan issue (issue stays open).
7. If another sprint exists, run `next-sprint` (which records current sprint acceptance and starts the next sprint on the same issue), then repeat steps 3-6.
8. After the final sprint is implemented and accepted, run `ready-plan` for the final plan-level review.
9. Run `close-plan` with the final approval comment URL to enforce merged-PR/task gates and close the single plan issue.

## Role boundary (mandatory)

- Main-agent is orchestration/review-only.
- Main-agent does not implement sprint tasks directly.
- Sprint implementation must be delegated to subagent-owned PRs.
- Sprint comments and plan close actions are main-agent orchestration artifacts; implementation remains subagent-owned.
