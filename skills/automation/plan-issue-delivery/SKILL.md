---
name: plan-issue-delivery
description:
  "Orchestrate plan-driven issue delivery by sprint: split plan tasks, dispatch subagent PR work, enforce acceptance gates, and advance to
  the next sprint without main-agent implementation."
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
- Runtime workspace root (fixed): `$AGENT_HOME/out/plan-issue-delivery`.
- Repository slug for runtime namespacing (derived from `--repo <owner/repo>` or local git remote).
- Plan issue number (`--issue <number>`) after `start-plan` creates the single issue.
- Sprint number for sprint orchestration commands.
- Sprint approval comment URL (`SPRINT_APPROVED_COMMENT_URL`) for `accept-sprint`.
- Plan-close approval comment URL (`PLAN_APPROVED_COMMENT_URL`) for `close-plan`.
- Approval URL format for both gates: `https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`.
- Optional repository override (`--repo <owner/repo>`) in live mode.
- Typed subcommands: `start-plan`, `start-sprint`, `link-pr`, `ready-sprint`, `accept-sprint`, `status-plan`, `ready-plan`, `close-plan`.
- Mandatory subagent dispatch bundle:
  - rendered `TASK_PROMPT_PATH` from `start-sprint`
  - sprint-scoped `SUBAGENT_INIT_SNAPSHOT_PATH` copied from `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`
  - issue-scoped `PLAN_SNAPSHOT_PATH` copied from the source plan at sprint start
  - task-scoped `DISPATCH_RECORD_PATH` (for example `.../manifests/dispatch-<TASK_ID>.json`) with artifact paths + execution facts
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
- Runtime artifacts and worktrees are namespaced under `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-<number>/...`.
- Issue-scoped plan snapshot (`PLAN_SNAPSHOT_PATH`) is generated for dispatch fallback.
- Sprint-scoped subagent companion prompt snapshot (`SUBAGENT_INIT_SNAPSHOT_PATH`) is generated for immutable dispatch.
- Task-scoped dispatch records (`DISPATCH_RECORD_PATH`) are generated per assignment for traceability.
- `plan-tooling split-prs` v2 emits grouping primitives only (`task_id`, `summary`, `pr_group`); `plan-issue` materializes runtime metadata
  (`Owner/Branch/Worktree/Notes`).
- Live mode (`plan-issue`) creates/updates exactly one GitHub Issue for the whole plan (`1 plan = 1 issue`).
- `## Task Decomposition` remains runtime-truth for execution lanes; `start-sprint` validates drift against plan-derived lane metadata
  before emitting artifacts.
- Sprint task-spec/prompts are derived artifacts from runtime-truth rows (not a second execution source of truth).
- `link-pr` normalizes PR references to canonical `#<number>` and updates task `PR`/`Status` fields.
- `link-pr --task <task-id>` auto-syncs all rows in the same runtime lane (`per-sprint`/`pr-shared`) to keep shared-lane PR/state
  consistent.
- `link-pr --sprint <n>` must resolve to a single runtime lane; use `--pr-group <group>` when sprint `n` has multiple shared lanes.
- `accept-sprint` additionally enforces sprint PRs are merged and syncs sprint task `Status` to `done` in live mode.
- `start-sprint` for sprint `N>1` is blocked until sprint `N-1` is merged and all its task rows are `done`.
- PR references in sprint comments and review tables use canonical `#<number>` format.
- Sprint start comments may still show `TBD` PR placeholders until subagents open PRs and rows are linked.
- `start-sprint` comments append the full markdown section for the active sprint from the plan file (for example Sprint 1/2/3 sections).
- Dispatch hints can open one shared PR for multiple ordered/small tasks when grouped.
- Main-agent must launch subagents with the full dispatch bundle:
  - rendered `TASK_PROMPT_PATH` artifact
  - `SUBAGENT_INIT_SNAPSHOT_PATH` artifact from `$AGENT_HOME/out/plan-issue-delivery/...`
  - `PLAN_SNAPSHOT_PATH` artifact from `$AGENT_HOME/out/plan-issue-delivery/...`
  - `DISPATCH_RECORD_PATH` artifact from `$AGENT_HOME/out/plan-issue-delivery/...`
  - plan task section context (snippet/link/path)
