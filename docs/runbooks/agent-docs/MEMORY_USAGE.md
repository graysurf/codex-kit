# Memory Usage

## Scope

- This document defines when and how agents should use personal environment
  memory stored outside project repositories.
- Memory path, when present: `~/.config/agent-memory/`.
- Memory is home-scope context. It can inform work across repositories, but it is
  not project state and is not a substitute for current user instructions or
  project documentation.
- The memory directory is optional and environment-specific. Its absence is not a
  startup, preflight, or task failure.

## Missing memory directory

- If `~/.config/agent-memory/` does not exist, treat that as "no personal memory
  is available" and continue with current user instructions, project docs, and
  task evidence.
- Do not ask the user to create the directory just to proceed with a task.
- Do not create the directory merely to read memory.
- Create the directory only when writing a durable memory entry is appropriate
  under this policy and the active environment allows local file writes.
- `AGENT_DOCS.toml` may require this policy document to be present; it must not
  require the personal memory directory itself to exist.

## What belongs in memory

- Durable personal preferences, such as response language, review style, output
  format preferences, or recurring decision criteria.
- Stable personal environment facts, such as preferred local paths, shells,
  editors, runtimes, tool habits, or workspace conventions.
- Reusable personal references that the user expects agents to remember across
  sessions.
- Recurring account, calendar, reporting, organization, or workflow conventions
  when they are safe to store and useful across tasks.

## When to read memory

Read the relevant memory files before asking the user to restate personal context
when the task depends on one or more of these signals:

- The user refers to personal setup or prior convention, for example "my usual
  setup", "same as before", "our normal process", "use my standard format", or
  "the usual report".
- The task asks for work that may depend on preferred local paths, tools, shells,
  editors, runtimes, accounts, workspaces, calendars, or reporting conventions.
- The task involves repeated personal workflows, such as weekly reporting,
  scheduling conventions, recurring customer-facing summaries, or preferred PR /
  review formats.
- The next action would otherwise require asking the user for personal
  environment details that may already be recorded.

## When not to read memory

- Do not preload, scan, or summarize memory when the task is self-contained.
- Do not read memory when project-local docs, repository files, or current user
  instructions already provide enough context for the next action.
- Do not read memory if it would not change the action, command, file target, or
  answer.
- Do not use memory to override explicit user instructions or closer project
  policy.

## Authority and conflict rules

- Treat memory as context, not authority.
- Current user instructions override memory.
- Closer project docs, repository files, and verified task evidence override
  memory when they conflict.
- If memory appears stale or contradictory, state the conflict briefly and rely on
  the freshest task-specific evidence.

## When to write or update memory

- Write or update memory only for durable personal preferences or reusable
  environment facts that are likely to be useful across sessions.
- Keep entries concise, source-aware, and easy to invalidate later.
- Do not create memory entries merely to mirror a single response or one-off task
  result.

## What must not be stored

- Secrets, credentials, API keys, tokens, private keys, recovery codes, or session
  cookies.
- Temporary task state, draft conclusions, transient plans, or intermediate
  command output.
- Project state that belongs in git history, project docs, issue trackers, or
  `agent-docs`.
- Sensitive personal data that is not necessary for recurring agent behavior.
