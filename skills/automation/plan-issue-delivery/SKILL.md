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
- `plan-issue-local` available on `PATH` for local rehearsal mode.
- `gh` available on `PATH`, and `gh auth status` succeeds only when using live mode (`plan-issue`).

Inputs:

- Plan file path (`docs/plans/...-plan.md`).
- Plan issue number (`--issue <number>`) after `start-plan` creates the single issue.
- Sprint number for sprint orchestration commands.
- Approval comment URL (`https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`) for:
  - sprint acceptance record comments
  - final plan issue close gate
- Optional repository override (`--repo <owner/repo>`) in live mode.
- Typed subcommands: `start-plan`, `start-sprint`, `link-pr`, `ready-sprint`, `accept-sprint`, `status-plan`, `ready-plan`, `close-plan`.
- Typed local rehearsal behavior:
  - `plan-issue-local` runs without GitHub API usage for local sprint orchestration rehearsal.
  - `plan-issue --dry-run` provides live-binary rehearsal behavior without mutating GitHub.
  - local rehearsal for sprint commands still requires `--issue <number>` input; use a local placeholder number (for example `999`) when no live issue exists.
  - sprint commands default to no comment posting during dry-run/local rehearsal.
  - `link-pr` supports `--issue` (live) or `--body-file` (offline); for local rehearsal, use `--body-file` (and typically `--dry-run`).
  - `ready-plan` requires one of `--issue` or `--body-file`; dry-run/local rehearsal should use `--body-file <path>`.
  - `close-plan` requires `--approved-comment-url`; dry-run/local rehearsal also requires `--body-file <path>`.
- Required PR grouping controls:
  - Always pass `--pr-grouping per-sprint|group` (`per-spring` alias accepted) and `--strategy deterministic|auto` on split-dependent commands.
  - Skill default: use `--pr-grouping group --strategy auto`.
  - `--pr-group <task-or-plan-id>=<group>` is:
    - optional for `group + auto` (supports partial pinning; remaining tasks are auto-assigned)
    - required for `group + deterministic` (must cover every task in scope)
    - unused for `per-sprint`

Outputs:

- Plan-scoped task-spec TSV generated from all plan tasks (all sprints) for one issue.
- Sprint-scoped task-spec TSV generated per sprint for subagent dispatch hints, including `pr_group`.
- Sprint-scoped rendered subagent prompt files + a prompt manifest (`task_id -> prompt_path -> execution_mode`) generated at `start-sprint`.
- `plan-tooling split-prs` v2 emits grouping primitives only (`task_id`, `summary`, `pr_group`); `plan-issue` materializes runtime metadata (`Owner/Branch/Worktree/Notes`).
- Live mode (`plan-issue`) creates/updates exactly one GitHub Issue for the whole plan (`1 plan = 1 issue`).
- Local rehearsal (`plan-issue-local` or `plan-issue --dry-run`) emits equivalent orchestration artifacts without GitHub mutations.
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
- Main-agent must launch subagents from rendered `TASK_PROMPT_PATH` artifacts (no ad-hoc dispatch prompt bypass).
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
- Required commands missing (`plan-tooling`, `plan-issue`, `plan-issue-local`; `gh` only required for live GitHub mode).
- Typed argument validation fails (unknown subcommand, invalid flag, malformed `--pr-group`, invalid `--pr-grouping`).
- `link-pr` PR selector invalid (`--pr` must resolve to a concrete PR number).
- `link-pr` target ambiguous (for example sprint selector spans multiple runtime lanes without `--pr-group`).
- Live mode approval URL invalid.
- Dry-run/local `ready-plan` invoked without `--issue` or `--body-file`.
- Dry-run/local `close-plan` invoked without required `--approved-comment-url` and `--body-file`.
- Final plan close gate fails (task status/PR merge not satisfied in live mode).
- Worktree cleanup gate fails (any issue-assigned task worktree still exists after cleanup).
- Attempted transition to a next sprint that does not exist.

## Binaries (only entrypoints)

- `plan-issue` (live GitHub orchestration)
- `plan-issue-local` (local rehearsal)

