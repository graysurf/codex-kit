---
name: plan-issue-delivery
description: "Orchestrate plan-driven issue delivery by sprint: split plan tasks, dispatch subagent PR work, enforce acceptance gates, and advance to the next sprint without main-agent implementation."
---

# Plan Issue Delivery

## Contract

Prereqs:

- Run inside (or have access to) the target git repository.
- `plan-tooling` available on `PATH` for plan parsing/linting.
- `plan-issue` available on `PATH` for live GitHub orchestration mode.
- `gh` available on `PATH`, and `gh auth status` succeeds only when using live mode (`plan-issue`).

Inputs:

- Plan file path (`docs/plans/...-plan.md`).
- Plan issue number (`--issue <number>`) after `start-plan` creates the single issue.
- Sprint number for sprint orchestration commands.
- Sprint approval comment URL (`SPRINT_APPROVED_COMMENT_URL`) for `accept-sprint`.
- Plan-close approval comment URL (`PLAN_APPROVED_COMMENT_URL`) for `close-plan`.
- Approval URL format for both gates: `https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`.
- Optional repository override (`--repo <owner/repo>`) in live mode.
- Typed subcommands: `start-plan`, `start-sprint`, `link-pr`, `ready-sprint`, `accept-sprint`, `status-plan`, `ready-plan`, `close-plan`.
- Mandatory subagent dispatch bundle:
  - rendered `TASK_PROMPT_PATH` from `start-sprint`
  - `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`
  - plan task context per assignment (exact plan task section snippet and/or direct plan section link/path)
- Local rehearsal policy:
  - Default execution path is live mode (`plan-issue`) in this main skill.
  - If the user explicitly requests rehearsal, load `references/LOCAL_REHEARSAL.md` and run that playbook.
- Required PR grouping controls:
  - Authoritative grouping rules live in `## PR Grouping Steps (Mandatory)`.
  - Keep grouping flags consistent across `start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`.

Outputs:

- Plan-scoped task-spec TSV generated from all plan tasks (all sprints) for one issue.
- Sprint-scoped task-spec TSV generated per sprint for subagent dispatch hints, including `pr_group`.
- Sprint-scoped rendered subagent prompt files + a prompt manifest (`task_id -> prompt_path -> execution_mode`) generated at `start-sprint`.
- `plan-tooling split-prs` v2 emits grouping primitives only (`task_id`, `summary`, `pr_group`); `plan-issue` materializes runtime metadata (`Owner/Branch/Worktree/Notes`).
- Live mode (`plan-issue`) creates/updates exactly one GitHub Issue for the whole plan (`1 plan = 1 issue`).
- `## Task Decomposition` remains runtime-truth for execution lanes; `start-sprint` validates drift against plan-derived lane metadata before emitting artifacts.
- Sprint task-spec/prompts are derived artifacts from runtime-truth rows (not a second execution source of truth).
- `link-pr` normalizes PR references to canonical `#<number>` and updates task `PR`/`Status` fields.
- `link-pr --task <task-id>` auto-syncs all rows in the same runtime lane (`per-sprint`/`pr-shared`) to keep shared-lane PR/state consistent.
- `link-pr --sprint <n>` must resolve to a single runtime lane; use `--pr-group <group>` when sprint `n` has multiple shared lanes.
- `accept-sprint` additionally enforces sprint PRs are merged and syncs sprint task `Status` to `done` in live mode.
- `start-sprint` for sprint `N>1` is blocked until sprint `N-1` is merged and all its task rows are `done`.
- PR references in sprint comments and review tables use canonical `#<number>` format.
- Sprint start comments may still show `TBD` PR placeholders until subagents open PRs and rows are linked.
- `start-sprint` comments append the full markdown section for the active sprint from the plan file (for example Sprint 1/2/3 sections).
- Dispatch hints can open one shared PR for multiple ordered/small tasks when grouped.
- Main-agent must launch subagents with the full dispatch bundle:
  - rendered `TASK_PROMPT_PATH` artifact
  - `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`
  - plan task section context (snippet/link/path)
