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
- Local rehearsal mode (`--dry-run`) for full flow testing without GitHub API calls:
  - `start-plan` emits a synthetic plan-issue token (`DRY_RUN_PLAN_ISSUE`).
  - sprint commands default to no comment posting in dry-run.
  - `ready-plan` should use `--body-file`.
  - `close-plan --dry-run` requires `--body-file`.
- Required PR grouping controls (no defaults):
  - `--pr-grouping per-sprint|group` (`per-spring` alias accepted)
  - `--pr-group <task-or-plan-id>=<group>` (repeatable; required for `group`, and must cover every task in scope)

Outputs:

- Plan-scoped task-spec TSV generated from all plan tasks (all sprints) for one issue.
- Sprint-scoped task-spec TSV generated per sprint for subagent dispatch hints, including `pr_group`.
- Exactly one GitHub Issue for the whole plan (`1 plan = 1 issue`).
- Sprint progress tracked on that issue via comments + task decomposition rows/PR links.
- `start-sprint`/`ready-sprint`/`accept-sprint` sync sprint task rows (`Owner/Branch/Worktree/Execution Mode/Notes`) from the sprint task-spec.
- `accept-sprint` additionally enforces sprint PRs are merged and syncs sprint task `Status` to `done`.
- `start-sprint` for sprint `N>1` is blocked until sprint `N-1` is merged and all its task rows are `done`.
- PR references in sprint comments and review tables use canonical `#<number>` format.
- Sprint start comments may still show `TBD` PR placeholders until subagents open PRs and rows are linked.
- `start-sprint` comments append the full markdown section for the active sprint from the plan file (for example Sprint 1/2/3 sections).
- Dispatch hints can open one shared PR for multiple ordered/small tasks when grouped.
- Final issue close only after plan-level acceptance and merged-PR close gate.
- `close-plan` enforces cleanup of all issue-assigned task worktrees before completion.
- `multi-sprint-guide --dry-run` emits a local-only command sequence that avoids GitHub calls.
- Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed, and worktree cleanup passes.
- Error contract: if any gate/command fails, stop forward progress and report the failing command plus key stderr/stdout gate errors.

Exit codes:

- `0`: success
- `1`: runtime failure / gate failure
- `2`: usage error

Failure modes:

- Plan file missing, sprint missing, or selected sprint has zero tasks.
- Required commands missing (`plan-tooling`, `python3`; `gh` required for live GitHub mode).
- Approval URL invalid.
- Final plan close gate fails (task status/PR merge not satisfied).
- Worktree cleanup gate fails (any issue-assigned task worktree still exists after cleanup).
- Attempted transition to a next sprint that does not exist.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh`

## Workflow

1. Plan issue bootstrap (one-time)
   - `start-plan`: parse the full plan, generate one task decomposition covering all sprints, and open one plan issue.
2. Sprint execution loop (repeat on the same plan issue)
   - `start-sprint`: generate sprint task TSV, sync sprint task rows in issue body, post sprint-start comment, emit subagent dispatch hints (supports grouped PR dispatch). For sprint `N>1`, this command requires sprint `N-1` merged+done gate to pass first.
   - `ready-sprint`: post sprint-ready comment to request main-agent review before merge.
   - After review approval, merge sprint PRs.
   - `accept-sprint`: validate sprint PRs are merged, sync sprint task statuses to `done`, and record sprint acceptance comment on the same issue (issue stays open).
   - If another sprint exists, run `start-sprint` for the next sprint on the same issue.
3. Plan close (one-time)
   - `ready-plan`: request final plan review using issue-delivery-loop review helper.
   - `close-plan`: run the plan-level close gate, close the single plan issue, and enforce task worktree cleanup.

## Completion Policy (Mandatory)

- Do not stop after `start-plan`, `start-sprint`, `ready-sprint`, or `accept-sprint` as a final state.
- A successful run must terminate at `close-plan` with:
  - issue state `CLOSED`
  - merged-PR close gate satisfied
  - worktree cleanup gate passing
- If any close gate fails, treat the run as unfinished and report:
  - failing command
  - gate errors (task status, PR merge, approval URL, worktree cleanup)
  - next required unblock action

## Full Skill Flow

1. Confirm the plan file exists and passes `plan-tooling validate`.
2. Run `start-plan` to open exactly one GitHub issue for the whole plan (`1 plan = 1 issue`).
3. Run `start-sprint` for Sprint 1 on that same issue:
   - main-agent posts sprint kickoff comment
   - main-agent chooses PR grouping (`per-sprint` or `group`) and emits dispatch hints
   - subagents create worktrees/PRs and implement tasks
4. While sprint work is active, keep issue task rows + PR links traceable:
   - sprint row metadata is synced from task-spec by sprint commands
   - unresolved PRs remain `TBD`
   - linked PRs should be recorded as `#<number>`
   - optionally run `status-plan` for snapshots
5. When sprint work is ready, run `ready-sprint` to record a sprint review/acceptance request comment.
6. Main-agent reviews sprint PR content, records approval, and merges the sprint PRs.
7. Run `accept-sprint` with the approval comment URL to enforce merged-PR gate and sync sprint task status rows to `done` (issue stays open).
8. If another sprint exists, run `start-sprint` for the next sprint on the same issue; this is blocked until prior sprint is merged+done.
9. After the final sprint is implemented and accepted, run `ready-plan` for the final plan-level review.
10. Run `close-plan` with the final approval comment URL to enforce merged-PR/task gates, close the single plan issue, and force cleanup of task worktrees.

## Role boundary (mandatory)

- Main-agent is orchestration/review-only.
- Main-agent does not implement sprint tasks directly.
- Sprint implementation must be delegated to subagent-owned PRs.
- Sprint comments and plan close actions are main-agent orchestration artifacts; implementation remains subagent-owned.
