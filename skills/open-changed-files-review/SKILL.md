---
name: open-changed-files-review
description: Open files edited by Codex in VSCode after making changes, using the bundled open-changed-files script (silent no-op when unavailable).
---

# Open Changed Files Review

Use this skill when Codex has edited files and you want to immediately open the touched files in Visual Studio Code for human review.

## Inputs

- A list of file paths that were modified/added in this Codex run (preferred; does not require git).

## Workflow

1. Build a de-duplicated list of existing files from the touched paths.
2. Determine the cap:
   - Default: `CODEX_OPEN_CHANGED_FILES_MAX_FILES=50`
   - If there are more files than the cap: open the first N and mention that it was truncated.
3. Prefer running:
   - `$CODEX_HOME/skills/open-changed-files-review/scripts/open-changed-files.zsh --max-files "$max" --workspace-mode pwd -- <files...>`
4. If VSCode CLI `code` (or the tool) is unavailable: silent no-op (exit `0`, no errors), but still print a paste-ready manual command plus the file list for the user.

## Paste-ready command template

```zsh
$CODEX_HOME/skills/open-changed-files-review/scripts/open-changed-files.zsh --max-files "${CODEX_OPEN_CHANGED_FILES_MAX_FILES:-50}" --workspace-mode pwd -- <files...>
```