- Ad-hoc dispatch prompts that bypass the required bundle are invalid.
- Final issue close only after plan-level acceptance and merged-PR close gate.
- `close-plan` enforces cleanup of all issue-assigned task worktrees before completion.
- Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed (live mode), and worktree cleanup passes.
- Error contract: if any gate/command fails, stop forward progress and report the failing command plus key stderr/stdout gate errors.
- Runtime task lanes stay stable across implementation, clarification, CI, and review follow-up unless main-agent explicitly reassigns them.

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
- Runtime workspace root missing/unwritable (`$AGENT_HOME/out/plan-issue-delivery`).
- Sprint runtime artifacts missing (for example `TASK_PROMPT_PATH`, `PLAN_SNAPSHOT_PATH`, `SUBAGENT_INIT_SNAPSHOT_PATH`, or
  `DISPATCH_RECORD_PATH` not emitted under runtime root).
- Subagent dispatch launched without required bundle (`TASK_PROMPT_PATH`, `SUBAGENT_INIT_SNAPSHOT_PATH`, `PLAN_SNAPSHOT_PATH`,
  `DISPATCH_RECORD_PATH`, plan task section snippet/link/path).
- Assigned task `Worktree` is outside `$AGENT_HOME/out/plan-issue-delivery/...`.
- Final plan close gate fails (task status/PR merge not satisfied in live mode).
- Worktree cleanup gate fails (any issue-assigned task worktree still exists after cleanup).
- Attempted transition to a next sprint that does not exist.

## Runtime Workspace Policy (Mandatory)

- Use one runtime root for this skill only: `RUNTIME_ROOT="$AGENT_HOME/out/plan-issue-delivery"`.
- Namespace by repository and issue:
  - `ISSUE_ROOT="$RUNTIME_ROOT/<repo-slug>/issue-<ISSUE_NUMBER>"`
  - `SPRINT_ROOT="$ISSUE_ROOT/sprint-<N>"`
- Required runtime artifacts:
  - `PLAN_SNAPSHOT_PATH="$ISSUE_ROOT/plan/plan.snapshot.md"`
  - `TASK_PROMPT_PATH="$SPRINT_ROOT/prompts/<TASK_ID>.md"`
  - `SUBAGENT_INIT_SNAPSHOT_PATH="$SPRINT_ROOT/prompts/plan-issue-delivery-subagent-init.snapshot.md"`
  - prompt manifest under `"$SPRINT_ROOT/manifests/"`
  - `DISPATCH_RECORD_PATH="$SPRINT_ROOT/manifests/dispatch-<TASK_ID>.json"`
- Worktree path rules (must be absolute paths under `"$ISSUE_ROOT/worktrees"`):
  - `pr-isolated`: `.../worktrees/pr-isolated/<TASK_ID>`
  - `pr-shared`: `.../worktrees/pr-shared/<PR_GROUP>`
  - `per-sprint`: `.../worktrees/per-sprint/sprint-<N>`
- `start-sprint` must copy the source plan into `PLAN_SNAPSHOT_PATH` before subagent dispatch.
- `start-sprint` must copy `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md` into `SUBAGENT_INIT_SNAPSHOT_PATH` before subagent
  dispatch.
- `start-sprint` must emit one `DISPATCH_RECORD_PATH` per assigned task before subagent dispatch.
- Subagent plan reference priority:
  - assigned plan task snippet/link/path (primary)
  - `PLAN_SNAPSHOT_PATH` (fallback)
  - source plan path (last fallback)
- `close-plan` must enforce worktree cleanup under `"$ISSUE_ROOT/worktrees"`; leftovers fail the close gate.

## Task Lane Continuity (Mandatory)

- Follow the shared task-lane continuity policy:
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Treat each runtime row as one task lane that stays stable until merge/close.
- If a lane is blocked on missing/conflicting context or an external
  dependency, keep the lane assignment intact, sync `blocked`, and resume the
  same lane after clarification/unblock.
- Replacement subagent dispatch is exceptional; when it happens, preserve
  runtime-truth facts and existing PR linkage unless the row is intentionally
  updated first.

## Binaries (only entrypoints)

- `plan-issue` (live GitHub orchestration)

## References

- Local rehearsal playbook (`plan-issue-local` and `plan-issue --dry-run`): `references/LOCAL_REHEARSAL.md`
- Runtime layout and path rules: `references/RUNTIME_LAYOUT.md`
- Shared task-lane continuity policy (canonical):
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Shared main-agent review rubric (canonical):
  `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
- Shared post-review outcome handling (canonical):
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`

## Workflow

