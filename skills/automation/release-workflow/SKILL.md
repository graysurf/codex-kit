---
name: release-workflow
description: Execute project release workflows by following a repo-provided release guide when present; otherwise use a changelog-driven fallback flow with helper scripts.
---

# Release Workflow

## Contract

Prereqs:

- Run inside (or have access to) the target repo.
- `bash` + `zsh` available on `PATH` to run helper scripts.
- `git` available on `PATH` (plus any release tooling required by the guide).

Inputs:

- The user’s requested release action (tag/release/publish) and the target repository path (if unclear).

Outputs:

- Resolve a release guide + template deterministically, then execute the guide steps exactly (no inference).

Exit codes:

- N/A (workflow driver; stop and ask on unclear steps)

Failure modes:

- Multiple repo guides found (must ask which to use).
- A guide step fails or is unclear (must stop and follow recovery instructions or ask).
- Default guide steps fail (must stop and ask how to proceed).

## Workflow

1. Identify the target repository root; ask if the repo path is unclear.
2. Resolve the guide + template (project-first; default fallback):
   - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .`
   - If it exits `3`, stop and ask which guide to use.
3. Read the resolved guide file fully before running any commands.
4. Execute the guide steps in order, using the exact commands and tooling specified.
5. If anything is unclear or a step fails, stop and ask rather than making assumptions.

## Output and clarification rules

- Use `references/OUTPUT_TEMPLATE.md` when a release is published.
- Use `references/OUTPUT_TEMPLATE_BLOCKED.md` when blocked (audit/check fails or unclear step).
- If a release is published, the response must include, in order:
  1. Release content
  2. Release link
- If blocked (e.g. an audit/check step fails), the response must include:
  1. Failure summary (including audit output when applicable)
  2. A direct question asking how to proceed

## Fallback flow (when no guide exists)

The default fallback guide lives at:

- `$CODEX_HOME/skills/automation/release-workflow/references/DEFAULT_RELEASE_GUIDE.md`

## Helper scripts (fallback)

These scripts are designed to run inside a target repo that uses `CHANGELOG.md` headings like `## vX.Y.Z - YYYY-MM-DD`.

- Locate a project release guide deterministically:
  - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-find-guide.sh --project-path "$PROJECT_PATH" --search-root "$(pwd)" --max-depth 3`
- Resolve the guide + template deterministically (preferred entrypoint):
  - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .`
- Scaffold a new entry from a template:
  - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-scaffold-entry.sh --repo . --version v1.3.2 --output "$CODEX_HOME/out/release-entry-v1.3.2.md"`
  - Selects the repo template when present; otherwise falls back to the bundled template.
- Audit basic prereqs + changelog format:
  - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-audit.sh --repo . --version v1.3.2 --branch main`
- Audit changelog formatting + placeholder cleanup:
  - `$CODEX_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh --repo . --check`
- Extract release notes from `CHANGELOG.md` into a file for `gh release create -F`:
  - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh --version v1.3.2 --output "$CODEX_HOME/out/release-notes-v1.3.2.md"`
