---
name: semantic-commit
description: Commit staged changes using Semantic Commit format.
---

# Semantic Commit

## Contract

Prereqs:

- Run inside a git work tree (or pass `--repo <path>` to target one explicitly).
- `git` available on `PATH`.
- `semantic-commit` available on `PATH` (install via `brew install nils-cli`).
- `git-scope` is optional; default summary mode falls back to `git show` when unavailable.

Inputs:

- Staged changes (`git add ...`) for `semantic-commit staged-context`.
- Prepared commit message via stdin (preferred), `--message`, or `--message-file` for `semantic-commit commit`.
- Optional target repository via `--repo <path>`.

Outputs:

- `semantic-commit staged-context`: prints staged change context in `bundle|json|patch` format.
- `semantic-commit commit`: validates message, optionally commits staged changes, and prints commit summary unless disabled.
- Optional recovery file from `--message-out <path>`.

Exit codes:

- `0`: success (including `--validate-only`, `--dry-run`, and help output).
- `1`: usage or operational failure (invalid args, git command failure, hooks/conflicts, bad repo path).
- `2`: no staged changes for commands that require staged input.
- `3`: commit message missing/empty.
- `4`: commit message validation failed.
- `5`: required dependency missing (for example, `git`).

Failure modes:

- Not in a git repo and no valid `--repo` supplied.
- No staged changes (`exit 2`).
- No message provided in automation mode (`exit 3`).
- Message format invalid (`exit 4`).
- `git commit` failure (hooks/conflicts/signing/repo state) (`exit 1`).
- Summary helper unavailable (`git-scope` missing): warning emitted, fallback to `git show`.

## Setup

- Run inside the target git repo, or use `--repo <path>` to avoid shell `cwd` switching.
- Use only the entrypoints below; they are the stable interface for agents.

## Commands (only entrypoints)

- Get staged context:
  - `semantic-commit staged-context [--format <bundle|json|patch>] [--json] [--repo <path>]`
- Commit / validate prepared message:
  - `semantic-commit commit [--message <text>|--message-file <path>] [options]`
  - Useful options: `--message-out`, `--summary <git-scope|git-show|none>`, `--no-summary`, `--validate-only`, `--dry-run`, `--automation`, `--repo`, `--no-progress`, `--quiet`
- Do not call internal helpers directly; treat these commands as the only contract surface.

## Workflow

Rules:

- Never run `git add` in this skill; commit only what the user has already staged.
- Build message intent from `semantic-commit staged-context` output only.
- Prefer explicit `--repo <path>` when operating from another working directory.

Recommended flow:

1. Run `semantic-commit staged-context --format bundle` (or `--json` if your parser expects JSON only).
2. Draft the semantic message (`type(scope): subject` + optional bullet body).
3. Run `semantic-commit commit --validate-only ...` before committing to catch formatting errors early.
4. Optionally run `semantic-commit commit --dry-run ...` for staged/message sanity checks without creating a commit.
5. Run `semantic-commit commit ...` to finalize.
6. Capture and report `exit_code`, `stdout`, and `stderr`.

## Follow Semantic Commit format

Use one of:

- `type(scope): subject`
- `type: subject`

Rules:

- Type must be lowercase.
- Header length must be `<= 100` characters.
- If body exists: line 2 must be blank, and every body line must start with `- ` followed by an uppercase letter.
- Each body line must be `<= 100` characters.

## Error handling matrix

- `exit 2` (`no staged changes`): stop and ask for staging.
- `exit 3` (`message missing/empty`): provide/repair `--message` or `--message-file`.
- `exit 4` (`validation failed`): fix header/body format first; do not commit.
- `exit 1` from commit: treat as operational failure and report stderr verbatim.
- `git-scope` warning only: not fatal unless summary is explicitly required to be `git-scope`.

## Example

```bash
semantic-commit staged-context --format json

semantic-commit commit \
  --message-file /tmp/commit-msg.txt \
  --validate-only

semantic-commit commit \
  --message-file /tmp/commit-msg.txt \
  --summary git-show
```

## Output and clarification rules

- On failure: include command, exit code, and stderr; do not claim success.
- On success: include command output (commit summary) in a code block.
- If staged context cannot disambiguate type/scope/subject, ask one concise clarification question before committing.