1. Validate the plan (`plan-tooling validate`) and lock grouping policy
   (metadata-first `--strategy auto --default-pr-grouping group` by default).
2. Run `start-plan`, then capture the emitted issue number once and reuse it for all later commands.
3. Initialize issue runtime workspace under `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-<number>/`.
4. Run `start-sprint`, ensure `TASK_PROMPT_PATH` + `PLAN_SNAPSHOT_PATH` + `SUBAGENT_INIT_SNAPSHOT_PATH` + `DISPATCH_RECORD_PATH` artifacts
   exist, dispatch subagents, keep task lanes stable, and keep row state current via `link-pr`.
5. For each sprint: implement/clarify/follow-up on subagent-owned lanes -> `ready-sprint` -> main-agent review/merge -> `accept-sprint`.
6. Repeat step 5 for each next sprint (`start-sprint` is blocked until prior sprint is merged+done).
7. After final sprint acceptance, run `ready-plan`, then `close-plan` with plan-level approval URL.
8. If rehearsal is explicitly requested, switch to `references/LOCAL_REHEARSAL.md`.

## PR Grouping Steps (Mandatory)

1. Resolve grouping intent from user instructions before any split command.
2. If the user did not explicitly request grouping behavior, lock to
   metadata-first auto (`--strategy auto --default-pr-grouping group`).
3. Use explicit `group + deterministic` only when the user explicitly requests deterministic/manual grouping.
   - You must pass `--pr-group` and cover every task in scope.
4. Use explicit `per-sprint` only when the user explicitly requests one shared lane per sprint.
   - Use `--strategy deterministic --pr-grouping per-sprint`.
   - Do not pass `--pr-group`; all tasks in the sprint share one PR group anchor.
5. Keep the same grouping arguments across the same sprint flow
   (`start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`) to avoid
   row/spec drift.

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
3. If the user explicitly asks for local rehearsal, switch to `references/LOCAL_REHEARSAL.md` instead of mixing rehearsal commands into this
   flow.
4. Lock PR grouping policy from user intent:
   - no explicit user request: use metadata-first auto
     (`--strategy auto --default-pr-grouping group`)
   - explicit request for deterministic/manual grouping: use
     `--strategy deterministic --pr-grouping group` with full `--pr-group`
     coverage
   - explicit request for one-shared-lane-per-sprint behavior: use
     `--strategy deterministic --pr-grouping per-sprint`
5. Run `start-plan` to initialize plan orchestration (`1 plan = 1 issue` in live mode).
6. Capture the issue number immediately after `start-plan` and store it for reuse:
   - Example: `ISSUE_NUMBER=<start-plan output issue number>`
   - Every follow-up command in this flow should use `--issue "$ISSUE_NUMBER"`.
7. Initialize issue runtime workspace and plan snapshot:
   - Runtime root: `$AGENT_HOME/out/plan-issue-delivery`
   - Issue root: `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER`
   - Snapshot path: `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan.snapshot.md`
   - Subagent init snapshot path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/sprint-<N>/prompts/plan-issue-delivery-subagent-init.snapshot.md`
   - Dispatch record path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/sprint-<N>/manifests/dispatch-<TASK_ID>.json`
8. Run `start-sprint` for Sprint 1 on the same plan issue token/number:
   - main-agent follows the locked grouping policy (default metadata-first auto
     with `--default-pr-grouping group`; switch only on explicit user request)
     and emits dispatch hints
   - main-agent starts subagents using dispatch bundles that include:
     - rendered `TASK_PROMPT_PATH` prompt artifact from dispatch hints
     - `SUBAGENT_INIT_SNAPSHOT_PATH` copied from `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`
     - `PLAN_SNAPSHOT_PATH` from issue runtime workspace
     - `DISPATCH_RECORD_PATH` from sprint manifest artifacts
     - assigned plan task section snippet/link/path (from plan file or sprint-start comment section)
   - subagents create or re-enter assigned worktrees/PRs and implement tasks on their assigned lanes
9. While sprint work is active, link each subagent PR into runtime-truth rows with `link-pr`:
   - task scope: `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - sprint scope:
     `plan-issue link-pr --issue <number> --sprint <n> --pr-group <group> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - `--task` auto-syncs shared lanes; `--sprint` without `--pr-group` is valid only when the sprint target resolves to one runtime lane.
   - Use `in-progress` while a lane is actively implementing, fixing CI, or addressing review follow-up.
   - Use `blocked` while a lane is waiting on missing/conflicting context or another external unblock.
