# OpenCode Adapter

This document shows how to map the canonical `plan-issue-delivery`
`workflow_role` contract onto OpenCode's native agent system.

## What Stays Canonical

- The repo contract remains:
  - `workflow_role=implementation|review|monitor`
  - dispatch bundle and runtime artifacts
  - `plan-issue-delivery-main-agent-init.md`
  - `plan-issue-delivery-subagent-init.md`
- OpenCode config and agent files are an adapter layer only.

## OpenCode Features Used

- Project config in `opencode.json`
- Project agent markdown under `.opencode/agents/`
- Per-agent `mode`, `tools`, `permission`, `model`, and `prompt`
- `permission.task` to restrict which subagents a primary agent can invoke

## Recommended Mapping

- Canonical `workflow_role=implementation`
  - OpenCode subagent: `plan-issue-implementation`
- Canonical `workflow_role=review`
  - OpenCode subagent: `plan-issue-review`
- Canonical `workflow_role=monitor`
  - OpenCode subagent: `plan-issue-monitor`
- Optional OpenCode-only convenience primary agent:
  - `plan-issue-orchestrator`

## Project Adapter Files

Templates live under:

- `assets/runtime-adapters/opencode/project/opencode.json`
- `assets/runtime-adapters/opencode/project/.opencode/prompts/plan-issue-orchestrator.txt`
- `assets/runtime-adapters/opencode/project/.opencode/agents/plan-issue-implementation.md`
- `assets/runtime-adapters/opencode/project/.opencode/agents/plan-issue-review.md`
- `assets/runtime-adapters/opencode/project/.opencode/agents/plan-issue-monitor.md`

Recommended install target in a project:

- `opencode.json`
- `.opencode/prompts/plan-issue-orchestrator.txt`
- `.opencode/agents/plan-issue-implementation.md`
- `.opencode/agents/plan-issue-review.md`
- `.opencode/agents/plan-issue-monitor.md`

Optional installer/sync entrypoint:

- `$AGENT_HOME/scripts/plan-issue-adapter install --runtime opencode --project-path /path/to/project`
- `$AGENT_HOME/scripts/plan-issue-adapter sync --runtime opencode --project-path /path/to/project --apply`
- `$AGENT_HOME/scripts/plan-issue-adapter status --runtime opencode --project-path /path/to/project`

## Usage Notes

1. Keep dynamic issue/sprint/task facts in the dispatch bundle and prompt
   snapshots, not in `opencode.json`.
2. Use `permission.task` on the optional orchestrator agent to allow only the
   three plan-issue subagents.
3. The installer merges only `agent.plan-issue-orchestrator` into an existing
   `opencode.json`; unrelated keys stay untouched.
4. Keep `plan-issue-review` and `plan-issue-monitor` read-only by disabling
   edit/write and tightening bash permissions.
5. If project-level OpenCode agents are unavailable, continue using the
   canonical `workflow_role` contract without named runtime agents.
