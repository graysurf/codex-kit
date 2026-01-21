# codex-kit: Skills layout normalization and audit

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-17 | 2026-01-17 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/56
- Docs: [README.md](../../../README.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Addendum

- 2026-01-17: Clarify template placement: Markdown files with `TEMPLATE` in the filename belong in `references/` (writing skeletons) or `assets/templates/` (file scaffolds), enforced by `$CODEX_HOME/scripts/audit-skill-layout.sh`.

## Goal

- Normalize skill directory layouts to the Codex-recommended anatomy: `SKILL.md` + optional `scripts/`, `references/`, `assets/`.
- Remove the ad-hoc `template/` convention by migrating scaffolds/templates into `assets/`, updating all references, and enforcing the layout via CI.

## Acceptance Criteria

- No tracked skills contain a top-level `template/` directory; scaffolds/templates live under `assets/`.
- Skill layout enforcement exists and passes in CI: `$CODEX_HOME/scripts/audit-skill-layout.sh`.
- Repo references are updated (skills/docs/tests/workflows), and validation passes:
  - `$CODEX_HOME/scripts/lint.sh`
  - `$CODEX_HOME/scripts/test.sh`
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/audit_progress_addendum.sh --check-updated`

## Scope

- In-scope:
  - Migrate `skills/**/template/` to `skills/**/assets/` (scaffold + templates) and update all references.
  - Add a repo-level audit for tracked skill directory layout and wire it into CI.
  - Update affected archived progress docs with an Addendum describing the path migration.
- Out-of-scope:
  - Changing skill runtime behavior beyond path / reference updates.
  - Rewriting historical progress content outside `## Addendum` and specific stale path references.

## I/O Contract

### Input

- Tracked skill folders under `skills/**/`.
- CI workflows under `.github/workflows/`.

### Output

- Standardized skill directory layout under `skills/**/`.
- CI-enforced layout audit: `$CODEX_HOME/scripts/audit-skill-layout.sh`.

### Intermediate Artifacts

- `docs/progress/20260117_skills-layout-normalization-and-audit.md` (this file)
- Updated archived progress Addendums under `docs/progress/archived/*.md`

## Design / Decisions

### Rationale

- Align with Codex skill directory conventions to reduce ambiguity (where to put templates/guides) and keep repo-wide search results consistent.
- Enforce the layout mechanically to prevent future drift and “template vs assets” inconsistency.

### Risks / Uncertainties

- Risk: broken docs/CI/scripts due to stale `template/` path references.
  - Mitigation: update all tracked references and add CI coverage (`$CODEX_HOME/scripts/audit-skill-layout.sh` + existing smoke tests).
- Risk: edits to archived progress files could be seen as rewriting history.
  - Mitigation: restrict changes to path fixes + `## Addendum` entries documenting the change and linking back to this progress file.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, close-progress-pr will auto-wrap the item text with Markdown strikethrough (use `- [ ] ~~like this~~`).

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Decide and document the canonical skill directory layout.
    - [x] Inventory non-conforming skills and define the `template/` -> `assets/` mapping.
  - Artifacts:
    - `docs/progress/20260117_skills-layout-normalization-and-audit.md` (this file)
    - `$CODEX_HOME/scripts/audit-skill-layout.sh`
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: this document is complete.
    - [x] Data flow and I/O contract are defined: this document is complete.
    - [x] Risks and rollback plan are defined: revert path moves and re-run audit + tests.
    - [x] Minimal verification commands are defined:
      - `$CODEX_HOME/scripts/audit-skill-layout.sh`
      - `$CODEX_HOME/scripts/lint.sh`
      - `$CODEX_HOME/scripts/test.sh`
- [x] Step 1: Implementation (skill layout + path migration)
  - Work Items:
    - [x] Migrate `template/` to `assets/` for affected skills and update references.
    - [x] Update scripts/tests/workflows that depended on the old paths.
  - Artifacts:
    - `skills/tools/testing/api-test-runner/assets/scaffold/setup/`
    - `skills/tools/testing/graphql-api-testing/assets/scaffold/setup/`
    - `skills/tools/testing/rest-api-testing/assets/scaffold/setup/`
    - `skills/automation/release-workflow/assets/templates/RELEASE_TEMPLATE.md`
    - `skills/automation/release-workflow/references/DEFAULT_RELEASE_GUIDE.md`
  - Exit Criteria:
    - [x] No stale references remain: `rg -n "template/" .` returns no output.
    - [x] Skill layout audit passes: `$CODEX_HOME/scripts/audit-skill-layout.sh`.
    - [x] Usage docs reflect the new paths (skills + guides + workflow snippets).
- [x] Step 2: Documentation updates (including archived Addendums)
  - Work Items:
    - [x] Update archived progress files that referenced the old scaffold paths.
    - [x] Add `## Addendum` entries explaining the change and linking to the updated paths.
  - Artifacts:
    - `docs/progress/archived/20260107_graphql-api-testing.md`
    - `docs/progress/archived/20260108_graphql-api-testing-command-history.md`
    - `docs/progress/archived/20260108_rest-api-testing-skill.md`
    - `docs/progress/archived/20260109_ci-api-test-runner.md`
    - `docs/progress/archived/20260110_api-test-runner-gh-secrets-auth.md`
    - `docs/progress/archived/20260110_api-test-summary-gh-actions.md`
    - `docs/progress/archived/20260116_env-bool-flags.md`
  - Exit Criteria:
    - [x] Addendum placement/updated dates are valid:
      - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/audit_progress_addendum.sh --check-updated`
    - [x] `docs/progress/README.md` index entry exists for this progress file.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run repo lint and tests.
  - Artifacts:
    - `out/tests/script-coverage/summary.md` (generated by `$CODEX_HOME/scripts/test.sh`)
  - Exit Criteria:
    - [x] Validation commands executed successfully:
      - `$CODEX_HOME/scripts/lint.sh`
      - `$CODEX_HOME/scripts/test.sh`
- [x] Step 4: PR / wrap-up
  - Work Items:
    - [x] Open PR and get review.
    - [x] After merge: run `close-progress-pr` to archive this progress file (optional but preferred).
  - Artifacts:
    - PR: https://github.com/graysurf/codex-kit/pull/56
  - Exit Criteria:
    - [x] PR is merged and CI is green.
    - [x] Progress file is archived under `docs/progress/archived/` and index is updated.

## Modules

- `$CODEX_HOME/scripts/audit-skill-layout.sh`: Enforces tracked skill directory layout (`SKILL.md` + optional `scripts/`, `references/`, `assets/`).
- `.github/workflows/lint.yml`: Runs the skill layout audit in CI.
- `$CODEX_HOME/skills/automation/release-workflow/scripts/release-resolve.sh`: Resolves default guide/template from the normalized locations.
- `skills/tools/testing/api-test-runner/assets/scaffold/setup/`: Bootstrap suite scaffold for `setup/api|rest|graphql`.