10. If a lane is blocked by missing/conflicting context or another external dependency, stop forward progress, clarify/unblock it, and send
    work back to that same lane by default.
11. Optionally run `status-plan` checkpoints to keep plan-level progress snapshots traceable.
12. When sprint work is ready, run `ready-sprint` to record a sprint review/acceptance request (live comment in live mode).
13. Main-agent reviews each sprint PR against the shared review rubric
    (`skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`),
    then records approval and requests follow-up back to the same
    subagent-owned lanes or merges the PRs.
14. After each review decision, apply
    `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md` to sync
    runtime-truth rows before any further dispatch or acceptance gate.
15. Run `accept-sprint` with `SPRINT_APPROVED_COMMENT_URL` in live mode to enforce merged-PR gate and sync sprint task status rows to `done`
    (issue stays open).
16. If another sprint exists, run `start-sprint` for the next sprint on the same issue; this is blocked until prior sprint is merged+done.
17. After the final sprint is implemented and accepted, run `ready-plan` for
    final review:
    `plan-issue ready-plan --issue <number> [--repo <owner/repo>]`
18. Run `close-plan` with `PLAN_APPROVED_COMMENT_URL` in live mode to enforce
    merged-PR/task gates, close the single plan issue, and force cleanup of
    task worktrees:
    `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`

## Command-Oriented Flow

Default command templates in this section use the fixed policy
`--strategy auto --default-pr-grouping group`. Only switch to deterministic
grouping or explicit per-sprint deterministic mode when the user explicitly
requests that behavior. Capture the `ISSUE_NUMBER` output from `start-plan`
once, then reuse it in all `--issue` flags. Keep approval URLs explicit per
gate: `SPRINT_APPROVED_COMMENT_URL` for `accept-sprint`,
`PLAN_APPROVED_COMMENT_URL` for `close-plan`.

1. Live mode (`plan-issue`)
   - Validate: `plan-tooling validate --file <plan.md>`
   - Start plan:
     `plan-issue start-plan --plan <plan.md> --strategy auto --default-pr-grouping group [--repo <owner/repo>]`
   - Start sprint:
     `plan-issue start-sprint --plan <plan.md> --issue <number> --sprint <n> --strategy auto --default-pr-grouping group [--repo <owner/repo>]`
   - Link PR (task scope):
     `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>] [--repo <owner/repo>]`
   - Link PR (sprint lane scope):

     ```bash
     plan-issue link-pr --issue <number> --sprint <n> [--pr-group <group>] --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>] [--repo <owner/repo>]
     ```

   - Status checkpoint (optional): `plan-issue status-plan --issue <number> [--repo <owner/repo>]`
   - Ready sprint:
     `plan-issue ready-sprint --plan <plan.md> --issue <number> --sprint <n> --strategy auto --default-pr-grouping group [--repo <owner/repo>]`
   - Accept sprint:

     ```bash
     plan-issue accept-sprint --plan <plan.md> --issue <number> --sprint <n> --strategy auto --default-pr-grouping group --approved-comment-url <comment-url> [--repo <owner/repo>]
     ```

   - Ready plan: `plan-issue ready-plan --issue <number> [--repo <owner/repo>]`
   - Close plan: `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
2. Explicit override patterns (only when user explicitly requests):

- Deterministic/manual split: use `--strategy deterministic --pr-grouping group`
  and pass full `--pr-group <task-id>=<group>` coverage.
- Per-sprint single lane: use `--strategy deterministic --pr-grouping per-sprint`
  and do not pass `--pr-group`.

## Role boundary (mandatory)

- Main-agent is orchestration/review-only.
- Main-agent does not implement sprint tasks directly.
- Sprint implementation must be delegated to subagent-owned PRs.
- Sprint comments and plan close actions are main-agent orchestration artifacts; implementation remains subagent-owned.
- Review follow-up returns to the existing subagent-owned lanes by default; reassignment is explicit, not implicit.
- Main-agent review decisions should follow
  `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
  before calling `issue-pr-review`.
- After `request-followup` or `close-pr`, main-agent should apply
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md` before
  any new dispatch, acceptance gate, or next-sprint transition.
- For `issue-pr-review` execution, prefer structured outcome flags
  (`request-followup`: `--row-status`, `--next-owner`; `close-pr`:
  `--close-reason`, `--next-action`, optional `--replacement-pr`,
  `--row-status`) to minimize ad-hoc comment formatting decisions.