- Ad-hoc dispatch prompts that bypass the required bundle are invalid.
- Final issue close only after plan-level acceptance and merged-PR close gate.
- `close-plan` enforces cleanup of all issue-assigned task worktrees before completion.
- Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed (live mode), and worktree cleanup passes.
- Error contract: if any gate/command fails, stop forward progress and report the failing command plus key stderr/stdout gate errors.

Exit codes:

- `0`: success
- `1`: runtime failure / gate failure
- `2`: usage error

Failure modes:

- Plan file missing, sprint missing, or selected sprint has zero tasks.
- Required commands missing (`plan-tooling`, `plan-issue`; `gh` only required for live GitHub mode).
- Typed argument validation fails (unknown subcommand, invalid flag, malformed `--pr-group`, invalid `--pr-grouping`).
- `link-pr` PR selector invalid (`--pr` must resolve to a concrete PR number).
- `link-pr` target ambiguous (for example sprint selector spans multiple runtime lanes without `--pr-group`).
- Live mode approval URL invalid.
- Subagent dispatch launched without required bundle (`TASK_PROMPT_PATH`, `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`, plan task section snippet/link/path).
- Final plan close gate fails (task status/PR merge not satisfied in live mode).
- Worktree cleanup gate fails (any issue-assigned task worktree still exists after cleanup).
- Attempted transition to a next sprint that does not exist.

## Binaries (only entrypoints)

- `plan-issue` (live GitHub orchestration)

## References

- Local rehearsal playbook (`plan-issue-local` and `plan-issue --dry-run`): `references/LOCAL_REHEARSAL.md`

## Workflow

1. Validate the plan (`plan-tooling validate`) and lock grouping policy (`group + auto` by default).
2. Run `start-plan`, then capture the emitted issue number once and reuse it for all later commands.
3. Run `start-sprint`, dispatch subagents from generated `TASK_PROMPT_PATH` artifacts, and keep row state current via `link-pr`.
4. For each sprint: `ready-sprint` -> main-agent review/merge -> `accept-sprint`.
5. Repeat step 4 for each next sprint (`start-sprint` is blocked until prior sprint is merged+done).
6. After final sprint acceptance, run `ready-plan`, then `close-plan` with plan-level approval URL.
7. If rehearsal is explicitly requested, switch to `references/LOCAL_REHEARSAL.md`.

## PR Grouping Steps (Mandatory)

1. Resolve grouping intent from user instructions before any split command.
2. If the user did not explicitly request grouping behavior, lock to default `group + auto` (`--pr-grouping group --strategy auto`).
3. Use explicit `group + deterministic` only when the user explicitly requests deterministic/manual grouping.
   - You must pass `--pr-group` and cover every task in scope.
4. Use explicit `per-sprint` only when the user explicitly requests one shared lane per sprint.
   - Do not pass `--pr-group`; all tasks in the sprint share one PR group anchor.
5. Keep the same grouping flags across the same sprint flow (`start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`) to avoid row/spec drift.

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
2. Default execution mode is live (`plan-issue ...`).
3. If the user explicitly asks for local rehearsal, switch to `references/LOCAL_REHEARSAL.md` instead of mixing rehearsal commands into this flow.
4. Lock PR grouping policy from user intent:
   - no explicit user request: use `group + auto`
   - explicit request for deterministic/manual grouping: use `group + deterministic` with full `--pr-group` coverage
   - explicit request for one-shared-lane-per-sprint behavior: use `per-sprint`
5. Run `start-plan` to initialize plan orchestration (`1 plan = 1 issue` in live mode).
6. Capture the issue number immediately after `start-plan` and store it for reuse:
   - Example: `ISSUE_NUMBER=<start-plan output issue number>`
   - Every follow-up command in this flow should use `--issue "$ISSUE_NUMBER"`.
