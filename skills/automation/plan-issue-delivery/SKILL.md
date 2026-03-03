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
- Repository default branch (`DEFAULT_BRANCH`, for example `main`), resolved once per plan issue.
- Plan integration branch name (`PLAN_BRANCH`, for example `plan/issue-<number>`), created from `DEFAULT_BRANCH` after `start-plan`.
- Persisted `PLAN_BRANCH_REF_PATH` artifact under issue runtime for deterministic restarts.
- Sprint number for sprint orchestration commands.
- Sprint approval comment URL (`SPRINT_APPROVED_COMMENT_URL`) for `accept-sprint`.
- Plan-close approval comment URL (`PLAN_APPROVED_COMMENT_URL`) for `close-plan`.
- Approval URL format for both gates: `https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`.
- Final plan integration PR URL/number (`PLAN_INTEGRATION_PR`) for `PLAN_BRANCH -> DEFAULT_BRANCH`.
- Final integration merge strategy for `PLAN_BRANCH -> DEFAULT_BRANCH`:
  prefer `--squash` when allowed, fallback to `--merge` when squash merge is unavailable by repo/branch policy.
- Plan issue mention comment URL for final integration PR
  (`PLAN_INTEGRATION_MENTION_URL`), posted on the single plan issue.
- Plan conformance review artifact path (`PLAN_CONFORMANCE_REVIEW_PATH`) written by main-agent before final integration merge.
- Final integration required-check verification artifact path (`PLAN_INTEGRATION_CI_PATH`) written by main-agent before final integration merge.
- Final integration CI policy:
  - main-agent must require all required checks to pass before merge
  - `no checks reported` is treated as a merge-blocking failure unless the user explicitly approves override in-thread
- Corrective implementation exception policy:
  - default: main-agent requests follow-up back to the assigned lane
  - exception: main-agent may apply a minimal corrective fix only when explicitly justified and documented in review evidence
- Local sync policy:
  - after each `accept-sprint`: sync local `PLAN_BRANCH` to latest remote state
  - after final integration merge + `close-plan`: sync local `DEFAULT_BRANCH`
    to latest remote state
- Optional repository override (`--repo <owner/repo>`) in live mode.
- Typed subcommands: `start-plan`, `start-sprint`, `link-pr`, `ready-sprint`, `accept-sprint`, `status-plan`, `ready-plan`, `close-plan`.
- Main-agent init source prompt path (`MAIN_AGENT_INIT_SOURCE_PATH`):
  `$AGENT_HOME/prompts/plan-issue-delivery-main-agent-init.md`.
- Issue-scoped `MAIN_AGENT_INIT_SNAPSHOT_PATH` copied from
  `MAIN_AGENT_INIT_SOURCE_PATH` during issue runtime initialization.
- Review evidence template path (`REVIEW_EVIDENCE_TEMPLATE_PATH`):
  `$AGENT_HOME/skills/workflows/issue/issue-pr-review/references/REVIEW_EVIDENCE_TEMPLATE.md`.
- Decision-scoped review evidence artifact path (`REVIEW_EVIDENCE_PATH`) per
  review decision.
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
- Issue-scoped main-agent init prompt snapshot
  (`MAIN_AGENT_INIT_SNAPSHOT_PATH`) is generated for deterministic
  orchestration restarts.
- Decision-scoped review evidence artifacts
  (`REVIEW_EVIDENCE_PATH`) are generated under sprint runtime for each
  `request-followup|merge|close-pr` decision.
