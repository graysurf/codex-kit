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
- `git-scope` is optional; default summary mode falls back to `git show` when unavailable.

Inputs:

- Unstaged changes in the working tree (this skill stages them via `git add`).
- Prepared commit message via `--message`, `--message-file`, or stdin (`--automation` disables stdin fallback).
- Optional target repository via `--repo <path>`.

Outputs:

- Staged changes via `git add` (`-A` or `-u`).
- `semantic-commit staged-context`: staged diff context for message generation.
- `semantic-commit commit`: validation result and commit summary (unless disabled).
- Optional recovery file from `--message-out <path>`.

Exit codes:

- `0`: success (including validate-only and dry-run checks).
- `1`: usage/operational failure (`git add`/git commit/hook/conflict/repo issues).
- `2`: no changes to stage/commit.
- `3`: commit message missing/empty.
- `4`: commit message validation failed.
- `5`: required dependency missing (for example, `git`).

Failure modes:

- Not in a git repo.
- Dirty tree includes unrelated work: `git add -A` may stage unintended files.
- `git add` failure (pathspec/permission/submodule state).
- No staged changes after autostage (`exit 2`).
- Automation mode without explicit message source (`exit 3`).
- Invalid message format (`exit 4`).
- `git commit` failure (`exit 1`).

## Setup

- Use this skill only when full autostage is intended and safe.
- If user expects review-first partial staging, switch to `semantic-commit` (non-autostage).

## Commands (only entrypoints)

- Autostage all changes: `git add -A`
- Autostage tracked-only changes: `git add -u`
- Get staged context:
  - `semantic-commit staged-context [--format <bundle|json|patch>] [--json] [--repo <path>]`
- Commit / validate prepared message:
  - `semantic-commit commit [--message <text>|--message-file <path>] [options]`
  - Useful options: `--automation`, `--validate-only`, `--dry-run`, `--message-out`, `--summary`, `--no-summary`, `--repo`, `--no-progress`, `--quiet`

## Workflow

Rules:

- Use `git add -A` by default; use `git add -u` only when untracked files must stay uncommitted.
- Generate the message from `semantic-commit staged-context` output only.
- For non-interactive reliability, prefer `--automation` with `--message` or `--message-file`.

Recommended flow:

1. Choose stage mode (`git add -A` or `git add -u`) and run it.
2. Run `semantic-commit staged-context --format bundle`.
3. Draft semantic message from staged context.
4. Run `semantic-commit commit --validate-only ...`.
5. Optionally run `semantic-commit commit --dry-run ...`.
6. Run `semantic-commit commit ...` for the real commit.
7. Report command, exit code, stdout, stderr.

## Follow Semantic Commit format

Use one of:

- `type(scope): subject`
- `type: subject`

Rules:

- Type must be lowercase.
- Header length must be `<= 100` characters.
- If body exists: blank line after header, then only `- ` bullets with uppercase first letter.
- Body lines must be `<= 100` characters.

## Error handling matrix

- `exit 2`: autostage produced no commitable delta.
- `exit 3`: missing/empty message (common with `--automation` + no `--message`).
- `exit 4`: semantic format validation failed.
- `exit 1`: operational failure (`git add`/`git commit`/hook conflict); report stderr verbatim.
- `git-scope` warning only: fallback to `git show` is expected behavior.

## Output and clarification rules

- On failure: include the failing command, exit code, and key stderr.
- On success: include commit summary stdout in a code block.
- If staged context and user intent conflict (mixed unrelated changes), stop and ask whether to proceed with broad autostage.
