---
name: release-workflow
description: Execute project release workflows by locating and following project-specific RELEASE_GUIDE.md in the repository root or docs/. Use when asked to perform a release, publish a release, cut a tag, run release steps, or when a user references RELEASE_GUIDE.md.
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

Exit codes:

- N/A (workflow driver; stop and ask on unclear steps)

Failure modes:

- `RELEASE_GUIDE.md` missing or multiple guides found (must ask which to use).
- A guide step fails or is unclear (must stop and follow recovery instructions or ask).

## Setup

- Load commands with `source $CODEX_HOME/scripts/codex-tools.sh`

## Workflow

1. Identify the target repository root; ask if the repo path is unclear.
2. Locate `RELEASE_GUIDE.md` in the repo root or `docs/`:
   - Prefer `rg --files -g 'RELEASE_GUIDE.md'` from the repo root.
   - If multiple guides are found, ask which one to follow.
3. Read the entire guide before running any commands; do not infer missing steps.
4. Execute steps in order, using the exact commands and tooling specified (scripts, Makefile, CI tasks, etc.).
5. Follow the release guide exactly; if anything is unclear, stop and ask rather than making assumptions.
6. If a step fails, stop and either follow the guide's recovery instructions or ask for user direction.
7. If no `RELEASE_GUIDE.md` exists, ask the user for the correct release documentation location.

## Output and clarification rules

- The response must include, in order:
  1. Release content (use the template provided in each project's release guide)
  2. Release link
