# codex-kit: Skills layout governance (v2)

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-24 | 2026-01-24 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/75
- Docs: `docs/plans/skills-layout-governance-plan.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- Define an enforceable “Skill Anatomy v2” for `skills/` (layout, sharing, scripts, tests, path rules).
- Provide a safe migration plan for existing skills (starting with `_projects` path issues).
- Add automated enforcement (audits + CI + tests) to prevent regressions.

## Acceptance Criteria

- Canonical spec exists: `docs/skills/SKILL_LAYOUT_V2.md` and is referenced from `README.md` and `skills/.system/skill-creator/SKILL.md`.
- Path enforcement exists: `scripts/audit-skill-paths.sh` runs in `scripts/check.sh --lint` and CI, and prints `error:` lines on violations.
- All tracked skills pass: `scripts/validate_skill_contracts.sh`, `scripts/audit-skill-layout.sh`, and `scripts/audit-skill-paths.sh`.
- Migration complete for the known broken class: `_projects/*` SKILL.md “Wrapper loaded: source …” paths point to existing `skills/_projects/<project>/scripts/*.zsh`.
- Full repo validation passes: `scripts/check.sh --all` and `scripts/test.sh` exit 0.

## Scope

- In-scope:
  - Directory conventions for each skill folder (what is allowed at the top-level, where templates live, where shared code lives).
  - Shared resources strategy for related skills (group-level `_libs/` for non-executable code, group-level `scripts/` for shared entrypoints).
  - `$CODEX_HOME/...` path conventions in SKILL.md (commands/snippets), plus an audit to prevent broken references.
  - Migration of existing skills that violate the new rules (start with `_projects` wrapper path fixes).
- Out-of-scope:
  - Changing skill semantics beyond docs/path correctness.
  - Introducing per-skill pytest suites inside each skill folder (keep tests centralized under repo `tests/`).
  - Large-scale re-homing of repo-level tooling out of `scripts/` (allowed later via thin wrappers).

## I/O Contract

### Input

- Existing skills and docs: `skills/**`, `docs/plans/skills-layout-governance-plan.md`, `docs/templates/PROGRESS_TEMPLATE.md`.
- Existing enforcement/tooling: `scripts/validate_skill_contracts.sh`, `scripts/audit-skill-layout.sh`, `scripts/check.sh`.
- Existing test harness: `scripts/test.sh`, `tests/`.

### Output

- Canonical spec: `docs/skills/SKILL_LAYOUT_V2.md`.
- Enforcement: `scripts/audit-skill-paths.sh` wired into `scripts/check.sh --lint` and CI.
- Migration changes: updated `skills/**/SKILL.md` (especially `_projects/*`) and any required shared folder skeletons (`*_libs/`).

### Intermediate Artifacts

- `docs/progress/20260124_skills-layout-governance-v2.md` (this file)
- `docs/plans/skills-layout-governance-plan.md`
- Test evidence: `out/tests/script-regression/summary.json`, `out/tests/script-smoke/summary.json`

## Design / Decisions

### Rationale

- Keep repo `scripts/` as stable entrypoints for CI and local tooling; if governance tooling moves under `skills/`, keep `scripts/*` as thin wrappers.
- Use group-level `_libs/` for shared, non-executable implementation code to avoid accidental execution via script regression tests.
- Require `$CODEX_HOME/...` for command snippets in SKILL.md so instructions are runnable from any working directory.
- Keep tests centralized under repo `tests/`; allow skill-local fixtures under `assets/testdata/` when needed.

### Risks / Uncertainties

- Risk: a SKILL.md path audit could flag illustrative examples and create false positives.
  - Mitigation: lint only `$CODEX_HOME/`-anchored paths in inline code / code blocks; allow explicit opt-out markers only when justified.
- Risk: shared code accidentally becomes executable entrypoints (placed under `skills/**/scripts/**` or includes a shebang).
  - Mitigation: enforce “no `scripts/` under `_libs/`” and “no shebang in `_libs`”; add regression coverage.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, use `- [ ] ~~like this~~` and include `Reason:`. Unchecked and unstruck items (e.g. `- [ ] foo`) will block close-progress-pr.

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Confirm Skill Anatomy v2 decisions (sharing strategy, `$CODEX_HOME` rules, test strategy).
    - [ ] Ensure plan + progress docs are executable (linted; no placeholder tokens).
  - Artifacts:
    - `docs/progress/20260124_skills-layout-governance-v2.md` (this file)
    - `docs/plans/skills-layout-governance-plan.md`
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned in this progress file.
    - [ ] Plan file passes: `scripts/plan/validate_plans.sh --file docs/plans/skills-layout-governance-plan.md`.
    - [ ] No placeholder tokens remain in progress docs: `rg -n \"\\[\\[.*\\]\\]\" docs/progress -S` returns no output.
    - [ ] Progress index format is valid: `skills/workflows/pr/progress/create-progress-pr/scripts/validate_progress_index.sh`.
- [ ] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [ ] Publish canonical spec doc (`docs/skills/SKILL_LAYOUT_V2.md`) and link it from `README.md` + `skill-creator`.
    - [ ] Implement `scripts/audit-skill-paths.sh` and wire it into `scripts/check.sh --lint` + CI.
    - [ ] Add fixtures/tests so the new audit fails on known-bad cases and passes on the repo.
  - Artifacts:
    - `docs/skills/SKILL_LAYOUT_V2.md`
    - `scripts/audit-skill-paths.sh`
    - `.github/workflows/lint.yml`
    - `tests/test_audit_scripts.py`
    - `tests/fixtures/`
  - Exit Criteria:
    - [ ] Lint pipeline passes: `scripts/check.sh --lint`.
    - [ ] New audit fails on a minimal fixture with a broken `$CODEX_HOME/...` path and reports `error:`.
    - [ ] Spec doc includes examples for tool/workflow/_projects skills and defines “MUST/SHOULD/MAY” rules.
- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Fix `_projects/*` SKILL.md wrapper paths and remove duplicated `$CODEX_HOME` segments.
    - [ ] Add group-level `_libs/` skeletons for sharing where appropriate (pattern after `skills/automation/_libs`).
    - [ ] (Optional) Add a governance skill and convert repo-level scripts into thin wrappers.
  - Artifacts:
    - `skills/_projects/*/*/SKILL.md`
    - `skills/workflows/_libs/README.md`
    - `skills/tools/_libs/README.md`
    - `skills/_projects/_libs/README.md`
    - `skills/tools/devex/skill-governance/` (optional)
  - Exit Criteria:
    - [ ] Skill docs for `_projects` can be followed literally without missing wrapper paths.
    - [ ] `_libs/` files are non-executable and contain no shebangs; no `_libs/**/scripts/` exists.
    - [ ] Governance wrappers (if added) match canonical `--help` output and exit codes.
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Run full repo checks/tests and capture evidence paths.
  - Artifacts:
    - `out/tests/script-regression/summary.json`
    - `out/tests/script-smoke/summary.json`
    - `out/tests/script-coverage/summary.md`
  - Exit Criteria:
    - [ ] Validation commands executed successfully: `scripts/check.sh --all` and `scripts/test.sh`.
    - [ ] Evidence exists under `out/tests/` (summaries + logs) and can be linked from PR(s) when needed.
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Merge implementation PRs and update this progress file Links/PRs.
    - [ ] Archive this progress file via `close-progress-pr` when DONE.
  - Artifacts:
    - `docs/progress/archived/20260124_skills-layout-governance-v2.md`
  - Exit Criteria:
    - [ ] Documentation completed and entry points updated (README / docs index links).
    - [ ] Cleanup completed (archive progress file when done; remove temporary fixtures/scripts if any).

## Modules

- `docs/plans/skills-layout-governance-plan.md`: detailed sprints/tasks for the migration and enforcement work.
- `scripts/audit-skill-layout.sh`: enforces allowed per-skill top-level directory structure.
- `scripts/validate_skill_contracts.sh`: enforces minimal `## Contract` structure in `skills/**/SKILL.md`.
- `scripts/audit-skill-paths.sh` (planned): enforces `$CODEX_HOME` path correctness inside SKILL.md.