- Main-agent posts decision-scoped review-evidence PR comments and keeps those
  comment URLs traceable in issue-side sync actions.
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
- `ready-sprint` is a pre-merge review gate: linked sprint PRs should still be open and reviewable.
- Sprint PR review verifies lane mapping, required checks, and target `baseRefName == PLAN_BRANCH` before merge decisions.
- `accept-sprint` additionally enforces sprint PRs are merged into `PLAN_BRANCH` and syncs sprint task `Status` to `done` in live mode.
- `start-sprint` for sprint `N>1` is blocked until sprint `N-1` is merged and all its task rows are `done`.
- `start-plan` initializes and persists `PLAN_BRANCH` (created from `DEFAULT_BRANCH`) at `PLAN_BRANCH_REF_PATH`.
- Final close path includes one main-agent integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`) and persists traceability at
  `PLAN_INTEGRATION_PR_PATH`.
- Main-agent must emit `PLAN_CONFORMANCE_REVIEW_PATH` proving final merged scope matches plan task intent before merging integration PR.
- Main-agent must emit `PLAN_INTEGRATION_CI_PATH` proving required checks are green for the integration PR before merging integration PR.
- Main-agent must post one plan-issue comment that mentions the final
  integration PR (`#<number>`) and persist its URL at
  `PLAN_INTEGRATION_MENTION_PATH`.
- Main-agent must run local sync commands after merge gates so local branch
  state reflects remote (`PLAN_BRANCH` after sprint acceptance,
  `DEFAULT_BRANCH` after close-plan).
- PR references in sprint comments and review tables use canonical `#<number>` format.
- Sprint start comments may still show `TBD` PR placeholders until subagents open PRs and rows are linked.
- `start-sprint` comments append the full markdown section for the active sprint from the plan file (for example Sprint 1/2/3 sections).
- Dispatch hints can open one shared PR for multiple ordered/small tasks when grouped.
- Main-agent must launch subagents with the full dispatch bundle:
  - rendered `TASK_PROMPT_PATH` artifact
  - `SUBAGENT_INIT_SNAPSHOT_PATH` artifact from `$AGENT_HOME/out/plan-issue-delivery/...`
  - `PLAN_SNAPSHOT_PATH` artifact from `$AGENT_HOME/out/plan-issue-delivery/...`
  - `DISPATCH_RECORD_PATH` artifact from `$AGENT_HOME/out/plan-issue-delivery/...`
  - assigned `PLAN_BRANCH` base-branch context for sprint PR creation
  - plan task section context (snippet/link/path)
- Ad-hoc dispatch prompts that bypass the required bundle are invalid.
- Final issue close only after plan-level acceptance, merged-PR close gate, and integration mention gate.
- `close-plan` enforces integration mention + cleanup of all issue-assigned task worktrees before completion.
- Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed (live mode), integration mention gate
  passes, plan-conformance gate passes, integration required-check gate passes, worktree cleanup passes, and required local sync commands
  succeed.
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
- Issue/sprint runtime artifacts missing (for example
  `MAIN_AGENT_INIT_SNAPSHOT_PATH`, `REVIEW_EVIDENCE_PATH`, `TASK_PROMPT_PATH`,
  `PLAN_SNAPSHOT_PATH`, `SUBAGENT_INIT_SNAPSHOT_PATH`,
  `PLAN_BRANCH_REF_PATH`, `PLAN_INTEGRATION_PR_PATH`,
  `PLAN_INTEGRATION_MENTION_PATH`, or
  `DISPATCH_RECORD_PATH` not emitted under runtime root).
- `PLAN_BRANCH` is missing/unresolvable for sprint dispatch or differs from the persisted `PLAN_BRANCH_REF_PATH` value.
- A sprint PR is linked with `baseRefName != PLAN_BRANCH`.
- `ready-sprint` checkpoint reached after sprint PRs were already merged without post-merge audit evidence + explicit follow-up decision.
- Main-agent review decision attempted without validated review evidence (for
  example missing `--enforce-review-evidence`, missing/invalid
  `REVIEW_EVIDENCE_PATH`, or generic non-evidenced decision text).
- Subagent dispatch launched without required bundle (`TASK_PROMPT_PATH`, `SUBAGENT_INIT_SNAPSHOT_PATH`, `PLAN_SNAPSHOT_PATH`,
  `DISPATCH_RECORD_PATH`, plan task section snippet/link/path).
