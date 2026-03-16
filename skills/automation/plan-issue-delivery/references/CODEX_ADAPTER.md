# Codex Adapter

This document shows how to map the canonical `plan-issue-delivery`
`workflow_role` contract onto Codex's native child-agent role system.

## What Stays Canonical

- The repo contract remains:
  - `workflow_role=implementation|review|monitor`
  - dispatch bundle and runtime artifacts
  - `plan-issue-delivery-main-agent-init.md`
  - `plan-issue-delivery-subagent-init.md`
- Codex config under `~/.codex/` is an adapter layer only.

## Codex Features Used

- Local named child-agent roles in `~/.codex/config.toml`
- Per-role config files under `~/.codex/agents/`
- Runtime traceability fields such as `runtime_name` / `runtime_role`

## Recommended Mapping

- Canonical `workflow_role=implementation`
  - Codex child-agent role: `plan_issue_worker`
- Canonical `workflow_role=review`
  - Codex child-agent role: `plan_issue_reviewer`
- Canonical `workflow_role=monitor`
  - Codex child-agent role: `plan_issue_monitor`
- The main Codex thread remains the orchestrator; no extra named orchestrator
  role is required.

## Adapter Templates

Templates live under:

- `assets/runtime-adapters/codex/home/.codex/config.toml`
- `assets/runtime-adapters/codex/home/.codex/agents/plan-issue-worker.toml`
- `assets/runtime-adapters/codex/home/.codex/agents/plan-issue-reviewer.toml`
- `assets/runtime-adapters/codex/home/.codex/agents/plan-issue-monitor.toml`

Recommended install target on a machine running Codex:

- `~/.codex/config.toml`
- `~/.codex/agents/plan-issue-worker.toml`
- `~/.codex/agents/plan-issue-reviewer.toml`
- `~/.codex/agents/plan-issue-monitor.toml`

Optional installer/sync entrypoint:

- `$AGENT_HOME/scripts/plan-issue-adapter install --runtime codex`
- `$AGENT_HOME/scripts/plan-issue-adapter sync --runtime codex --apply`
- `$AGENT_HOME/scripts/plan-issue-adapter status --runtime codex`

## Usage Notes

1. Keep dynamic issue/sprint/task facts in the dispatch bundle and prompt
   snapshots, not in `~/.codex/config.toml`.
2. Because the Codex adapter is machine-scoped, treat these repo templates as
   mergeable examples rather than project-truth config.
3. The installer merges only the managed `plan_issue_*` agent sections into an
   existing `~/.codex/config.toml`; unrelated config stays untouched.
4. If named child-agent roles are unavailable, continue using the canonical
   `workflow_role` contract without a Codex-specific adapter.
5. No runtime adapter is the repo default; choose Codex, Claude Code, OpenCode,
   or no named-role adapter explicitly for the active environment.
