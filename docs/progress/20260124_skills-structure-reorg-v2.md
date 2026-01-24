# codex-kit: Skills structure reorg v2

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-24 | 2026-01-24 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/80
- Docs: [docs/plans/skills-structure-reorg-plan.md](../plans/skills-structure-reorg-plan.md)
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- Define and enforce a v2 `skills/` anatomy (shared `_shared/`, per-skill `tests/`, and executable path rules).
- Migrate skill-related tooling out of repo-root `scripts/` into canonical `skills/**/scripts/` locations while keeping backwards-compatible wrappers.

## Acceptance Criteria

- Tracked skills follow v2 layout rules and pass audits:
  - `$CODEX_HOME/scripts/audit-skill-layout.sh`
  - `$CODEX_HOME/scripts/validate_skill_contracts.sh`
- Plan tooling and E2E driver have canonical entrypoints under `skills/` and legacy wrappers remain functional:
  - Plan tooling: `validate_plans`, `plan_to_json`, `plan_batches`
  - Progress workflow E2E driver: `progress_pr_workflow.sh`
- `SKILL.md` runnable executable references use `$CODEX_HOME/...` (no CWD-dependent `scripts/...` instructions).
- Full repo checks pass: `$CODEX_HOME/scripts/check.sh --all`.

## Scope

- In-scope:
  - Tracked skills under `skills/workflows/`, `skills/tools/`, and `skills/automation/`.
  - Shared layout rules and folders:
    - Category shared: `skills/<category>/<area>/_shared/`
    - Global shared: `skills/_shared/`
  - Script migrations (canonical under `skills/`, keep wrappers under `scripts/`):
    - `scripts/validate_plans.sh`, `scripts/plan_to_json.sh`, `scripts/plan_batches.sh`
    - `scripts/e2e/progress_pr_workflow.sh`
    - `scripts/audit-skill-layout.sh`, `scripts/validate_skill_contracts.sh`
  - Per-skill tests: add `tests/` for every tracked skill and enforce via audits + CI.
- Out-of-scope:
  - Local-only skills under `skills/_projects/` (ignored by git) and generated skills under `skills/.system/` (ignored by git).
  - Functional redesign of skills beyond path/reference/validation updates (except when required for safety/compat).

## I/O Contract

### Input

- Existing tracked skills and tooling under:
  - `skills/**/`
  - `scripts/`
  - `tests/`
  - `docs/`

### Output

- Canonical skill tooling under `skills/**/scripts/`, with legacy wrappers preserved under `scripts/`.
- Enforced v2 skill layout rules (including per-skill tests) via repo checks and CI.

### Intermediate Artifacts

- `docs/progress/20260124_skills-structure-reorg-v2.md` (this file)
- `docs/plans/skills-structure-reorg-plan.md`
- PR split spec (TSV) used by worktree tooling (committed or embedded in PR bodies).

## Design / Decisions

### Rationale

- Reduce ambiguity and drift when adding skills by enforcing a single directory anatomy.
- Improve portability by ensuring runnable instructions use `$CODEX_HOME/...` absolute paths.
- Keep changes safe by preserving backwards-compatible wrappers and avoiding sudden breakage.

### Risks / Uncertainties

- Risk: shared code placed under `skills/**/scripts/` becomes “entrypoint surface area” unintentionally.
  - Mitigation: forbid `_shared/scripts/` and keep shared code under `_shared/lib/` or `_shared/python/`.
- Risk: Python import paths for `skills/**/tests/` become brittle.
  - Mitigation: define a stable import strategy (package init + tests) and validate in CI.
- Risk: wrapper drift (two competing implementations).
  - Mitigation: wrappers must be thin and delegate to canonical scripts.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, use `- [ ] ~~like this~~` and include `Reason:`. Unchecked and unstruck items (e.g. `- [ ] foo`) will block close-progress-pr.

 - [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Confirm v2 anatomy rules + enforcement scope (tracked skills only).
    - [ ] Decide PR split (stacked) and subagent assignments.
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - `docs/plans/skills-structure-reorg-plan.md`
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned: see Goals/Scope/Acceptance Criteria above.
    - [ ] Risks and rollback plan are defined: see Risks/Rollback in `docs/plans/skills-structure-reorg-plan.md`.
    - [ ] Minimal verification commands are defined:
      - `$CODEX_HOME/scripts/check.sh --all`
      - `$CODEX_HOME/scripts/test.sh -m script_smoke`
      - `$CODEX_HOME/scripts/audit-skill-layout.sh`
- [ ] Step 1: MVP (governance + docs baseline)
  - Work Items:
    - [ ] Create/land the planning docs (this progress file + plan file) and open the planning PR.
    - [ ] Add governance skill skeleton + wrappers (no breaking changes).
  - Artifacts:
    - `docs/progress/20260124_skills-structure-reorg-v2.md`
    - `docs/plans/skills-structure-reorg-plan.md`
  - Exit Criteria:
    - [ ] Planning PR is merged and Progress link is patched to `blob/main/...`.
    - [ ] Repo checks still pass after baseline changes:
      - `$CODEX_HOME/scripts/check.sh --contracts --skills-layout`
- [ ] Step 2: Expansion / integration (migrations + tests)
  - Work Items:
    - [ ] Migrate plan tooling and progress E2E driver into `skills/` with wrappers preserved.
    - [ ] Add per-skill tests for all tracked skills; enforce via audit + CI.
  - Artifacts:
    - `skills/workflows/plan/plan-tooling/`
    - `skills/workflows/pr/progress/progress-pr-workflow-e2e/`
    - `skills/**/tests/`
  - Exit Criteria:
    - [ ] Legacy entrypoints remain functional (wrappers delegate correctly).
    - [ ] `scripts/check.sh --all` passes.
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Run full repo checks and record evidence paths under `out/`.
  - Artifacts:
    - `out/tests/`
  - Exit Criteria:
    - [ ] Validation commands executed successfully:
      - `$CODEX_HOME/scripts/check.sh --all`
      - `$CODEX_HOME/scripts/test.sh`
    - [ ] Evidence captured under `out/tests/` (summary + script coverage reports).
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Merge implementation PRs (stacked), retargeting bases as needed.
    - [ ] Run `close-progress-pr` to archive this progress file (preferred).
  - Artifacts:
    - PR links (planning + implementation)
    - `docs/progress/archived/20260124_skills-structure-reorg-v2.md`
  - Exit Criteria:
    - [ ] Documentation entry points updated (README / docs index links).
    - [ ] Cleanup completed (remove temporary flags/files; set status to DONE; archive progress file).

## Modules

- `docs/plans/skills-structure-reorg-plan.md`: sprinted implementation plan (authoritative task breakdown).
- `skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh`: progress file scaffold.
- `skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh`: merge planning PR + patch Progress link.
- `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh`: create stacked worktrees from a TSV spec.