- Assigned task `Worktree` is outside `$AGENT_HOME/out/plan-issue-delivery/...`.
- Final plan close gate fails (task status/PR merge not satisfied in live mode).
- Final plan close gate fails because the integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`) is missing or unmerged.
- Final plan close gate fails because `PLAN_CONFORMANCE_REVIEW_PATH` is missing, incomplete, or reports unresolved plan mismatches.
- Final plan close gate fails because `PLAN_INTEGRATION_CI_PATH` is missing/invalid, required checks are not green, or checks return
  `no checks reported` without explicit user-approved override.
- Final plan close gate fails because integration PR mention comment on the plan
  issue is missing/invalid/untraceable.
- Main-agent applies corrective implementation without explicit exception rationale and verification evidence.
- Local sync command fails after `accept-sprint` or after final `close-plan`.
- Worktree cleanup gate fails (any issue-assigned task worktree still exists after cleanup).
- Attempted transition to a next sprint that does not exist.

## Runtime Workspace Policy (Mandatory)

- Use one runtime root for this skill only: `RUNTIME_ROOT="$AGENT_HOME/out/plan-issue-delivery"`.
- Namespace by repository and issue:
  - `ISSUE_ROOT="$RUNTIME_ROOT/<repo-slug>/issue-<ISSUE_NUMBER>"`
  - `SPRINT_ROOT="$ISSUE_ROOT/sprint-<N>"`
- Required runtime artifacts:
  - `MAIN_AGENT_INIT_SOURCE_PATH="$AGENT_HOME/prompts/plan-issue-delivery-main-agent-init.md"`
  - `MAIN_AGENT_INIT_SNAPSHOT_PATH="$ISSUE_ROOT/prompts/plan-issue-delivery-main-agent-init.snapshot.md"`
  - `REVIEW_EVIDENCE_TEMPLATE_PATH="$AGENT_HOME/skills/workflows/issue/issue-pr-review/references/REVIEW_EVIDENCE_TEMPLATE.md"`
  - `REVIEW_EVIDENCE_PATH="$SPRINT_ROOT/reviews/<TASK_ID>-<decision>.md"`
  - `PLAN_SNAPSHOT_PATH="$ISSUE_ROOT/plan/plan.snapshot.md"`
  - `PLAN_BRANCH_REF_PATH="$ISSUE_ROOT/plan/plan-branch.ref"` (contains canonical `PLAN_BRANCH` name)
  - `PLAN_INTEGRATION_PR_PATH="$ISSUE_ROOT/plan/plan-integration-pr.md"` (tracks final `PLAN_BRANCH -> DEFAULT_BRANCH` PR)
  - `PLAN_CONFORMANCE_REVIEW_PATH="$ISSUE_ROOT/plan/plan-conformance-review.md"` (final plan-task conformance verdict + evidence)
  - `PLAN_INTEGRATION_CI_PATH="$ISSUE_ROOT/plan/plan-integration-ci.md"` (required-check verification for final integration PR)
  - `PLAN_INTEGRATION_MENTION_PATH="$ISSUE_ROOT/plan/plan-integration-mention.url"` (tracks issue-comment URL that mentions final
    integration PR)
  - `TASK_PROMPT_PATH="$SPRINT_ROOT/prompts/<TASK_ID>.md"`
  - `SUBAGENT_INIT_SNAPSHOT_PATH="$SPRINT_ROOT/prompts/plan-issue-delivery-subagent-init.snapshot.md"`
  - prompt manifest under `"$SPRINT_ROOT/manifests/"`
  - `DISPATCH_RECORD_PATH="$SPRINT_ROOT/manifests/dispatch-<TASK_ID>.json"`
- Worktree path rules (must be absolute paths under `"$ISSUE_ROOT/worktrees"`):
  - `pr-isolated`: `.../worktrees/pr-isolated/<TASK_ID>`
  - `pr-shared`: `.../worktrees/pr-shared/<PR_GROUP>`
  - `per-sprint`: `.../worktrees/per-sprint/sprint-<N>`
- `start-plan` (or immediate post-`start-plan` issue runtime initialization)
  must copy `MAIN_AGENT_INIT_SOURCE_PATH` into
  `MAIN_AGENT_INIT_SNAPSHOT_PATH` before any `start-sprint`.
- `start-plan` (or immediate post-`start-plan` issue runtime initialization)
  must resolve `DEFAULT_BRANCH`, create/push `PLAN_BRANCH` from
  `DEFAULT_BRANCH`, and persist `PLAN_BRANCH_REF_PATH` before any
  `start-sprint`.
- `start-sprint` must copy the source plan into `PLAN_SNAPSHOT_PATH` before subagent dispatch.
- `start-sprint` must copy `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md` into `SUBAGENT_INIT_SNAPSHOT_PATH` before subagent
  dispatch.
- `start-sprint` must emit one `DISPATCH_RECORD_PATH` per assigned task before subagent dispatch.
- `start-sprint` dispatch artifacts must include `PLAN_BRANCH` as required base branch for sprint PR creation.
- Subagent plan reference priority:
  - assigned plan task snippet/link/path (primary)
  - `PLAN_SNAPSHOT_PATH` (fallback)
  - source plan path (last fallback)
- After every successful `accept-sprint`, main-agent must sync local
  `PLAN_BRANCH`:
  - `git fetch origin --prune`
  - `git switch "$PLAN_BRANCH"` (or create tracking branch from
    `origin/$PLAN_BRANCH` if missing)
  - `git pull --ff-only`
- `close-plan` must enforce final integration PR merged (`PLAN_BRANCH -> DEFAULT_BRANCH`), integration PR mention comment on plan issue, and
  worktree cleanup under `"$ISSUE_ROOT/worktrees"`; leftovers fail the close gate.
- `close-plan` must also enforce final conformance + integration CI artifacts:
  - `PLAN_CONFORMANCE_REVIEW_PATH` present with pass verdict
  - `PLAN_INTEGRATION_CI_PATH` present with required checks green (or explicit user-approved override)
- After successful `close-plan`, main-agent must sync local `DEFAULT_BRANCH`:
  - `git fetch origin --prune`
  - `git switch "$DEFAULT_BRANCH"` (or create tracking branch from
    `origin/$DEFAULT_BRANCH` if missing)
  - `git pull --ff-only`

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

## Entrypoint boundary

- This skill intentionally keeps no repo-local wrapper script for `plan-issue`.
- Keep `plan-issue` as the shared primitive on PATH; do not add duplicate `plan-issue-*` wrappers under `skills/automation/`.
- Shared reusable logic belongs in shared references or automation libs, not new wrapper entrypoints.

## References

- Local rehearsal playbook (`plan-issue-local` and `plan-issue --dry-run`): `references/LOCAL_REHEARSAL.md`
- Runtime layout and path rules: `references/RUNTIME_LAYOUT.md`
- Review evidence template for main-agent decisions:
  `skills/workflows/issue/issue-pr-review/references/REVIEW_EVIDENCE_TEMPLATE.md`
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
3. Initialize issue runtime workspace under
   `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-<number>/`, and copy
   `MAIN_AGENT_INIT_SOURCE_PATH` into `MAIN_AGENT_INIT_SNAPSHOT_PATH`; then
   resolve `DEFAULT_BRANCH`, create `PLAN_BRANCH`, and persist
   `PLAN_BRANCH_REF_PATH`.
4. Run `start-sprint`, ensure `MAIN_AGENT_INIT_SNAPSHOT_PATH` +
   `REVIEW_EVIDENCE_PATH` + `TASK_PROMPT_PATH` + `PLAN_SNAPSHOT_PATH` +
   `SUBAGENT_INIT_SNAPSHOT_PATH` + `DISPATCH_RECORD_PATH` artifacts
   exist, dispatch subagents with `PLAN_BRANCH` base-branch context, keep task
   lanes stable, and keep row state current via `link-pr`.
5. For each sprint: implement/clarify/follow-up on subagent-owned lanes ->
   `ready-sprint` (pre-merge review gate, PRs should still be open) ->
   main-agent review decisions + merge into `PLAN_BRANCH` -> `accept-sprint` ->
   local `PLAN_BRANCH` sync (`git fetch` + `git switch` + `git pull --ff-only`).
6. Repeat step 5 for each next sprint (`start-sprint` is blocked until prior sprint is merged+done).
7. After final sprint acceptance, run `ready-plan`, then execute final integration gates in order:
   - main-agent performs full plan conformance review against plan tasks, runtime
     rows, merged sprint PRs, and current `PLAN_BRANCH` diff; writes
     `PLAN_CONFORMANCE_REVIEW_PATH`.
   - if conformance review finds mismatch, default action is lane follow-up
     dispatch on the original lane; main-agent corrective implementation is a
     documented exception only.
   - open the final integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`) and persist
     `PLAN_INTEGRATION_PR_PATH`.
   - wait for required checks to pass (`gh pr checks <integration-pr> --required --watch`)
     and write `PLAN_INTEGRATION_CI_PATH`; `no checks reported` is merge-blocking
     unless user explicitly approves override.
   - merge integration PR only after both gates pass, using squash-first
     fallback-to-merge strategy.
   - post a plan-issue mention comment for the merged integration PR and persist
     `PLAN_INTEGRATION_MENTION_PATH`.
   - run `close-plan` with plan-level approval URL, then local `DEFAULT_BRANCH`
     sync (`git fetch` + `git switch` + `git pull --ff-only`).
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
  - `PLAN_CONFORMANCE_REVIEW_PATH` present with pass verdict and traceable evidence
  - `PLAN_INTEGRATION_CI_PATH` present with required checks green (or explicit user override recorded)
  - final integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`) merged
  - plan issue mention comment exists for final integration PR
  - local `PLAN_BRANCH` sync succeeded after each sprint acceptance
  - local `DEFAULT_BRANCH` sync succeeded after final close
  - worktree cleanup gate passing
- If any close gate fails, treat the run as unfinished and report:
  - failing command
  - gate errors (task status, PR merge, plan conformance, integration CI, integration PR, integration mention, local sync, approval URL,
    worktree cleanup)
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
   - Main-agent init source path:
     `$AGENT_HOME/prompts/plan-issue-delivery-main-agent-init.md`
   - Main-agent init snapshot path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/prompts/plan-issue-delivery-main-agent-init.snapshot.md`
   - Copy main-agent init source prompt into the snapshot path before any
     `start-sprint` execution.
   - Snapshot path: `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan.snapshot.md`
   - Subagent init snapshot path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/sprint-<N>/prompts/plan-issue-delivery-subagent-init.snapshot.md`
   - Dispatch record path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/sprint-<N>/manifests/dispatch-<TASK_ID>.json`
   - Plan branch ref path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan-branch.ref`
   - Plan integration PR record path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan-integration-pr.md`
   - Plan conformance review path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan-conformance-review.md`
   - Plan integration CI verification path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan-integration-ci.md`
   - Plan integration mention record path:
     `$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-$ISSUE_NUMBER/plan/plan-integration-mention.url`
   - Resolve and persist branch contract:
     - `DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')"`
     - `PLAN_BRANCH="plan/issue-$ISSUE_NUMBER"`
     - `git fetch origin --prune`
     - `git checkout -B "$PLAN_BRANCH" "origin/$DEFAULT_BRANCH"`
     - `git push -u origin "$PLAN_BRANCH"`
     - `printf '%s\n' "$PLAN_BRANCH" > "$PLAN_BRANCH_REF_PATH"`
