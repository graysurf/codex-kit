# Plan-Issue CLI Skill Mapping

This matrix maps the legacy `plan-issue-delivery-loop.sh` command surface to Rust CLI entrypoints.

| Legacy Command | New Command | Scope |
| --- | --- | --- |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh start-plan` | `plan-issue start-plan` | Live GitHub-backed plan bootstrap (`1 plan = 1 issue`). |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh start-sprint` | `plan-issue start-sprint` | Live sprint kickoff and task-row sync. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh ready-sprint` | `plan-issue ready-sprint` | Live sprint-ready review request comment. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh accept-sprint` | `plan-issue accept-sprint` | Live sprint acceptance gate (merged PR check + `Status=done` sync). |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh ready-plan` | `plan-issue ready-plan` | Live final plan review handoff. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh close-plan` | `plan-issue close-plan` | Live final close gate + worktree cleanup enforcement. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh status-plan` | `plan-issue status-plan` | Live plan issue status snapshot. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh status-sprint` | `plan-issue status-plan` | Legacy alias removal: use `status-plan` in Rust CLI. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-task-spec` | `plan-issue build-task-spec` | Build sprint-scoped task-spec TSV from plan. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh build-plan-task-spec` | `plan-issue build-plan-task-spec` | Build plan-scoped task-spec TSV (all sprints). |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh cleanup-worktrees` | `plan-issue cleanup-worktrees` | Enforce cleanup of issue-assigned task worktrees. |
| `$AGENT_HOME/skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh multi-sprint-guide` | `plan-issue multi-sprint-guide` | Print repeated multi-sprint orchestration flow. |

`plan-issue-local` supports the same subcommands as `plan-issue` for local-first rehearsal (typically with `--dry-run`).

## Inventory

### Directly Impacted Skills/Docs

- `skills/automation/plan-issue-delivery-loop/SKILL.md`
- `skills/automation/issue-delivery-loop/SKILL.md`
- `skills/workflows/issue/issue-subagent-pr/SKILL.md`
- `skills/workflows/issue/issue-pr-review/SKILL.md`
- `docs/runbooks/skills/TOOLING_INDEX_V2.md`

### Transitive Dependencies Relevant To This Migration

- `skills/automation/plan-issue-delivery-loop/scripts/plan-issue-delivery-loop.sh` (legacy wrapper being replaced by Rust binaries).
- `skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh` (status/review/close orchestration contract wrapped by plan-level commands).
- `skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh` (subagent worktree/PR execution path used by sprint orchestration).
- `skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh` (main-agent review/merge decisions used before accept/close gates).
- PATH tooling used by impacted skills: `plan-tooling`, `gh`.
