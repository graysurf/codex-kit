# codex-kit: Skills structure reorg v2

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-24 | 2026-01-24 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/80
- Docs: [docs/plans/skills-structure-reorg-plan.md](../../plans/skills-structure-reorg-plan.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Addendum

- 2026-01-24: Merged implementation PRs (#81–#84) and archived this progress file.

## Goal

- Define and enforce a v2 `skills/` anatomy (shared `_shared/`, per-skill `tests/`, and executable path rules).
- Consolidate skill-related tooling under canonical `skills/**/scripts/` locations.

## Acceptance Criteria

- Tracked skills follow v2 layout rules and pass audits:
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Plan tooling and E2E driver have canonical entrypoints under `skills/`:
  - Plan tooling:
    - `$CODEX_COMMANDS_PATH/plan-tooling validate`
    - `$CODEX_COMMANDS_PATH/plan-tooling to-json`
    - `$CODEX_COMMANDS_PATH/plan-tooling batches`
  - Progress workflow E2E driver:
    - `$AGENTS_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
- `SKILL.md` runnable executable references use `$AGENTS_HOME/...` (no CWD-dependent `scripts/...` instructions).
- Full repo checks pass: `$AGENTS_HOME/scripts/check.sh --all`.

## Scope

- In-scope:
  - Tracked skills under `skills/workflows/`, `skills/tools/`, and `skills/automation/`.
- Shared layout rules and folders:
    - Category shared: `skills/<category>/<area>/_shared/`
    - Global shared: `skills/_shared/`
  - Canonical script entrypoints under `skills/`:
    - `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
    - `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
    - `commands/plan-tooling`
    - `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
  - Per-skill tests: add `tests/` for every tracked skill and enforce via audits + CI.
- Out-of-scope:
  - Local-only skills under `skills/_projects/` (ignored by git) and generated skills under `skills/.system/` (ignored by git).
  - Functional redesign of skills beyond path/reference/validation updates (except when required for safety).

## I/O Contract

### Input

- Existing tracked skills and tooling under:
  - `skills/**/`
  - `scripts/`
  - `tests/`
  - `docs/`

### Output

- Canonical skill tooling under `skills/**/scripts/`.
- Enforced v2 skill layout rules (including per-skill tests) via repo checks and CI.

### Intermediate Artifacts

- `docs/progress/archived/20260124_skills-structure-reorg-v2.md` (this file)
- `docs/plans/skills-structure-reorg-plan.md`
- PR split spec (TSV) used by worktree tooling (committed or embedded in PR bodies).

## Design / Decisions

### Rationale

- Reduce ambiguity and drift when adding skills by enforcing a single directory anatomy.
- Improve portability by ensuring runnable instructions use `$AGENTS_HOME/...` absolute paths.

### Risks / Uncertainties

- Risk: shared code placed under `skills/**/scripts/` becomes “entrypoint surface area” unintentionally.
  - Mitigation: forbid `_shared/scripts/` and keep shared code under `_shared/lib/` or `_shared/python/`.
- Risk: Python import paths for `skills/**/tests/` become brittle.
  - Mitigation: define a stable import strategy (package init + tests) and validate in CI.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, use `- [ ] ~~like this~~` and include `Reason:`. Unchecked and unstruck items (e.g. `- [ ] foo`) will block close-progress-pr.

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm v2 anatomy rules + enforcement scope (tracked skills only).
    - [x] Decide PR split (stacked) and subagent assignments.
  - Artifacts:
    - `docs/progress/archived/20260124_skills-structure-reorg-v2.md` (this file)
    - `docs/plans/skills-structure-reorg-plan.md`
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: see Goals/Scope/Acceptance Criteria above.
    - [x] Risks and rollback plan are defined: see Risks/Rollback in `docs/plans/skills-structure-reorg-plan.md`.
    - [x] Minimal verification commands are defined:
      - `$AGENTS_HOME/scripts/check.sh --all`
      - `$AGENTS_HOME/scripts/test.sh -m script_smoke`
      - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- [x] Step 1: MVP (governance + docs baseline)
  - Work Items:
    - [x] Create/land the planning docs (this progress file + plan file) and open the planning PR.
    - [x] Add governance skill and audits.
  - Artifacts:
    - `docs/progress/archived/20260124_skills-structure-reorg-v2.md`
    - `docs/plans/skills-structure-reorg-plan.md`
  - Exit Criteria:
    - [x] Planning PR is merged and Progress link is patched to `blob/main/...`.
    - [x] Repo checks still pass after baseline changes:
      - `$AGENTS_HOME/scripts/check.sh --contracts --skills-layout`
- [x] Step 2: Expansion / integration (migrations + tests)
  - Work Items:
    - [x] Migrate plan tooling and progress E2E driver into `skills/`.
    - [x] Add per-skill tests for all tracked skills; enforce via audit + CI.
  - Artifacts:
    - `commands/plan-tooling`
    - `skills/workflows/pr/progress/progress-pr-workflow-e2e/`
    - `skills/**/tests/`
  - Exit Criteria:
    - [x] Canonical entrypoints are the only supported executable paths.
    - [x] `scripts/check.sh --all` passes.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run full repo checks and record evidence paths under `out/`.
  - Artifacts:
    - `out/tests/`
  - Exit Criteria:
    - [x] Validation commands executed successfully:
      - `$AGENTS_HOME/scripts/check.sh --all`
      - `$AGENTS_HOME/scripts/test.sh`
    - [x] Evidence captured under `out/tests/` (summary + script coverage reports).
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Merge implementation PRs (stacked), retargeting bases as needed.
    - [x] Archive this progress file under `docs/progress/archived/`.
  - Artifacts:
    - PR links (planning + implementation)
    - `docs/progress/archived/20260124_skills-structure-reorg-v2.md`
  - Exit Criteria:
    - [x] Documentation entry points updated (README / docs index links).
    - [x] Cleanup completed (set status to DONE; archive progress file).

## Modules

- Planning PR: https://github.com/graysurf/codex-kit/pull/80
- Implementation PRs:
  - https://github.com/graysurf/codex-kit/pull/81
  - https://github.com/graysurf/codex-kit/pull/82
  - https://github.com/graysurf/codex-kit/pull/83
  - https://github.com/graysurf/codex-kit/pull/84
- `docs/plans/skills-structure-reorg-plan.md`: sprinted implementation plan (authoritative task breakdown).
- `skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh`: progress file scaffold.
- `skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh`: merge planning PR + patch Progress link.
- `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh`: create stacked worktrees from a TSV spec.
