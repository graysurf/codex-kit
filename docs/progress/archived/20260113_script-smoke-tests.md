# codex-kit: Script smoke tests expansion

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-13 | 2026-01-14 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/22
- Planning PR: https://github.com/graysurf/codex-kit/pull/21
- Docs: [docs/testing/script-regression.md](../../testing/script-regression.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Goal

- Expand script validation from "entrypoint regression" (`--help`) into a tiered smoke framework that exercises real code paths.
- Make smoke coverage scalable: inventory every tracked script entrypoint, choose the right harness (spec vs pytest fixture), and incrementally raise coverage without flakiness or destructive side effects.

## Acceptance Criteria

- Every tracked script entrypoint has an explicit test plan status: `help-only`, `spec-smoke`, or `pytest-fixture` (with a documented reason for the choice).
- A new smoke suite runs in CI (in addition to existing `script_regression`) and produces traceable evidence under `out/tests/`.
- Smoke suites remain hermetic by default (no real network; no real DB; no mutations to the real repo state).

## Scope

- In-scope:
  - Define a tiered "script smoke" strategy and a repeatable harness for running it (spec-driven where possible, pytest fixtures where needed).
  - Add fixtures + stubs to enable deterministic happy-path runs (e.g. temporary git repos, stubbed DB clients, stubbed network tools).
  - Produce and maintain a script inventory with a per-script smoke plan (tracked in this progress file initially).
- Out-of-scope:
  - End-to-end tests that require real external services (real network, real databases, real cloud credentials).
  - Large refactors to existing scripts unless required to make them testable (those become separate follow-up PRs).

## I/O Contract

### Input

- Script entrypoints: tracked files under `scripts/**` and `skills/**/scripts/**`.
- Existing regression specs: `tests/script_specs/**/*.json`.
- New smoke inputs:
  - `tests/script_specs/**/*.json` smoke cases (in addition to regression `--help`).
  - `tests/fixtures/**` (fixture repos/files used by pytest-driven smoke cases).
  - `tests/stubs/bin/**` (stub commands for hermetic execution).

### Output

- Evidence under `out/tests/`:
  - Existing: `out/tests/script-regression/**`
  - Existing: `out/tests/script-smoke/**` (logs + summary JSON)

### Intermediate Artifacts

- `out/tests/**/logs/<script>.stdout.txt` and `out/tests/**/logs/<script>.stderr.txt`
- `out/tests/**/summary.json`

## Design / Decisions

### Rationale

- Keep `script_regression` (default `--help`) as a fast, broad guardrail for all entrypoints.
- Add a separate smoke layer for "does it actually work" paths using deterministic fixtures and stubs (avoid touching the real repo state).
- Prefer spec-driven smoke when a script can be exercised safely in-place; fall back to pytest fixtures when setup/teardown is required (e.g. temporary git repos, mutable working trees).

### Selected Defaults

- Smoke specs live in `tests/script_specs/**` (schema extended for smoke cases), rather than a new `tests/script_smoke_specs/**` tree.
- Any git-mutating scripts run only inside isolated temporary git repos (pytest fixtures); never in the real repo working tree.
- CI contract (no nightly):
  - Keep a single `script_smoke` marker for now.
  - Consider splitting `script_smoke_quick` / `script_smoke_full` later if runtime grows.

### Risks / Uncertainties

- Runtime + maintenance cost: 42 scripts today, likely more over time; adding smoke coverage everywhere can bloat CI. Mitigation: tiering + timeouts + explicit allowlist progression.
- Flakiness from environment coupling (PATH tools, OS differences, network). Mitigation: hermetic env (`tests/stubs/bin`, `HOME/XDG_*` redirection) + fixture repos + "dry-run" modes.
- Some scripts may be inherently interactive or destructive (git history mutation, database connections). Mitigation: run those only in isolated temporary repos or keep them `help-only` with a documented reason.
- CI contract split (quick vs full): quick on feature pushes may miss slower paths until PR/main. Mitigation: keep quick meaningful (not just `--help`) and keep full within CI timeouts.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Alignment and inventory
  - Work Items:
    - [x] Confirm smoke tier definitions and CI contract (what runs by default vs optional).
    - [x] Generate the script inventory and classify each entrypoint (`help-only` / `spec-smoke` / `pytest-fixture`).
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - Script inventory table (see "Script Inventory" below)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: decisions recorded in this progress file.
    - [x] Data flow and I/O contract are defined: inputs/outputs/artifacts recorded above.
    - [x] Risks and mitigations are defined: risks recorded above.
    - [x] Verification commands are defined: `$CODEX_HOME/scripts/test.sh -m script_regression` and `$CODEX_HOME/scripts/test.sh -m script_smoke`.
- [x] Step 1: Minimum viable smoke suite
  - Work Items:
    - [x] Add a new pytest marker for smoke (e.g. `script_smoke`) and a harness that can run "smoke cases".
    - [x] Extend the existing `tests/script_specs/**` JSON schema to support smoke cases (and implement loading logic).
    - [x] Add initial fixtures/stubs and smoke coverage for a small starter set (5–8 scripts).
  - Artifacts:
    - `tests/test_script_smoke.py`
    - `tests/script_specs/**` (smoke cases)
    - `tests/fixtures/**`
    - `docs/testing/script-smoke.md`
  - Exit Criteria:
    - [x] At least one happy path runs end-to-end: `$CODEX_HOME/scripts/test.sh -m script_smoke` (pass).
    - [x] Primary outputs are verifiable: `out/tests/script-smoke/summary.json` + per-script logs.
    - [x] Usage docs skeleton exists: `docs/testing/script-smoke.md` includes TL;DR + spec format.
- [x] Step 2: Expand smoke coverage across scripts
  - Work Items:
    - [x] Split Step 2 into multiple implementation PRs; scopes recorded in "Step 2 PR Plan".
    - [x] Add smoke coverage for remaining scripts, guided by the inventory table (spec-smoke first; defer pytest fixtures).
    - [x] Extend `tests/stubs/bin` to cover required external tools (e.g. `psql`, `mysql`, `sqlcmd`).
    - [x] Add negative tests for "placeholder left behind" failure modes where relevant.
  - Artifacts:
    - `tests/script_specs/**` (smoke cases expanded)
    - `tests/fixtures/**` (expanded)
    - `tests/stubs/bin/**` (expanded)
  - Exit Criteria:
    - [x] Common branches are covered per script: missing args, invalid env, dry-run, error codes (as applicable).
    - [x] Compatible with existing conventions: no dataflow breakage in CI or local workflows.
    - [x] Documentation exists for smoke authoring: spec schema + fixture conventions + stub guidelines.
  - Evidence:
    - Step 2 PRs #23-#34 merged (see "Step 2 PR Plan" + PR history).
    - Local `$CODEX_HOME/scripts/test.sh -m script_smoke` runs recorded in PR Testing sections.
- [x] Step 3: CI validation and evidence
  - Work Items:
    - [x] Ensure CI runs smoke tests by default and fails on regressions.
    - [x] Track runtime and tune timeouts/spec selection to keep CI fast and stable.
  - Artifacts:
    - CI logs (GitHub Actions)
    - `out/tests/script-smoke/**` evidence (local)
  - Exit Criteria:
    - [x] Validation commands executed with results recorded: `$CODEX_HOME/scripts/test.sh` (pass) + CI run (pass).
    - [x] Representative samples include failure + rerun after fix: at least one negative test per high-risk script family.
    - [x] Traceable evidence exists: smoke summary + logs + CI links.
  - Evidence:
    - 2026-01-14T07:48:17+08:00 local: `$CODEX_HOME/scripts/test.sh` (97 passed in 4.41s) on `feat/script-smoke-tests` @ `1e38e21d`.
    - Local artifacts: `out/tests/script-regression/summary.json`, `out/tests/script-regression/logs`, `out/tests/script-smoke/summary.json`, `out/tests/script-smoke/logs`.
    - 2026-01-13T23:39:40Z CI: GitHub Actions `Lint` workflow_dispatch success (run `20976621777`, sha `1e38e21d`): https://github.com/graysurf/codex-kit/actions/runs/20976621777
    - Negative samples (failure → fix) recorded under `out/tests/step3-evidence/`:
      - `rest.sh`: curl blocked → stubbed curl success
      - `gql.sh`: xh blocked → stubbed xh success
      - `psql.zsh`: missing env → env set + stubbed psql success
      - `gh`: blocked → stubbed gh success
- [x] Step 4: Release / wrap-up (optional)
  - Work Items:
    - [x] Decide whether this warrants a version bump (decision: `v1.0.2`).
  - Artifacts:
    - `CHANGELOG.md` entry (optional)
  - Exit Criteria:
    - [x] Versioning and changes recorded: `v1.0.2` + changelog entry.
    - [x] Release actions completed: tag + GitHub Release for `v1.0.2`.
    - [x] Documentation completed: `docs/testing/script-smoke.md` and updates to `docs/testing/script-regression.md` as needed.
    - [x] Cleanup completed: move this progress file to archived and mark DONE.
  - Evidence:
    - Versioning decision recorded in this Step 4 (`v1.0.2`).
    - Release link: https://github.com/graysurf/codex-kit/releases/tag/v1.0.2
    - Docs present: `docs/testing/script-smoke.md`, `docs/testing/script-regression.md`.
    - Progress archived: `docs/progress/archived/20260113_script-smoke-tests.md`; index updated in `docs/progress/README.md`.

## Modules

- `tests/test_script_regression.py`: baseline entrypoint regression (default `--help`).
- `tests/script_specs/**`: per-script overrides for regression.
- `tests/test_audit_scripts.py`: existing functional tests for selected scripts.
- `tests/stubs/bin/**`: hermetic stubs (e.g. `curl`, `gh`, `wget`).
- `docs/testing/script-regression.md`: current docs for regression suite.
- `tests/test_script_smoke.py`: functional smoke suite (marker-based).
- `tests/script_specs/**`: spec-driven smoke cases.
- `tests/fixtures/**`: fixture repos/files for smoke.
- `docs/testing/script-smoke.md`: smoke docs + authoring guide.

## Script Inventory

Tracked script entrypoints (via `git ls-files`):

| Script | Interpreter | Current | Planned smoke harness | Notes |
| --- | --- | --- | --- | --- |
| `$CODEX_HOME/scripts/build/bundle-wrapper.zsh` | `zsh -f` | regression (`--help`) | `pytest-fixture` | likely needs temp FS + wrapper inputs |
| `$CODEX_HOME/scripts/chrome-devtools-mcp.sh` | `bash` | regression (spec: dry-run) | `spec-smoke` | keep `CHROME_DEVTOOLS_DRY_RUN=true` |
| `commands/git-scope` | `zsh -f` | regression (`--help`) | `spec-smoke` | can stub `git` and validate output format |
| `commands/git-commit-context-json` | `zsh -f` | regression (`--help`) | `spec-smoke` | can stub `git` and validate output format |
| `$CODEX_HOME/scripts/db-connect/mssql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `sqlcmd` to validate argv/env wiring |
| `$CODEX_HOME/scripts/db-connect/mysql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `mysql` to validate argv/env wiring |
| `$CODEX_HOME/scripts/db-connect/psql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `psql` to validate argv/env wiring |
| `$CODEX_HOME/scripts/env.zsh` | `zsh -f` | regression (`--help`) | `help-only` | environment helper; keep lightweight |
| `$CODEX_HOME/scripts/test.sh` | `bash` | regression (`--help`) | `help-only` | runs deps/tests; avoid running in CI smoke |
| `$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh` | `bash` | functional pytest | `pytest-fixture` | already covered by `tests/test_audit_scripts.py` |
| `$CODEX_HOME/skills/_projects/finance-report/scripts/fr-psql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `psql` and validate flags |
| `$CODEX_HOME/skills/_projects/megabank/scripts/mb-mssql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `sqlcmd` and validate flags |
| `$CODEX_HOME/skills/_projects/qburger/scripts/qb-mysql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `mysql` and validate flags |
| `$CODEX_HOME/skills/_projects/tun-group/scripts/tun-mssql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `sqlcmd` and validate flags |
| `$CODEX_HOME/skills/_projects/tun-group/scripts/tun-psql.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `psql` and validate flags |
| `$CODEX_HOME/skills/tools/devex/desktop-notify/scripts/desktop-notify.sh` | `bash` | regression (`--help`) | `spec-smoke` | stub notifier; validate no-op behavior |
| `$CODEX_HOME/skills/tools/devex/desktop-notify/scripts/project-notify.sh` | `bash` | regression (`--help`) | `spec-smoke` | stub notifier; validate wrapper output |
| `$CODEX_HOME/skills/tools/devex/open-changed-files-review/scripts/open-changed-files.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | stub `code`; validate silent no-op |
| `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/commit_with_message.sh` | `zsh -f` | regression (`--help`) | `pytest-fixture` | needs temp git repo (creates commits) |
| `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/staged_context.sh` | `zsh -f` | regression (`--help`) | `pytest-fixture` | needs temp git repo to stage diffs |
| `$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test-summary.sh` | `bash` | regression (`--help`) | `spec-smoke` | stub inputs; validate output format |
| `$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs fixture manifests + stubbed runners |
| `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-history.sh` | `bash` | regression (`--help`) | `spec-smoke` | fixture history dir under `out/tests` |
| `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-report.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs fixture operations + stubbed HTTP |
| `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-schema.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs fixture schema + stubbed HTTP |
| `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs stubbed HTTP + fixture ops |
| `$CODEX_HOME/skills/tools/testing/rest-api-testing/scripts/rest-history.sh` | `bash` | regression (`--help`) | `spec-smoke` | fixture history dir under `out/tests` |
| `$CODEX_HOME/skills/tools/testing/rest-api-testing/scripts/rest-report.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs fixture requests + stubbed HTTP |
| `$CODEX_HOME/skills/tools/testing/rest-api-testing/scripts/rest.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs stubbed HTTP + fixture files |
| `$CODEX_HOME/skills/automation/find-and-fix-bugs/scripts/render_issues_pr.sh` | `bash` | regression (`--help`) | `spec-smoke` | fixture issues JSON input, no network |
| `$CODEX_HOME/skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh` | `bash` | regression (`--help`) | `pytest-fixture` | stub `gh`; validate command sequencing |
| `$CODEX_HOME/skills/workflows/pr/feature/create-feature-pr/scripts/render_feature_pr.sh` | `bash` | regression (`--help`) | `spec-smoke` | render-only; validate output format |
| `$CODEX_HOME/skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh` | `bash` | regression (`--help`) | `pytest-fixture` | stub `gh`; fixture progress files |
| `$CODEX_HOME/skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh` | `bash` | regression (`--help`) | `pytest-fixture` | needs temp repo to avoid writing to real docs |
| `$CODEX_HOME/skills/workflows/pr/progress/create-progress-pr/scripts/render_progress_pr.sh` | `bash` | regression (`--help`) | `spec-smoke` | render-only; validate output format |
| `$CODEX_HOME/skills/workflows/pr/progress/create-progress-pr/scripts/validate_progress_index.sh` | `bash` | functional pytest | `pytest-fixture` | already covered by `tests/test_audit_scripts.py` |
| `$CODEX_HOME/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh` | `bash` | regression (`--help`) | `pytest-fixture` | stub `gh`; fixture progress PR metadata |
| `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/audit_progress_addendum.sh` | `bash` | regression (`--help`) | `spec-smoke` | audit `docs/progress/**` for canonical addendum placement |
| `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh` | `bash` | regression (`--help`) | `pytest-fixture` | run against fixture progress copies under `out/tests` |
| `$CODEX_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh` | `zsh -f` | regression (`--help`) | `spec-smoke` | run `--check` via smoke spec |
| `$CODEX_HOME/skills/automation/release-workflow/scripts/release-audit.sh` | `bash` | regression (`--help`) | `pytest-fixture` | temp repo for tag checks + changelog fixtures |
| `$CODEX_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh` | `bash` | regression (`--help`) | `pytest-fixture` | changelog fixtures, verify extracted notes |
| `$CODEX_HOME/skills/automation/release-workflow/scripts/release-scaffold-entry.sh` | `bash` | regression (`--help`) | `spec-smoke` | output to `out/tests` and verify content |

## Step 2 PR Plan

Goal: Expand `script_smoke` coverage without making a single massive PR. Each PR should be reviewable and
focused on one script family + its required stubs/fixtures.

Defaults (selected):

- Start from the baseline commit that lands Step 1 (`script_smoke` harness + initial cases).
- Prefer `spec-smoke` cases first; defer `pytest-fixture` scripts unless the fixture setup is minimal.
- Stubs should be strict validators by default (fail fast when argv/env wiring is wrong).
- Keep a single `script_smoke` marker for now (no quick/full split yet).

Planned PRs:

| PR | Scope | Target scripts (primary) | Notes |
| --- | --- | --- | --- |
| #23 | DB client stubs (`psql`, `mysql`, `sqlcmd`) | `scripts/db-connect/*.zsh`, `skills/_projects/*/scripts/*` | Add strict stubs first; fixture-based coverage may follow in a later PR. |
| #25 | Smoke specs: Chrome devtools + history tools | `$CODEX_HOME/scripts/chrome-devtools-mcp.sh`, `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-history.sh` | Use dry-run + history fixtures under `tests/fixtures/`. |
| #24 | Smoke specs: desktop notifications | `skills/tools/devex/desktop-notify/scripts/*.sh` | Add notifier stubs (`terminal-notifier` / `notify-send`) and validate wrapper behavior. |
| #26 | Smoke specs: release workflow audits | `$CODEX_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh`, `.../release-scaffold-entry.sh` | Write outputs to `out/tests/script-smoke/**` and verify artifacts. |
| #27 | Smoke specs: render-only workflow helpers | `skills/workflows/**/scripts/render_*.sh` | Validate templates render; no network required. |
| #34 | Smoke specs: git command wrappers | `commands/git-scope`, `commands/git-commit-context-json` | Validate wrappers run in a hermetic env (includes a minimal `tree` stub). |
| #28 | Follow-ups: PR workflow fixtures | `$CODEX_HOME/skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh`, `$CODEX_HOME/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh`, `$CODEX_HOME/skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh` | Fixture-based smoke coverage with an opt-in stubbed `gh`. |
| #29 | Follow-ups: semantic commit fixture | `$CODEX_HOME/skills/tools/devex/semantic-commit/scripts/commit_with_message.sh` | Fixture-based smoke coverage in a temp git repo. |
| #30 | Follow-ups: API testing tool fixtures | `$CODEX_HOME/skills/tools/testing/rest-api-testing/scripts/rest.sh`, `.../rest-report.sh`, `$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh`, `.../gql-report.sh`, `.../gql-schema.sh`, `$CODEX_HOME/skills/tools/testing/api-test-runner/scripts/api-test.sh` | Add opt-in `curl`/`xh` stubs, fixtures, and smoke specs. |
| #31 | Follow-ups: progress file helper fixtures | `$CODEX_HOME/skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh`, `skills/workflows/pr/progress/progress-addendum/scripts/*.sh` | Fixture-based smoke coverage in a temp git repo. |
| #32 | Follow-ups: release workflow fixtures | `$CODEX_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh`, `.../release-audit.sh` | Fixture-based smoke coverage with a stubbed `gh auth status`. |
| #33 | Follow-ups: bundle wrapper fixture | `$CODEX_HOME/scripts/build/bundle-wrapper.zsh` | Fixture-based smoke coverage for bundled sources + embedded exec tools. |
