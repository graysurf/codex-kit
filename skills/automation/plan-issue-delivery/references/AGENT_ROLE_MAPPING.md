# Agent Role Mapping

This document defines the canonical workflow-role contract for
`plan-issue-delivery` and shows how runtime-specific adapters may map those
roles to local child-agent features.

## Canonical Roles

- `implementation`
  - Owns code changes, tests, and sprint PR updates for an assigned task lane.
- `review`
  - Performs read-only audit work such as PR evidence gathering, merged-diff
    checks, and plan-conformance analysis.
- `monitor`
  - Performs read-only wait/watch work such as CI polling and required-check
    monitoring.

## Traceability Rules

- `workflow_role` is required in prompt manifests and each
  `DISPATCH_RECORD_PATH`.
- `runtime_name` / `runtime_role` are optional adapter fields and should be
  recorded only when the active runtime supports named child-agent roles.
- If a named-role runtime falls back to a generic child agent, keep
  `workflow_role` unchanged and record:
  - `runtime_role=generic`
  - `runtime_role_fallback_reason=<why the adapter role was unavailable>`

## Adapter Selection Policy

- Codex, Claude Code, and OpenCode are peer runtime adapter candidates.
- No runtime adapter is the repo default.
- Choose the adapter that matches the active CLI, or use no named-role adapter
  when the runtime does not support one.

## Runtime Adapter Examples

- Codex:
  - `implementation -> plan_issue_worker`
  - `review -> plan_issue_reviewer`
  - `monitor -> plan_issue_monitor`
  - guide + templates: `references/CODEX_ADAPTER.md`
- Claude Code:
  - `implementation -> plan-issue-implementation`
  - `review -> plan-issue-review`
  - `monitor -> plan-issue-monitor`
  - guide + templates: `references/CLAUDE_CODE_ADAPTER.md`
- OpenCode:
  - `implementation -> plan-issue-implementation`
  - `review -> plan-issue-review`
  - `monitor -> plan-issue-monitor`
  - guide + templates: `references/OPENCODE_ADAPTER.md`

## Runtime Adapter Notes

- Repo workflow docs should describe only canonical `workflow_role` behavior.
- Runtime-specific config stays outside the repo contract unless a project
  explicitly chooses to version an adapter.
- Use the explicit installer/sync entrypoint when you want managed adapter setup:
  - `$AGENT_HOME/scripts/plan-issue-adapter <install|sync|status> --runtime <codex|claude|opencode> [--apply]`
- Runtimes without named child-agent role support can still execute the full
  workflow by honoring `workflow_role` via prompt instructions alone.
- Runtime-specific installation examples:
  - Codex: `references/CODEX_ADAPTER.md`
  - Claude Code: `references/CLAUDE_CODE_ADAPTER.md`
  - OpenCode: `references/OPENCODE_ADAPTER.md`