8. Run `start-sprint` for Sprint 1 on the same plan issue token/number:
   - main-agent verifies `MAIN_AGENT_INIT_SNAPSHOT_PATH` exists before sprint
     dispatch
   - main-agent follows the locked grouping policy (default metadata-first auto
     with `--default-pr-grouping group`; switch only on explicit user request)
     and emits dispatch hints
   - main-agent starts subagents using dispatch bundles that include:
     - rendered `TASK_PROMPT_PATH` prompt artifact from dispatch hints
     - `SUBAGENT_INIT_SNAPSHOT_PATH` copied from `$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md`
     - `PLAN_SNAPSHOT_PATH` from issue runtime workspace
     - `DISPATCH_RECORD_PATH` from sprint manifest artifacts
     - `PLAN_BRANCH` (required base branch for sprint PRs)
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
12. When sprint work is ready, run `ready-sprint` as the pre-merge review checkpoint:
    - expected state: linked sprint PRs are open, CI-ready, and target `PLAN_BRANCH`
    - if any sprint PR is already merged, switch to post-merge audit mode before acceptance:
      - generate decision-scoped review evidence from merged diff/CI history
      - decide follow-up on the same lane (reopen work via replacement PR) vs accept as-is
13. Main-agent reviews each sprint PR against the shared review rubric
    (`skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`),
    generates `REVIEW_EVIDENCE_PATH` from
    `REVIEW_EVIDENCE_TEMPLATE_PATH`, and executes `issue-pr-review`
    decisions with `--enforce-review-evidence` so each
    `request-followup|merge|close-pr` action is grounded in concrete evidence.
    Then records approval and requests follow-up back to the same
    subagent-owned lanes or merges/closes the PRs.
    - merge authority stays with main-agent
    - sprint PR merges must target `PLAN_BRANCH`, not `DEFAULT_BRANCH`