## Workflow

1. Live mode (GitHub mutations): use `plan-issue`.
2. Local rehearsal mode (no GitHub mutations): use `plan-issue-local` (or `plan-issue --dry-run` when matching live CLI ergonomics is required).
3. Plan issue bootstrap (one-time):
   - `start-plan`: parse the full plan, generate one task decomposition covering all sprints, and open one plan issue in live mode.
4. Sprint execution loop (repeat on the same plan issue):
   - `start-sprint`: validate runtime-truth sprint rows against plan-derived lane metadata, generate sprint task TSV, render per-task subagent prompts, post sprint-start comment in live mode, and emit subagent dispatch hints (supports grouped PR dispatch). For sprint `N>1`, this command requires sprint `N-1` merged+done gate to pass first.
   - As subagent PRs open, use `link-pr` to record PR references and runtime task status (`planned|in-progress|blocked`).
   - `ready-sprint`: post sprint-ready comment in live mode to request main-agent review before merge.
   - After review approval, merge sprint PRs.
   - `accept-sprint`: validate sprint PRs are merged, sync sprint task statuses to `done`, and record sprint acceptance comment on the same issue in live mode (issue stays open).
   - If another sprint exists, run `start-sprint` for the next sprint on the same issue.
5. Plan close (one-time):
   - `ready-plan`: request final plan review without label mutation (`--no-label-update`). For dry-run/local rehearsal, provide `--body-file`.
   - `close-plan`: run the plan-level close gate, close the single plan issue in live mode, and enforce task worktree cleanup. For dry-run/local rehearsal, `--body-file` is required.

## PR Grouping Steps (Mandatory)

1. Choose grouping profile before any split command:
   - Default/recommended: `group + auto`
   - Deterministic/manual split: `group + deterministic`
   - One shared PR per sprint: `per-sprint`
2. Keep the same grouping flags across the same sprint flow (`start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`) to avoid row/spec drift.
3. If using `group + auto`:
   - You may omit `--pr-group` completely.
   - You may pass partial `--pr-group` mappings to pin selected tasks; unmapped tasks remain auto-assigned.
4. If using `group + deterministic`:
   - You must pass `--pr-group` and cover every task in scope.
   - Missing mappings are a hard validation error; stop and fix before proceeding.
5. If using `per-sprint`:
   - Do not pass `--pr-group`; all tasks in the sprint share one PR group anchor.

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
2. Choose execution mode:
   - Live mode: `plan-issue ...`
   - Local rehearsal: `plan-issue-local ...` (or `plan-issue --dry-run ...`)
3. Choose PR grouping profile (default `group + auto`):
   - `group + auto`: no mapping requirement; optional partial pinning with `--pr-group`.
   - `group + deterministic`: full `--pr-group` coverage required.
   - `per-sprint`: one shared PR group per sprint.
4. Run `start-plan` to initialize plan orchestration (`1 plan = 1 issue` in live mode).
5. Run `start-sprint` for Sprint 1 on the same plan issue token/number:
   - main-agent chooses PR grouping + strategy (`per-sprint`, `group + auto`, or `group + deterministic`) and emits dispatch hints
   - main-agent starts subagents using rendered `TASK_PROMPT_PATH` prompt artifacts from dispatch hints
   - subagents create worktrees/PRs and implement tasks
6. While sprint work is active, link each subagent PR into runtime-truth rows with `link-pr`:
   - task scope: `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - sprint scope: `plan-issue link-pr --issue <number> --sprint <n> --pr-group <group> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>]`
   - `--task` auto-syncs shared lanes; `--sprint` without `--pr-group` is valid only when the sprint target resolves to one runtime lane.
7. Optionally run `status-plan` checkpoints to keep plan-level progress snapshots traceable.
8. When sprint work is ready, run `ready-sprint` to record a sprint review/acceptance request (live comment in live mode).
9. Main-agent reviews sprint PR content, records approval, and merges the sprint PRs.
10. Run `accept-sprint` with the approval comment URL in live mode to enforce merged-PR gate and sync sprint task status rows to `done` (issue stays open).
11. If another sprint exists, run `start-sprint` for the next sprint on the same issue; this is blocked until prior sprint is merged+done.
12. After the final sprint is implemented and accepted, run `ready-plan` for final review:
   - live mode: `plan-issue ready-plan --issue <number> --no-label-update [--repo <owner/repo>]`
   - dry-run/local rehearsal: `plan-issue ready-plan --dry-run --body-file <ready-plan-comment.md> --no-label-update`
13. Run `close-plan` with the final approval comment URL in live mode to enforce merged-PR/task gates, close the single plan issue, and force cleanup of task worktrees:
   - live mode: `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
   - dry-run/local rehearsal: `plan-issue close-plan --dry-run --approved-comment-url <comment-url> --body-file <close-plan-comment.md>`

