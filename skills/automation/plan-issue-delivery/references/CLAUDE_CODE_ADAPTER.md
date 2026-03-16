# Claude Code Adapter

This document shows how to map the canonical `plan-issue-delivery`
`workflow_role` contract onto Claude Code's native subagent system.

## What Stays Canonical

- The repo contract remains:
  - `workflow_role=implementation|review|monitor`
  - dispatch bundle and runtime artifacts
  - `plan-issue-delivery-main-agent-init.md`
  - `plan-issue-delivery-subagent-init.md`
- Claude-specific agent files are an adapter layer only.

## Claude Code Features Used

- Project-scoped subagents under `.claude/agents/`
- Optional user-scoped subagents under `~/.claude/agents/`
- YAML frontmatter fields such as `name`, `description`, `tools`, and `model`
- `Agent(...)` tool allowlists on the main-thread orchestrator agent

## Recommended Mapping

- Canonical `workflow_role=implementation`
  - Claude subagent: `plan-issue-implementation`
- Canonical `workflow_role=review`
  - Claude subagent: `plan-issue-review`
- Canonical `workflow_role=monitor`
  - Claude subagent: `plan-issue-monitor`
- Optional Claude-only convenience entrypoint for the main thread:
  - `plan-issue-orchestrator`

## Project Adapter Files

Templates live under:

- `assets/runtime-adapters/claude-code/project/.claude/agents/plan-issue-orchestrator.md`
- `assets/runtime-adapters/claude-code/project/.claude/agents/plan-issue-implementation.md`
- `assets/runtime-adapters/claude-code/project/.claude/agents/plan-issue-review.md`
- `assets/runtime-adapters/claude-code/project/.claude/agents/plan-issue-monitor.md`

Recommended install target in a project:

- `.claude/agents/plan-issue-orchestrator.md`
- `.claude/agents/plan-issue-implementation.md`
- `.claude/agents/plan-issue-review.md`
- `.claude/agents/plan-issue-monitor.md`

Optional installer/sync entrypoint:

- `$AGENT_HOME/scripts/plan-issue-adapter install --runtime claude --project-path /path/to/project`
- `$AGENT_HOME/scripts/plan-issue-adapter sync --runtime claude --project-path /path/to/project --apply`
- `$AGENT_HOME/scripts/plan-issue-adapter status --runtime claude --project-path /path/to/project`

## Usage Notes

1. Keep dynamic issue/sprint/task facts in the dispatch bundle and prompt
   snapshots, not in the Claude subagent files.
2. Use the orchestrator template only as a static capability router for the
   main thread. It should not become a second source of workflow truth.
3. The implementation subagent should stay write-capable; review and monitor
   templates stay read-only by tool restrictions.
4. If Claude-specific subagent files are unavailable, continue using the
   canonical `workflow_role` contract without named runtime agents.
