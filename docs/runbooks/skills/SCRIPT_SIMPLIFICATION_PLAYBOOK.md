# Script Simplification Playbook

## Goal

Use this playbook when simplifying a tracked skill's script surface.
The target outcome is a smaller, clearer public entrypoint set without leaving orphaned tests, smoke specs, or migration ambiguity behind.
This playbook is based on the release-workflow simplification shipped in PR #221.

## Decision Rules

| Signal | Decision |
| --- | --- |
| The script exposes the primary stable workflow users should call directly. | `keep` |
| Multiple public scripts split one logical workflow and can be folded into a single supported command without hiding required behavior. | `merge` |
| The script is a thin wrapper, a superseded helper, or a public alias that no longer needs to exist after consolidation. | `remove` |
| The script remains necessary only for an internal helper role and should not stay public. | move helper logic out of `scripts/` into `lib/` or `_shared/`, then `remove` the public entrypoint |

## Required Decision Record

Record every changed script with these exact fields before or during implementation:

| Field | Requirement |
| --- | --- |
| `old entrypoint` | Current public script path before the change |
| `decision` | `keep`, `merge`, or `remove` |
| `new entrypoint` | Final supported public path after the change |
| `test/spec updates` | Exact tests, smoke specs, and fixtures added, removed, or rewritten |
| `migration note` | Caller impact and old-to-new command mapping |

## Execution Rules

1. Keep one primary entrypoint whenever the skill can present one stable public workflow.
2. Merge only when the resulting command contract is clearer than the current split surface.
3. Remove a public script only after updating every coupled test, smoke spec, fixture, and docs reference.
4. Update `SKILL.md` in the same change as the script decision.
5. If the change is breaking for callers, add an explicit migration note in the skill docs or release notes.

## Coupled Update Requirements

When a script decision changes the public surface, update all applicable items in the same PR:

- `SKILL.md` contract and usage examples
- any fallback or reference guide under `references/`
- per-skill tests under `<skill>/tests/`
- smoke specs under `tests/script_specs/...`
- smoke/regression tests under `tests/`
- fixtures used by smoke/regression tests
- runbooks or inventories that describe the skill surface

## Post-Change Validation Matrix

| Area | Required validation |
| --- | --- |
| contract | `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh` |
| layout | `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh` |
| docs parity | `scripts/check.sh --docs` |
| entrypoint ownership | `scripts/check.sh --entrypoint-ownership` |
| smoke/spec freshness | `bash scripts/ci/stale-skill-scripts-audit.sh --check` |
| targeted regression | run the skill-specific test module(s) and any dedicated smoke test file touching the changed entrypoint |

## PR #221 Example

`release-workflow` used these simplification choices:

- `old entrypoint`: `audit-changelog.zsh`, `release-audit.sh`, `release-find-guide.sh`, `release-notes-from-changelog.sh`, `release-scaffold-entry.sh`
- `decision`: merge publish behavior into `release-publish-from-changelog.sh`, remove the rest from the public surface
- `new entrypoint`: `skills/automation/release-workflow/scripts/release-publish-from-changelog.sh`
- `test/spec updates`: keep contract and smoke coverage aligned with the new public entrypoint set; remove stale specs for retired scripts
- `migration note`: callers of retired release scripts must switch to `release-publish-from-changelog.sh`

## Anti-Patterns

- Leaving a removed script referenced in `SKILL.md`, runbooks, or smoke specs.
- Keeping thin compatibility wrappers in `scripts/` without a documented reason.
- Removing a script without updating the matching smoke fixtures.
- Treating helper scripts as public API when they should move to `lib/` or `_shared/`.