## Command-Oriented Flow

1. Live mode (`plan-issue`)
   - Validate: `plan-tooling validate --file <plan.md>`
   - Start plan: `plan-issue start-plan --plan <plan.md> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> [--pr-group <task-id>=<group> ...] [--repo <owner/repo>]`
   - Start sprint: `plan-issue start-sprint --plan <plan.md> --issue <number> --sprint <n> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> [--pr-group <task-id>=<group> ...] [--repo <owner/repo>]`
   - Link PR (task scope): `plan-issue link-pr --issue <number> --task <task-id> --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>] [--repo <owner/repo>]`
   - Link PR (sprint lane scope): `plan-issue link-pr --issue <number> --sprint <n> [--pr-group <group>] --pr <#123|123|pull-url> [--status <planned|in-progress|blocked>] [--repo <owner/repo>]`
   - Status checkpoint (optional): `plan-issue status-plan --issue <number> [--repo <owner/repo>]`
   - Ready sprint: `plan-issue ready-sprint --plan <plan.md> --issue <number> --sprint <n> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> [--pr-group <task-id>=<group> ...] [--repo <owner/repo>]`
   - Accept sprint: `plan-issue accept-sprint --plan <plan.md> --issue <number> --sprint <n> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> --approved-comment-url <comment-url> [--pr-group <task-id>=<group> ...] [--repo <owner/repo>]`
   - Ready plan: `plan-issue ready-plan --issue <number> --no-label-update [--repo <owner/repo>]`
   - Close plan: `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
2. Local rehearsal (`plan-issue-local`)
  - Validate: `plan-tooling validate --file <plan.md>`
  - Start plan: `plan-issue-local start-plan --plan <plan.md> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> [--pr-group <task-id>=<group> ...]`
  - Start sprint: `plan-issue-local start-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> [--pr-group <task-id>=<group> ...]`
  - Link PR (task scope): `plan-issue-local link-pr --body-file <issue-body.md> --task <task-id> --pr <#123|123|pull-url> --status <planned|in-progress|blocked> --dry-run`
  - Link PR (sprint lane scope): `plan-issue-local link-pr --body-file <issue-body.md> --sprint <n> [--pr-group <group>] --pr <#123|123|pull-url> --status <planned|in-progress|blocked> --dry-run`
  - Status checkpoint (optional): `plan-issue-local status-plan --body-file <issue-body.md> --dry-run`
  - Ready sprint: `plan-issue-local ready-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> [--pr-group <task-id>=<group> ...]`
  - Accept sprint: `plan-issue-local accept-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --pr-grouping <per-sprint|group> --strategy <auto|deterministic> --approved-comment-url <comment-url> [--pr-group <task-id>=<group> ...]`
3. Plan-level local/offline rehearsal (`plan-issue --dry-run`)
  - Ready plan: `plan-issue ready-plan --dry-run --body-file <ready-plan-comment.md> --no-label-update`
  - Close plan: `plan-issue close-plan --dry-run --approved-comment-url <comment-url> --body-file <close-plan-comment.md>`

## Role boundary (mandatory)

- Main-agent is orchestration/review-only.
- Main-agent does not implement sprint tasks directly.
- Sprint implementation must be delegated to subagent-owned PRs.
- Sprint comments and plan close actions are main-agent orchestration artifacts; implementation remains subagent-owned.
