---
name: semantic-commit
description: Commit staged changes using Semantic Commit format.
---

# Semantic Commit

## Contract

Prereqs:

- Run inside a git work tree.
- `git` available on `PATH`.
- `zsh` available on `PATH` (scripts are `zsh -f`).
- `$CODEX_HOME/scripts/codex-tools.sh` exists (provides `git-tools` and `git-scope`).

Inputs:

- Staged changes (`git add ...`) for `staged_context.sh`.
- Prepared commit message via stdin (preferred), `--message`, or `--message-file` for `commit_with_message.sh`.

Outputs:

- `staged_context.sh`: prints staged context to stdout (diff + scope tree).
- `commit_with_message.sh`: creates a git commit and prints a commit summary to stdout.

Exit codes:

- `0`: success
- `2`: no staged changes (for scripts that require staged input)
- non-zero: invalid usage / missing prerequisites / git failures

Failure modes:

- Not in a git repo or no staged changes.
- `$CODEX_HOME` unset and loader cannot be resolved.
- `git commit` fails (hooks, conflicts, or repo state issues).

## Setup

- Run inside the target git repo
- Prefer using the scripts below; they load Codex git helpers via `source $CODEX_HOME/scripts/codex-tools.sh` and hard-fail if unavailable

## Scripts (only entrypoints)

- Get staged context (stdout): `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/staged_context.sh`
- Commit with a prepared message, then print a commit summary (stdout): `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/commit_with_message.sh`
  - Prefer piping the full multi-line message via stdin
- Do not call other helper commands directly; treat these scripts as the stable interface

## Workflow

Rules:

- **Never** run `git add` on your own; **do not** stage files the user has not explicitly staged
- Use staged changes only; do not infer from unstaged/untracked files
- If `staged_context.sh` fails, report its error output and do not proceed to committing

## Follow Semantic Commit format

Use the exact header format:

type(scope): subject

Rules:

- Use a valid type (feat, fix, refactor, chore, etc.)
- Use a concise scope that matches the changed area
- Keep the subject lowercase and concise
- Keep the full header under 100 characters

## Write the body correctly

Rules:

- Insert one blank line between header and body
- Start every body line with "- " and a capitalized word
- Keep each line under 100 characters
- Keep bullets concise and group related changes
- Do not insert blank lines between body items
- For small or trivial changes, the body is optional; if included, use a single bullet and avoid restating the subject

## Commit execution

- Generate the full commit message from `staged_context.sh` output
- Commit by piping the full message into `commit_with_message.sh` (it preserves formatting)
- Capture the exit status in `rc` or `exit_code` (do not use `status`)
- If the commit fails, report the error and do not claim success

## Input completeness

- Full-file reads are not required for commit message generation
- Base the message on staged context only
- Only read full files if the diff/context is insufficient to describe the change accurately

## Example

```md
refactor(members): simplify otp purpose validation logic in requestOtp

- Merged duplicated member existence checks into a single query
- Reordered conditional logic for better readability
```

## Output and clarification rules

- If type, scope, or change summary is missing, ask a concise clarifying question and do not commit
- Always run `commit_with_message.sh` for committing (it will print the commit summary on success)
- On script failure: include exit code + stderr in the response, and do not claim success
- On success: include the script stdout (commit summary) in a code block