14. After each review decision, apply
    `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md` to sync
    runtime-truth rows before any further dispatch or acceptance gate.
15. Run `accept-sprint` with `SPRINT_APPROVED_COMMENT_URL` in live mode to enforce
    merged-PR gate (merged into `PLAN_BRANCH`) and sync sprint task status rows
    to `done` (issue stays open).
16. Sync local `PLAN_BRANCH` after each successful `accept-sprint`:
    - `git fetch origin --prune`
    - `git switch "$PLAN_BRANCH"` (or create tracking branch from
      `origin/$PLAN_BRANCH` if missing)
    - `git pull --ff-only`
17. If another sprint exists, run `start-sprint` for the next sprint on the same issue; this is blocked until prior sprint is merged+done.
18. After the final sprint is implemented and accepted, run `ready-plan` for
    final review:
    `plan-issue ready-plan --issue <number> [--repo <owner/repo>]`
19. Main-agent executes full plan-conformance review before integration merge,
    then writes `PLAN_CONFORMANCE_REVIEW_PATH`:
    - verify each plan task is fully satisfied by merged sprint PRs + current
      `PLAN_BRANCH` diff
    - if mismatch exists, default action is lane follow-up on the original lane
    - main-agent corrective implementation is exceptional and must include
      explicit rationale + verification evidence
