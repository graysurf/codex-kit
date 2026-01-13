---
name: release-workflow
description: Execute project release workflows by locating and following project-specific RELEASE_GUIDE.md in the repository root or docs/. Includes fallback CHANGELOG templates and helper scripts for changelog-driven GitHub releases.
---

# Release Workflow

## Contract

Prereqs:

- Run inside (or have access to) the target repo.
- `rg` available on `PATH` to locate `RELEASE_GUIDE.md`.
- `git` available on `PATH` (plus any release tooling required by the guide).

Inputs:

- The user’s requested release action (tag/release/publish) and the target repository path (if unclear).

Outputs:

- Release steps executed exactly per the project’s `RELEASE_GUIDE.md`, plus release notes/link as provided by the guide.
- When the project has no guide, a proposed fallback flow + templates/scripts (must ask for confirmation before running).

Exit codes:

- N/A (workflow driver; stop and ask on unclear steps)

Failure modes:

- `RELEASE_GUIDE.md` missing or multiple guides found (must ask which to use).
- A guide step fails or is unclear (must stop and follow recovery instructions or ask).

## Setup

- Load commands with `source $CODEX_HOME/scripts/codex-tools.sh`

## Project-first rule (important)

- If the target repo provides any of the following, always prefer them over codex-kit defaults:
  - `RELEASE_GUIDE.md`
  - `docs/templates/RELEASE_TEMPLATE.md` (or an equivalent template path documented by the repo)
  - repo-local release scripts / Makefile / CI tasks
- Only use the templates/scripts in this skill as a fallback when the repo has no release guide and the user confirms the fallback flow.

## Workflow

1. Identify the target repository root; ask if the repo path is unclear.
2. Locate `RELEASE_GUIDE.md` in the repo root or `docs/`:
   - Prefer `rg --files -g 'RELEASE_GUIDE.md'` from the repo root.
   - If multiple guides are found, ask which one to follow.
3. Read the entire guide before running any commands; do not infer missing steps.
4. Execute steps in order, using the exact commands and tooling specified (scripts, Makefile, CI tasks, etc.).
5. Follow the release guide exactly; if anything is unclear, stop and ask rather than making assumptions.
6. If a step fails, stop and either follow the guide's recovery instructions or ask for user direction.
7. If no `RELEASE_GUIDE.md` exists:
   - Ask the user for the correct release documentation location, OR
   - Propose using the fallback flow below (changelog-driven GitHub release) and wait for explicit confirmation.

## Output and clarification rules

- The response must include, in order:
  1. Release content (use the template provided in each project's release guide)
  2. Release link

## Fallback flow (when no RELEASE_GUIDE.md exists)

This fallback matches a common "CHANGELOG.md → GitHub Releases" workflow (confirm with the user before using):

1. Prereqs
   - Clean working tree: `git status -sb`
   - On the target branch (default: `main`)
   - GitHub CLI is authenticated: `gh auth status`
2. Decide the version and date
   - Version: `vX.Y.Z`
   - Date: `YYYY-MM-DD` (e.g. `date +%Y-%m-%d`)
3. Update `CHANGELOG.md`
   - Add a new entry at the top using the repo’s template (preferred), or `$CODEX_HOME/skills/workflows/release/release-workflow/template/RELEASE_TEMPLATE.md`
   - Keep section order; remove empty sections
   - Run `$CODEX_HOME/skills/workflows/release/release-workflow/scripts/audit-changelog.zsh --check` (skips when repo provides its own template; use `--no-skip-template` to force)
4. (Only when code changed) run the repo’s lint/test/build checks and record results
5. Commit the changelog
6. Create the GitHub release notes from the changelog section and publish the release with `gh release create`
7. Verify the release with `gh release view`

## Templates (fallback)

- `template/RELEASE_TEMPLATE.md`: Changelog entry / GitHub release notes template (copy into the project’s `CHANGELOG.md`).
- Path: `$CODEX_HOME/skills/workflows/release/release-workflow/template/RELEASE_TEMPLATE.md`

## Helper scripts (fallback)

These scripts are designed to run inside a target repo that uses `CHANGELOG.md` headings like `## vX.Y.Z - YYYY-MM-DD`.

- Scaffold a new entry from a template:
  - `$CODEX_HOME/skills/workflows/release/release-workflow/scripts/release-scaffold-entry.sh --version v1.3.2 --output "$CODEX_HOME/out/release-entry-v1.3.2.md"`
  - Uses repo-local `docs/templates/RELEASE_TEMPLATE.md` when present; otherwise falls back to this skill template.
- Audit basic prereqs + changelog format:
  - `$CODEX_HOME/skills/workflows/release/release-workflow/scripts/release-audit.sh --repo . --version v1.3.2 --branch main`
- Audit changelog formatting + placeholder cleanup (skips when repo provides its own template; use `--no-skip-template` to force):
  - `$CODEX_HOME/skills/workflows/release/release-workflow/scripts/audit-changelog.zsh --repo . --check`
- Extract release notes from `CHANGELOG.md` into a file for `gh release create -F`:
  - `$CODEX_HOME/skills/workflows/release/release-workflow/scripts/release-notes-from-changelog.sh --version v1.3.2 --output "$CODEX_HOME/out/release-notes-v1.3.2.md"`
