---
name: committer
description: Generate Git commit messages in Semantic Commit format. Use when asked to write commit messages, format Semantic Commits, or summarize changes/diffs into a commit.
---

# Committer

## Use staged context only

Rules:

- Prefer staged changes as input via `git-commit-context --stdout`
- If `git-commit-context` is not available, collect fallback inputs:
  - `git diff --staged --no-color` for the diff
  - `git-scope staged --no-color` for the scope tree (fallback: `git diff --staged --name-only`)
  - For each staged file, include its staged version via `git show :<path>`
  - If a file is deleted and has no index version, note it as deleted
- Do not infer from unstaged changes or untracked files
- If staged diff is empty, ask for staged changes or a change summary

## Setup (if command missing)

- `git-commit-context` is defined in `~/.config/zsh/scripts/git/git-tools.zsh`
- Load it with `source ~/.codex/tools/codex-tools.zsh`
- If that is unavailable, run `source ~/.config/zsh/scripts/git/git-tools.zsh`

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

- Generate the full commit message from staged context
- Write the message to a temporary file to preserve formatting
- Run `git commit -F <temp-file>` and remove the temp file afterward
- Capture the exit status in `rc` or `exit_code` (do not use `status`)
- If the commit fails, report the error and do not claim success

## Output and clarification rules

- After a successful commit, run `git-scope commit HEAD --no-color`
- Print the `git-scope` output in a code block
- If type, scope, or change summary is missing, ask a concise clarifying question and do not commit

## Example

```md
refactor(members): simplify otp purpose validation logic in requestOtp

- Merged duplicated member existence checks into a single query
- Reordered conditional logic for better readability
```

## Input completeness

- Full-file reads are not required for commit message generation
- Base the message on staged diff, scope tree, and staged (index) version content
- Only read full files if the diff/context is insufficient to describe the change accurately
