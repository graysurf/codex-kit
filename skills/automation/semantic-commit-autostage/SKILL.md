---
name: semantic-commit-autostage
description: Autostage (git add) and commit changes using Semantic Commit format for fully automated workflows where Codex owns the full change set and the user should not manually stage files.
---

# Semantic Commit (Autostage)

## Contract

Prereqs:

- Run inside a git work tree.
- `git` available on `PATH`.
- `semantic-commit` available on `PATH` (install via `brew install nils-cli`).
- `git-scope` available on `PATH` (install via `brew install nils-cli`) (required).

Inputs:

- Unstaged changes in the working tree (this skill will stage them via `git add`).
- Prepared commit message via stdin (preferred), `--message`, or `--message-file` for `semantic-commit commit`.

Outputs:

- Staged changes via `git add` (this skill autostages).
- `semantic-commit staged-context`: prints staged diff context to stdout.
- `semantic-commit commit`: creates a git commit and prints a commit summary to stdout.

Exit codes:

- `0`: success
- `2`: no changes to stage/commit
- non-zero: invalid usage / missing prerequisites / git failures

Failure modes:

- Not in a git repo.
- `git-scope` missing or fails.
- Dirty starting state includes unrelated changes; autostage may include unintended files (start from a clean tree).
- `git add` fails (pathspec errors, permissions).
- `git commit` fails (hooks, conflicts, or repo state issues).
- Commit message validation fails (header/body rules are hard-fail).

## Setup

- Run inside the target git repo
- Prefer using the `semantic-commit` commands below; they resolve required commands directly

## Commands (only entrypoints)

- Autostage (all changes): `git add -A`
- Autostage (tracked-only): `git add -u`
- Get staged context (stdout): `semantic-commit staged-context`
- Commit with a prepared message, then print a commit summary (stdout): `semantic-commit commit`
  - Prefer piping the full multi-line message via stdin
- **Do not run any other repo-inspection commands** (especially `git status`, `git diff`, `git show`, `rg`, or reading repo files like `cat path/to/file`); the only source of truth is `semantic-commit staged-context` output (after autostage)

## Workflow

Rules:

- This skill **may** run `git add` (autostage). Use only when the user asked for end-to-end automation and will not stage files manually.
- For review-first flows where the user stages a subset, use `semantic-commit` instead.
- Prefer starting from a clean working tree to avoid staging unrelated local changes.
- After autostage, do not run any extra repo-inspection commands; generate the commit message from `semantic-commit staged-context` output only
- If `semantic-commit staged-context` exits `2`, treat it as "no changes to stage/commit" and stop
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

- Generate the full commit message from `semantic-commit staged-context` output
- Commit by piping the full message into `semantic-commit commit` (it preserves formatting)
- Capture the exit status in `rc` or `exit_code` (do not use `status`)
- If the commit fails, report the error and do not claim success

## Input completeness

- Full-file reads are not allowed for commit message generation
- Base the message on `semantic-commit staged-context` output only
- If the staged context is insufficient to describe the change accurately, ask a concise clarifying question (do not run additional commands)

## Output and clarification rules

- If type, scope, or change summary is missing, ask a concise clarifying question and do not commit
- Always run `semantic-commit commit` for committing (it will print the commit summary on success)
- On command failure: include exit code + stderr in the response, and do not claim success
- On success: include the command stdout (commit summary) in a code block
