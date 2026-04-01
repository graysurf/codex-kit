---
name: release-workflow
description:
  Execute project release workflows by following a repo-provided release guide when present; otherwise use a changelog-driven fallback flow
  with helper scripts.
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
   - `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .`
   - If it exits `3`, stop and ask which guide to use.
3. Read the resolved guide file fully before running any commands.
4. Execute the guide steps in order, using the exact commands and tooling specified.
5. If anything is unclear or a step fails, stop and ask rather than making assumptions.

## Output and clarification rules

- Use `references/ASSISTANT_RESPONSE_TEMPLATE.md` when a release is published.
- Use `references/ASSISTANT_RESPONSE_TEMPLATE_BLOCKED.md` when blocked (audit/check fails or unclear step).
- If a release is published, the response must include, in order:
  1. Release content
  2. Release link
- If blocked (e.g. an audit/check step fails), the response must include:
  1. Failure summary (including audit output when applicable)
  2. A direct question asking how to proceed

## Fallback flow (when no guide exists)

The default fallback guide lives at:

- `$AGENT_HOME/skills/automation/release-workflow/references/DEFAULT_RELEASE_GUIDE.md`

## Entrypoints (fallback helper scripts)

- `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .`
- `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <vX.Y.Z>`
- Legacy wrapper paths are not supported; keep docs and callers pinned to these scripts.

## Helper scripts (fallback)

Use only these public entrypoints:

- Resolve the guide + template deterministically:
  - `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .`
- Publish GitHub release from changelog via single entrypoint (extract + audit + upstream-sync check/push + create/edit + verify body):

  ```bash
  $AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version v1.3.2 --push-current-branch
  ```

## Migration notes (removed entrypoints)

The release-workflow surface was simplified in PR #221.
The following entrypoints are deprecated and removed; migrate to the retained commands below.

| Removed entrypoint | Replace with |
| --- | --- |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-audit.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-find-guide.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .` |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-scaffold-entry.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` |

`release-resolve.sh` remains the guide-resolution entrypoint.
`release-publish-from-changelog.sh` remains the publish entrypoint.

## Related docs

- Reference notes for the single-entrypoint simplification shipped in PR #221:
  - `docs/plans/pr-221-reference-notes.md`
- Repo-wide script simplification playbook:
  - `docs/runbooks/skills/SCRIPT_SIMPLIFICATION_PLAYBOOK.md`
