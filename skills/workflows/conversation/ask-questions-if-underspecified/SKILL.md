---
name: ask-questions-if-underspecified
description: Clarify requirements before implementing changes or plans when a request is underspecified. Use when objectives, scope, constraints, acceptance criteria, or environment details are unclear and you need the minimum set of questions before proceeding.
---

# Ask Questions If Underspecified

## Contract

Prereqs:

- User request is missing must-have details (objective/scope/constraints/done criteria) and needs clarification before proceeding.
- User is available to answer questions or explicitly approve stated assumptions.

Inputs:

- User request + any provided context (codebase, environment, constraints, examples).
- Optional user preference for defaults vs custom answers (e.g., "defaults").

Outputs:

- 1-5 numbered "Need to know" questions with short options and an explicit default.
- If the user asks to proceed without answers: a short numbered assumptions list to confirm before starting work.

Exit codes:

- N/A (conversation workflow; no repo scripts)

Failure modes:

- User cannot provide required answers and will not approve assumptions (must stop; do not implement).
- Constraints conflict or request stays ambiguous after Q/A (must clarify before proceeding).

## Goal

Ask the minimum set of clarifying questions needed to avoid wrong work. Do not begin implementation until must-have answers are provided or the user explicitly approves stated assumptions.

## Workflow

1) Decide whether the request is underspecified

   - Check objective (what should change vs stay the same)
   - Check done criteria (acceptance, examples, edge cases)
   - Check scope (files/components/users in or out)
   - Check constraints (compatibility, performance, style, deps, time)
   - Check environment (language/runtime versions, OS, test runner)
   - Check safety/reversibility (migrations, rollout, risk)

2) Ask must-have questions first

   - Ask 1 to 5 questions that remove whole branches of work
   - Use numbered questions with short options (a/b/c)
   - Provide a clear default (bold it) and a fast path reply like "defaults"
   - Allow "not sure - use default" when helpful
   - Separate "Need to know" from "Nice to know" only if it reduces friction

3) Pause before acting

   - Do not run commands, edit files, or make a detailed plan that depends on missing info
   - A low-risk discovery read is allowed if it does not commit to a direction

4) Confirm and proceed

   - Restate requirements and success criteria in 1 to 3 sentences
   - Begin work only after answers or explicit approval of assumptions

## Response format

Use a compact, scannable structure. Example:

```text
Need to know
1) Scope?
   a) **Minimal change**
   b) Refactor while touching the area
   c) Not sure - use default
2) Compatibility target?
   a) **Current project defaults**
   b) Also support older versions: <specify>
   c) Not sure - use default
Reply with: defaults (or 1a 2a)
```

## If asked to proceed without answers

- State assumptions as a short numbered list
- Ask for confirmation
- Proceed only after confirmation or corrections
