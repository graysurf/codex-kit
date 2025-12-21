---
name: release-workflow
description: Execute project release workflows by locating and following project-specific RELEASE_GUIDE.md in the repository root or docs/. Use when asked to perform a release, publish a release, cut a tag, run release steps, or when a user references RELEASE_GUIDE.md.
---

# Release Workflow

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

## Output

The response must include, in order:

1. This release's content (output using the template provided in each project's release guide)
2. Release link
