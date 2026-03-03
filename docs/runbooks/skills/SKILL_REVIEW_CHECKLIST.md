# Skill Review Checklist

## Purpose

Use this checklist to review any tracked skill against the repo's contract, layout, and entrypoint rules.
Every checklist item maps to a deterministic repo command so reviewers can verify findings without judgment calls.
This checklist applies to existing skills, newly created skills, and refactors that remove or merge entrypoints.

## Review Steps

1. Confirm the target is a tracked skill under `skills/workflows/`, `skills/tools/`, or `skills/automation/`.
2. Run the contract validator for the full repo or the target file.
3. Run the layout audit for the full repo or the target directory.
4. Run entrypoint ownership checks when scripts are added, removed, or renamed.
5. Run smoke or regression coverage checks when script specs or public entrypoints change.
6. Verify supporting docs still match the maintained entrypoint surface.

## Deterministic Checklist

| Rule | Why it matters | Command-backed check |
| --- | --- | --- |
| `SKILL.md` exists and `## Contract` is the first H2 after the H1 title. | Keeps every skill contract machine-checkable. | `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file <skill>/SKILL.md` |
| Contract headings are present and in canonical order: `Prereqs`, `Inputs`, `Outputs`, `Exit codes`, `Failure modes`. | Prevents drift in required contract fields. | `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file <skill>/SKILL.md` |
| Top-level layout contains only allowed entries (`SKILL.md`, `scripts/`, `bin/`, `references/`, `assets/`, `tests/`). | Stops hidden structure drift and undocumented executables. | `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir <skill-dir>` |
| Tracked skills always include `tests/`. | Maintains minimum regression coverage for every skill. | `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir <skill-dir>` |
| Template markdown lives only under `references/` or `assets/templates/`. | Keeps executable and reusable docs separated. | `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir <skill-dir>` |
| Every maintained script under `skills/**/scripts/` is owned by a skill test via `assert_entrypoints_exist(...)` or an explicit reviewed exclusion. | Prevents orphaned public entrypoints. | `scripts/check.sh --entrypoint-ownership` |
| If a script is expected to participate in smoke coverage, its `tests/script_specs/...json` file stays in sync with the current entrypoint path. | Prevents stale smoke fixtures after script changes. | `bash scripts/ci/stale-skill-scripts-audit.sh --check` |
| Skill docs reference only maintained entrypoints and current supporting docs. | Avoids contract/docs mismatch after simplification. | `scripts/check.sh --docs` and targeted `rg -n '\$AGENT_HOME/.*/scripts/' <skill-dir> docs/runbooks/skills skills/README.md` |
| Repo-wide contract/layout checks remain green after a skill change. | Ensures changes do not break unrelated tracked skills. | `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh && skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh` |

## Change-Type Matrix

| Change type | Required checks |
| --- | --- |
| Contract wording only | `validate_skill_contracts.sh --file <skill>/SKILL.md` |
| Add or remove non-template files under the skill directory | `audit-skill-layout.sh --skill-dir <skill-dir>` |
| Add, remove, or rename a script entrypoint | `scripts/check.sh --entrypoint-ownership` and `bash scripts/ci/stale-skill-scripts-audit.sh --check` |
| Update repo-facing skill docs or runbooks | `scripts/check.sh --docs` |
| Large skill-management or multi-skill refactor | `scripts/check.sh --contracts --skills-layout --entrypoint-ownership` plus `bash scripts/ci/stale-skill-scripts-audit.sh --check` |

## Reviewer Notes

- `create-skill` is the baseline scaffold contract, but this checklist is intentionally broader than scaffolding.
- A passing checklist does not decide whether a script should stay public; that decision belongs in the simplification playbook.
- When a skill removes or merges an entrypoint, update script specs, tests, and supporting docs in the same change.
