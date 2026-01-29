---
name: semantic-commit-autostage
description: Autostage (git add) and commit changes using Semantic Commit format for fully automated workflows where Codex owns the full change set and the user should not manually stage files.
---

# Semantic Commit (Autostage)

## Contract

Prereqs:

- Run inside a git work tree.
- `git` available on `PATH`.
- `zsh` available on `PATH` (scripts are `zsh -f`).
- `git-commit-context-json` available (via `CODEX_COMMANDS_PATH` or `$CODEX_HOME/commands`).
- `git-scope` available for commit summary output (optional; fallback is `git show --stat`).

Inputs:

- Unstaged changes in the working tree (this skill will stage them via `git add`).
- Prepared commit message via stdin (preferred), `--message`, or `--message-file` for `commit_with_message.sh`.

Outputs:

- Staged changes via `git add` (this skill autostages).
- `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/staged_context.sh`: prints staged context bundle to stdout (JSON + patch).
- `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/commit_with_message.sh`: creates a git commit and prints a commit summary to stdout.

Exit codes:

- `0`: success
- `2`: no changes to stage/commit
- non-zero: invalid usage / missing prerequisites / git failures

Failure modes:

- Not in a git repo.
- Dirty starting state includes unrelated changes; autostage may include unintended files (start from a clean tree).
- `git add` fails (pathspec errors, permissions).
- `git commit` fails (hooks, conflicts, or repo state issues).
- `git-commit-context-json` not found (falls back to raw `git diff`).
- Commit message validation fails (header/body rules are hard-fail).

## Setup

- Run inside the target git repo
- Prefer using the scripts below; they resolve required commands directly (no sourcing)

## Scripts (only entrypoints)

- Autostage (all changes): `git add -A`
- Autostage (tracked-only): `git add -u`
- Get staged context (stdout): `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/staged_context.sh`
- Commit with a prepared message, then print a commit summary (stdout): `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/commit_with_message.sh`
  - Prefer piping the full multi-line message via stdin
- **Do not run any other repo-inspection commands** (especially `git status`, `git diff`, `git show`, `rg`, or reading repo files like `cat path/to/file`); the only source of truth is `staged_context.sh` output (after autostage)

## Workflow

Rules:

- This skill **may** run `git add` (autostage). Use only when the user asked for end-to-end automation and will not stage files manually.
- For review-first flows where the user stages a subset, use `semantic-commit` instead.
- Prefer starting from a clean working tree to avoid staging unrelated local changes.
- After autostage, do not run any extra repo-inspection commands; generate the commit message from `staged_context.sh` output only
- If `staged_context.sh` exits `2`, treat it as "no changes to stage/commit" and stop
- Treat header/body validation errors as hard failures; report the error and do not claim success

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

- Generate the full commit message from semantic-commit `staged_context.sh` output
- Commit by piping the full message into semantic-commit `commit_with_message.sh` (it preserves formatting)
- Capture the exit status in `rc` or `exit_code` (do not use `status`)
- If the commit fails, report the error and do not claim success

## Input completeness

- Full-file reads are not allowed for commit message generation
- Base the message on `staged_context.sh` output only
- If the staged context is insufficient to describe the change accurately, ask a concise clarifying question (do not run additional commands)

## Output and clarification rules

- If type, scope, or change summary is missing, ask a concise clarifying question and do not commit
- Always run `commit_with_message.sh` for committing (it will print the commit summary on success)
- On script failure: include exit code + stderr in the response, and do not claim success
- On success: include the script stdout (commit summary) in a code block