7. Run `start-sprint` for Sprint 1 on the same plan issue token/number:
   - main-agent follows the locked grouping policy (default `group + auto`; switch only on explicit user request) and emits dispatch hints
   - main-agent starts subagents using dispatch bundles that include:
     - rendered `TASK_PROMPT_PATH` prompt artifact from dispatch hints
     - `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`
     - assigned plan task section snippet/link/path (from plan file or sprint-start comment section)
   - subagents create worktrees/PRs and implement tasks
8. While sprint work is active, link each subagent PR into runtime-truth rows with `link-pr`:
   - task scope: `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - sprint scope: `plan-issue link-pr --issue <number> --sprint <n> --pr-group <group> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - `--task` auto-syncs shared lanes; `--sprint` without `--pr-group` is valid only when the sprint target resolves to one runtime lane.
9. Optionally run `status-plan` checkpoints to keep plan-level progress snapshots traceable.
10. When sprint work is ready, run `ready-sprint` to record a sprint review/acceptance request (live comment in live mode).
11. Main-agent reviews sprint PR content, records approval, and merges the sprint PRs.
12. Run `accept-sprint` with `SPRINT_APPROVED_COMMENT_URL` in live mode to enforce merged-PR gate and sync sprint task status rows to `done` (issue stays open).
13. If another sprint exists, run `start-sprint` for the next sprint on the same issue; this is blocked until prior sprint is merged+done.
14. After the final sprint is implemented and accepted, run `ready-plan` for final review:
   - `plan-issue ready-plan --issue <number> [--repo <owner/repo>]`
15. Run `close-plan` with `PLAN_APPROVED_COMMENT_URL` in live mode to enforce merged-PR/task gates, close the single plan issue, and force cleanup of task worktrees:
   - `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`

## Command-Oriented Flow

Default command templates in this section use the fixed policy `--pr-grouping group --strategy auto`.
Only switch to `group + deterministic` or `per-sprint` when the user explicitly requests that behavior.
Capture the `ISSUE_NUMBER` output from `start-plan` once, then reuse it in all `--issue` flags.
Keep approval URLs explicit per gate: `SPRINT_APPROVED_COMMENT_URL` for `accept-sprint`, `PLAN_APPROVED_COMMENT_URL` for `close-plan`.

1. Live mode (`plan-issue`)
   - Validate: `plan-tooling validate --file <plan.md>`
   - Start plan: `plan-issue start-plan --plan <plan.md> --pr-grouping group --strategy auto [--repo <owner/repo>]`
   - Start sprint: `plan-issue start-sprint --plan <plan.md> --issue <number> --sprint <n> --pr-grouping group --strategy auto [--repo <owner/repo>]`
   - Link PR (task scope): `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>] [--repo <owner/repo>]`
   - Link PR (sprint lane scope): `plan-issue link-pr --issue <number> --sprint <n> [--pr-group <group>] --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>] [--repo <owner/repo>]`
   - Status checkpoint (optional): `plan-issue status-plan --issue <number> [--repo <owner/repo>]`
   - Ready sprint: `plan-issue ready-sprint --plan <plan.md> --issue <number> --sprint <n> --pr-grouping group --strategy auto [--repo <owner/repo>]`
   - Accept sprint: `plan-issue accept-sprint --plan <plan.md> --issue <number> --sprint <n> --pr-grouping group --strategy auto --approved-comment-url <comment-url> [--repo <owner/repo>]`
   - Ready plan: `plan-issue ready-plan --issue <number> [--repo <owner/repo>]`
   - Close plan: `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
2. Explicit override patterns (only when user explicitly requests):
  - Deterministic/manual split: replace `--strategy auto` with `--strategy deterministic` and pass full `--pr-group <task-id>=<group>` coverage.
  - Per-sprint single lane: replace `--pr-grouping group --strategy auto` with `--pr-grouping per-sprint` and do not pass `--pr-group`.

## Role boundary (mandatory)

- Main-agent is orchestration/review-only.
- Main-agent does not implement sprint tasks directly.
- Sprint implementation must be delegated to subagent-owned PRs.
- Sprint comments and plan close actions are main-agent orchestration artifacts; implementation remains subagent-owned.
