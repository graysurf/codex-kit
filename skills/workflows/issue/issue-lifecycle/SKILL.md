---
name: issue-lifecycle
description: Main-agent workflow for opening, maintaining, decomposing, and closing GitHub Issues as the single source of planning state.
---

# Issue Lifecycle

Main agent owns issue state and task decomposition; implementation is delegated to subagents via PR workflows.

## Contract

Prereqs:

- Run inside the target git repo.
- `gh` available on `PATH`, and `gh auth status` succeeds.
- `python3` available on `PATH` for decomposition rendering.

Inputs:

- Issue title/body data (or template-based body).
- Optional labels/assignees/projects/milestone metadata.
- Optional decomposition TSV spec (`task_id`, `summary`, `branch`, `worktree`, `owner`, `notes`).

Outputs:

- Issue created/updated/closed/reopened via GitHub Issues.
- Optional decomposition markdown comment posted to the issue.
- Deterministic consistency checks on `Task Decomposition` (single source of truth).
- Deterministic CLI output suitable for orchestration scripts.
- Owner policy enforcement for implementation tasks: `Owner` must reference a subagent identity.
- Canonical task-lane storage in `Task Decomposition`, aligned with the shared
  issue workflow continuity policy.

Exit codes:

- `0`: success
- non-zero: invalid inputs, missing tools, or `gh` command failures

Failure modes:

- Missing required subcommand flags (`--title`, `--issue`, `--spec`, etc.).
- Ambiguous body inputs (`--body` and `--body-file` together).
- Decomposition spec malformed (wrong TSV shape or empty rows).
- Template consistency violations (invalid status/execution mode, missing execution metadata for active tasks, duplicated branch/worktree
  under `pr-isolated` mode).
- Owner policy violations (`Owner` missing, placeholder, or main-agent/non-subagent identity).
- `gh` auth/permission failures.

## Entrypoint

- `$AGENT_HOME/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh`

## Core usage

1. Create issue (main-agent owned):
   - `.../manage_issue_lifecycle.sh open --title "<title>" --label issue --label needs-triage`
2. Maintain issue body/labels while work progresses:
   - `.../manage_issue_lifecycle.sh update --issue <num> --body-file <path> --add-label in-progress`
3. Decompose work into subagent tasks:
   - `.../manage_issue_lifecycle.sh decompose --issue <num> --spec <task-split.tsv> --comment`
4. Validate/sync issue body consistency:
   - `.../manage_issue_lifecycle.sh validate --issue <num>`
   - `.../manage_issue_lifecycle.sh sync --issue <num>`
   - `.../manage_issue_lifecycle.sh sync --body-file <path> --write`
5. Log progress checkpoints:
   - `.../manage_issue_lifecycle.sh comment --issue <num> --body "<status update>"`
6. Close/reopen issue as workflow state changes:
   - `.../manage_issue_lifecycle.sh close --issue <num> --reason completed --comment "Implemented via #<pr>"`
   - `.../manage_issue_lifecycle.sh reopen --issue <num> --comment "Follow-up required"`

## References

- Skill issue template (single source of truth): `references/ISSUE_TEMPLATE.md`
- Task split example spec: `references/TASK_SPLIT_SPEC.tsv`
- Shared task-lane continuity policy (canonical):
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Shared post-review outcome handling (canonical):
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`

## Notes

- Use `--dry-run` whenever composing commands from a higher-level orchestrator.
- `Task Decomposition` is the only execution-state table in the issue body. `Owner` / `Branch` / `Worktree` / `Execution Mode` / `PR` should
  start as `TBD` and be updated with actual values during execution.
- Once assigned, those row fields define the canonical task lane; follow the
  shared policy in
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`.
- `Execution Mode` values: `per-sprint`, `pr-isolated`, `pr-shared` (or `TBD` before assignment). Branch/worktree uniqueness is enforced
  only for `pr-isolated`.
- `open` / `update` automatically validate template consistency when body contains `## Task Decomposition`; use `--skip-consistency-check`
  only for exceptional cases.
- `sync` normalizes the task table shape (including `Execution Mode`) and removes any legacy `## Subagent PRs` section.
- Keep decomposition and status notes in issue comments so execution history remains traceable.
- Review outcomes should sync `Task Decomposition` state using the shared
  post-review rules in
  `skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md`.
- In issue-driven implementation loops, `Owner` is for subagents only; main-agent remains orchestration/review-only.
