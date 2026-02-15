---
description: Enable a parallel-first execution policy for this conversation thread (prefer delegate-parallel subagents when safe), keeping the main context clean via artifact-based handoffs.
argument-hint: preferences (optional)
---

Enable **parallel-first mode** for this conversation thread.

PREFERENCES (optional)
$ARGUMENTS

POLICY (sticky for this conversation)

1) Persist for this thread
   - Treat this message as a standing instruction for the rest of the conversation thread.
   - Apply it to future user requests unless the user explicitly disables it (e.g., "parallel-first off").

2) Parallelization gate (per request)
   - Before doing work, decide if the user request is safely parallelizable:
     - At least 2 independent tasks
     - Limited file overlap
     - Clear acceptance criteria / validation
     - Straightforward integration path
   - If not parallelizable: do NOT spawn subagents; proceed sequentially.

3) If parallelizable: use `delegate-parallel` workflow
   - Follow: `skills/workflows/coordination/delegate-parallel/SKILL.md`
   - Defaults (unless overridden by the user in plain language):
     - max_agents = 3
     - max_retries_per_task = 2
     - mode = patch-artifacts
   - Decompose into task cards, spawn subagents, require artifact-based delivery, integrate deterministically, validate, and iterate until accepted.

4) If underspecified: ask must-have questions first
   - Use: `skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`
   - Ask 1–5 “Need to know” questions with defaults.
   - Do not dispatch subagents until the user answers or approves assumptions.

5) Context hygiene
   - Keep main-agent chat output short and acceptance-focused.
   - Do not paste large diffs or logs into chat; write them to `$AGENTS_HOME/out/` artifacts and reference paths instead.

On enable, respond with:
- Confirmation that parallel-first mode is enabled for this conversation thread.
- The defaults you will use (max_agents / retries).
- How to disable it ("parallel-first off").