20. Main-agent opens exactly one integration PR from `PLAN_BRANCH` into
    `DEFAULT_BRANCH`, then records the PR reference in
    `PLAN_INTEGRATION_PR_PATH`.
21. Main-agent verifies integration PR required checks are green before merge,
    writes `PLAN_INTEGRATION_CI_PATH`, and blocks merge when checks are not
    green:
    - `gh pr checks <integration-pr> --required --watch`
    - `no checks reported` is merge-blocking unless user explicitly approves
      override in-thread
22. Merge integration PR only after steps 19 and 21 pass.
23. Main-agent posts one plan-issue comment that mentions the merged
    integration PR (`#<number>`) and records the comment URL in
    `PLAN_INTEGRATION_MENTION_PATH`.
24. Run `close-plan` with `PLAN_APPROVED_COMMENT_URL` in live mode to enforce
    merged-PR/task + integration-PR + integration-mention gates, close the
    single plan issue, and force cleanup of task worktrees:
    `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
25. Sync local `DEFAULT_BRANCH` after successful final close:
    - `git fetch origin --prune`
    - `git switch "$DEFAULT_BRANCH"` (or create tracking branch from
      `origin/$DEFAULT_BRANCH` if missing)
    - `git pull --ff-only`

## Command-Oriented Flow

Default command templates in this section use the fixed policy
`--strategy auto --default-pr-grouping group`. Only switch to deterministic
grouping or explicit per-sprint deterministic mode when the user explicitly
requests that behavior. Capture the `ISSUE_NUMBER` output from `start-plan`
once, then reuse it in all `--issue` flags. Keep approval URLs explicit per
gate: `SPRINT_APPROVED_COMMENT_URL` for `accept-sprint`,
`PLAN_APPROVED_COMMENT_URL` for `close-plan`. Sprint PRs target `PLAN_BRANCH`;
only the final integration PR targets `DEFAULT_BRANCH`. Before `close-plan`,
main-agent must complete conformance + required-check gates for the integration
PR, then post an issue comment that mentions the integration PR and keep that
comment URL.

1. Live mode (`plan-issue`)
   - Validate: `plan-tooling validate --file <plan.md>`
   - Start plan:
     `plan-issue start-plan --plan <plan.md> --strategy auto --default-pr-grouping group [--repo <owner/repo>]`
   - Initialize branch contract (after capturing `ISSUE_NUMBER`):

     ```bash
     DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')"
     PLAN_BRANCH="plan/issue-${ISSUE_NUMBER}"
     PLAN_BRANCH_REF_PATH="$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-${ISSUE_NUMBER}/plan/plan-branch.ref"

     git fetch origin --prune
     git checkout -B "$PLAN_BRANCH" "origin/$DEFAULT_BRANCH"
     git push -u origin "$PLAN_BRANCH"
     printf '%s\n' "$PLAN_BRANCH" > "$PLAN_BRANCH_REF_PATH"
     ```

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
   - Pre-merge review check (recommended before merge decisions):

     ```bash
     gh pr view <pr-number> --json state,baseRefName,headRefName,isDraft,statusCheckRollup
     ```

     - Expected: `state=OPEN`, `baseRefName=$PLAN_BRANCH`, required checks green.
     - Treat `no checks reported` as blocking failure unless user explicitly approves override.
   - Accept sprint:

     ```bash
     plan-issue accept-sprint --plan <plan.md> --issue <number> --sprint <n> --strategy auto --default-pr-grouping group --approved-comment-url <comment-url> [--repo <owner/repo>]
     ```

   - Local sync after sprint acceptance:

     ```bash
     git fetch origin --prune
     git switch "$PLAN_BRANCH" || git switch -c "$PLAN_BRANCH" --track "origin/$PLAN_BRANCH"
     git pull --ff-only
     ```

   - Ready plan: `plan-issue ready-plan --issue <number> [--repo <owner/repo>]`
   - Write final plan conformance review (`PLAN_CONFORMANCE_REVIEW_PATH`):

     ```bash
     PLAN_CONFORMANCE_REVIEW_PATH="$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-${ISSUE_NUMBER}/plan/plan-conformance-review.md"
     # Record per-task conformance verdicts and blocking mismatches before integration merge.
     ```

   - Final integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`):

     ```bash
     gh pr create --base "$DEFAULT_BRANCH" --head "$PLAN_BRANCH" --title "plan(issue-${ISSUE_NUMBER}): merge ${PLAN_BRANCH} into ${DEFAULT_BRANCH}" --body "<summary>"
     ```

   - Verify integration required checks before merge and write `PLAN_INTEGRATION_CI_PATH`:

     ```bash
     INTEGRATION_PR_NUMBER="<number>"
     PLAN_INTEGRATION_CI_PATH="$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-${ISSUE_NUMBER}/plan/plan-integration-ci.md"

     gh pr checks "$INTEGRATION_PR_NUMBER" --required --watch
     # If output contains "no checks reported", treat as blocking failure unless user explicitly approves override.
     ```

   - Merge integration PR only after conformance + required-check gates pass
     (prefer squash, fallback to merge when squash is unavailable):

     ```bash
     if gh repo view --json squashMergeAllowed --jq '.squashMergeAllowed' | grep -q true; then
       gh pr merge "$INTEGRATION_PR_NUMBER" --squash || gh pr merge "$INTEGRATION_PR_NUMBER" --merge
     else
       gh pr merge "$INTEGRATION_PR_NUMBER" --merge
     fi
     ```

   - Mention integration PR on the plan issue and persist comment URL:

     ```bash
     INTEGRATION_PR_NUMBER="<number>"
     PLAN_INTEGRATION_MENTION_PATH="$AGENT_HOME/out/plan-issue-delivery/<repo-slug>/issue-${ISSUE_NUMBER}/plan/plan-integration-mention.url"
     PLAN_INTEGRATION_MENTION_URL="<https://github.com/<owner>/<repo>/issues/${ISSUE_NUMBER}#issuecomment-...>"

     gh issue comment "$ISSUE_NUMBER" \
       --body "Final integration PR merged: #${INTEGRATION_PR_NUMBER} (\`${PLAN_BRANCH}\` -> \`${DEFAULT_BRANCH}\`)."
     printf '%s\n' "$PLAN_INTEGRATION_MENTION_URL" > "$PLAN_INTEGRATION_MENTION_PATH"
     ```

   - Close plan: `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
   - Local sync after final close:

     ```bash
     git fetch origin --prune
     git switch "$DEFAULT_BRANCH" || git switch -c "$DEFAULT_BRANCH" --track "origin/$DEFAULT_BRANCH"
     git pull --ff-only
     ```

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
- Allowed baseline exception: main-agent may open/manage exactly one
  non-implementation integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`) after all
  sprints are accepted.
