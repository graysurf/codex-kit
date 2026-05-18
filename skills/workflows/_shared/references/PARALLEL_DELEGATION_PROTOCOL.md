# Parallel Delegation Protocol

Use this shared protocol when a user-facing workflow has already passed an explicit
delegation gate and needs common subagent execution rules.

This is not a user-facing skill. It is a cross-skill protocol for prompt modes
and execution workflows that need ad-hoc parallel implementation lanes without a
more specific plan, issue, or PR workflow contract.

## When To Use

Use this protocol from another workflow when all are true:

- The user explicitly enabled a delegation mode or invoked a workflow that allows
  subagents.
- The work splits into at least two independent lanes, or one broad lane that
  benefits from isolated implementation ownership.
- File overlap is limited and integration is straightforward.
- Acceptance criteria and validation are clear enough to delegate safely.
- The main agent owns scope, dispatch, integration, validation, and final
  reporting.

Do not use this protocol for small changes, unclear requirements, tightly coupled
refactors, destructive operations, or work whose next step blocks on a subagent
result.

## Prefer More Specific Workflows

- Use `execute-plan-parallel` when an existing markdown plan should be executed
  through parallel subagents.
- Use `execute-from-plan` when a durable plan and execution-state ledger should
  drive long-running work.
- Use `issue-delivery`, `plan-issue-delivery`, and `issue-subagent-pr` for
  GitHub issue, sprint, PR, and task-lane execution.
- Use this protocol only for cross-skill ad-hoc delegation after the active
  entrypoint has authorized subagents.

## Defaults

- `max_agents`: 3
- `max_retries_per_task`: 2
- `mode`: direct-lane-work or patch-artifacts, depending on runtime support
- `artifact_root`: output from `agent-out project --topic parallel-delegation --mkdir`

If `agent-out` is unavailable, use a project-local run directory that is clearly
temporary and excluded from tracked source unless the project defines another
artifact policy.

## Task Card Schema

Each delegated lane must receive a concrete task card:

- `ID`: `T1`, `T2`, ...
- `Objective`: one responsibility
- `Scope`: allowed dirs/files and explicit out-of-scope items
- `Dependencies`: other task IDs, if any
- `Acceptance criteria`: checklist
- `Validation`: minimum commands or manual checks
- `Expected artifacts`: report, changed files or patch, commands, and logs

If two task cards need to edit the same files substantially, merge them or
serialize them instead of dispatching both in parallel.

## Subagent Contract

Each subagent owns exactly one task card.

Required instructions:

- Stay within assigned scope and allowed files.
- Do not revert or overwrite changes made by other agents.
- Keep chat output short and write details to artifacts when available.
- Report changed files, acceptance evidence, validation run, and blockers.

For artifact-based runs, each task folder should contain:

- `REPORT.md`: at most 10 lines covering what changed, files touched, acceptance
  evidence, validation result, and remaining risks.
- `changes.patch`: clean unified diff when the runtime cannot merge direct
  workspace edits safely.
- `commands.txt`: commands executed, if any.
- `logs.txt`: trimmed logs; full logs belong here instead of chat.

## Main-Agent Integration Loop

1. Dispatch only unblocked task cards, limited by `max_agents`.
2. Review each returned lane for scope, completeness, and validation evidence.
3. Integrate in deterministic order.
4. Run the lane validation or closest available equivalent.
5. If rejected, send a concrete acceptance delta back to the same subagent.
6. Retry up to `max_retries_per_task`.
7. Run the best available global validation after integration.
8. Report completed lanes, blocked lanes, files changed, validation, and residual
   risk.

If validation fails after integration, route the fix back to the responsible lane
when practical. The main agent may make small integration or glue fixes only when
that is simpler and remains inside the accepted scope.