- Main-agent owns final plan-conformance review and integration required-check
  gates before merging to `DEFAULT_BRANCH`.
- Default correction path for plan mismatches is follow-up on the original lane,
  not main-agent coding.
- Exceptional correction path (main-agent coding) is allowed only when:
  - lane follow-up is unavailable or too risky for delivery timing
  - fix scope is minimal and directly tied to plan conformance
  - rationale, test evidence, and scope justification are recorded in review evidence
- Main-agent must post the integration PR mention comment on the plan issue
  before `close-plan`.
- Main-agent owns required local sync commands after sprint acceptance and final
  close (`git fetch` + `git switch` + `git pull --ff-only`).
- Review follow-up returns to the existing subagent-owned lanes by default; reassignment is explicit, not implicit.
- Main-agent review decisions should follow
  `skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md`
  before calling `issue-pr-review`.
- Main-agent review decisions must include decision-scoped evidence artifacts
  generated from
  `skills/workflows/issue/issue-pr-review/references/REVIEW_EVIDENCE_TEMPLATE.md`,
  and must execute `issue-pr-review` with `--enforce-review-evidence`.
- After `request-followup` or `close-pr`, main-agent should apply
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md` before
  any new dispatch, acceptance gate, or next-sprint transition.
- For `issue-pr-review` execution, prefer structured outcome flags
  (`request-followup`: `--row-status`, `--next-owner`; `close-pr`:
  `--close-reason`, `--next-action`, optional `--replacement-pr`,
  `--row-status`) to minimize ad-hoc comment formatting decisions.
