# env_bools: Env bool flags standardization

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-16 | 2026-01-16 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/48
- Docs: None
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- Standardize project-owned boolean env flags to accept only `true|false` (case-insensitive).
- On invalid values: warn to stderr and treat as `false`.
- Unify naming: project-owned boolean flags end with `_ENABLED` (rename existing; no legacy aliases).
- Add a repo-local audit and wire it into `scripts/check.sh --all` to prevent regressions.

## Acceptance Criteria

- All env flags listed under Inventory are renamed/updated across code + docs + tests (excluding `docs/progress/**`), and
  tracked examples/specs use only `true|false` values for them.
- Boolean parsing is consistent: only `true|false` are accepted; any other non-empty value warns to stderr and is treated
  as `false`.
- Repo validation passes after implementation:
  - `scripts/check.sh --all`
  - `scripts/audit-env-bools.zsh --check`
- No tracked source/docs examples for Inventory flags use legacy names or `=0` / `=1` / `yes` / `no` / `on` / `off`.

## Scope

- In-scope:
  - Rename and standardize boolean env flags listed under Inventory across:
    - `.github/workflows/`
    - `scripts/`
    - `skills/`
    - `tests/`
    - `docs/` (excluding `docs/progress/**`)
  - Add `scripts/audit-env-bools.zsh` (ported from `/Users/terry/.config/zsh/tools/audit-env-bools.zsh`) and integrate it
    into `scripts/check.sh --all`.
- Out-of-scope:
  - Backwards compatibility / legacy aliases for old env names or `0/1` values.
  - Third-party/upstream env vars (e.g. `NO_COLOR`, `PYTHONDONTWRITEBYTECODE`).
  - Non-boolean env vars (strings, integers, durations).
  - Historical docs under `docs/progress/**`.

## I/O Contract

### Input

- User-configured env flags (see Inventory) set via local shell, CI, or env files.
- Repo source files that read/parse these env flags.
- Script regression specs under `tests/script_specs/**` that set stub env flags for smoke tests.

### Output

- Consistent boolean env contract for all Inventory flags:
  - Naming: `*_ENABLED`
  - Values: `true|false` only (case-insensitive)
  - Invalid value behavior: warn to stderr, treated as `false`
- Repo-local enforcement: `scripts/audit-env-bools.zsh --check`.
- Updated docs/templates/examples and test specs to the new names/values.

### Intermediate Artifacts

- `docs/progress/20260116_env-bool-flags.md` (this file)
- `scripts/audit-env-bools.zsh`
- `out/` artifacts produced by validation (e.g. Semgrep JSON from `scripts/check.sh --all`) (optional)

## Design / Decisions

### Rationale

- `*_ENABLED` is the single, uniform convention for boolean env flags (clear intent; easy to grep).
- Restricting to `true|false` avoids ambiguous `0/1` and reduces per-module parsing drift.
- A shared boolean parser + an audit script keeps behavior consistent and prevents regressions.

### Risks / Uncertainties

- Breaking change: env names and accepted values change; local shells, CI, and test specs must be updated in lockstep.
  - Mitigation: list every affected env var and touchpoint in Inventory; no hidden fallbacks or legacy aliases.
- Some flags today accept multiple truthy/falsy vocab; tightening may surprise callers.
  - Mitigation: warn to stderr on invalid non-empty values and treat them as `false`.

## Inventory

Proposed project rules (this repo):

- Boolean env flags: only `true` / `false` (case-insensitive).
- Invalid values: warn to stderr and treat as `false`.
- Naming: project-owned boolean flags end with `_ENABLED`.

Already compliant (no changes):

- `CODEX_DESKTOP_NOTIFY_ENABLED` (`skills/tools/devex/desktop-notify/**`)
- `CODEX_DESKTOP_NOTIFY_HINTS_ENABLED` (`skills/tools/devex/desktop-notify/**`)

Explicit exclusions (out-of-scope examples):

- Third-party env vars like `NO_COLOR`, `CLICOLOR`, `PYTHONDONTWRITEBYTECODE`.
- Non-boolean env vars like `GQL_VARS_MIN_LIMIT` and `CHROME_DEVTOOLS_PREFLIGHT_TIMEOUT_SEC`.
- Historical references under `docs/progress/**` (excluded from audit).

| Env (current) | Env (new) | codex-kit touchpoints | Notes |
| --- | --- | --- | --- |
| `CHROME_DEVTOOLS_DRY_RUN` | `CHROME_DEVTOOLS_DRY_RUN_ENABLED` | `scripts/chrome-devtools-mcp.sh`<br>`tests/script_specs/scripts/chrome-devtools-mcp.sh.json` | Rename; strict `true|false` only. |
| `CHROME_DEVTOOLS_PREFLIGHT` | `CHROME_DEVTOOLS_PREFLIGHT_ENABLED` | `scripts/chrome-devtools-mcp.sh`<br>`tests/script_specs/scripts/chrome-devtools-mcp.sh.json` | Rename; strict `true|false` only. |
| `CHROME_DEVTOOLS_AUTOCONNECT` | `CHROME_DEVTOOLS_AUTOCONNECT_ENABLED` | `scripts/chrome-devtools-mcp.sh` | Rename; strict `true|false` only. |
| `REST_HISTORY` | `REST_HISTORY_ENABLED` | `skills/tools/testing/rest-api-testing/SKILL.md`<br>`skills/tools/testing/rest-api-testing/scripts/rest.sh` | Rename; update `--no-history` to set `REST_HISTORY_ENABLED=false`. |
| `REST_HISTORY_LOG_URL` | `REST_HISTORY_LOG_URL_ENABLED` | `skills/tools/testing/rest-api-testing/scripts/rest.sh` | Rename; strict `true|false` only. |
| `REST_REPORT_INCLUDE_COMMAND` | `REST_REPORT_INCLUDE_COMMAND_ENABLED` | `skills/tools/testing/rest-api-testing/scripts/rest-report.sh` | Rename; strict `true|false` only. |
| `REST_REPORT_COMMAND_LOG_URL` | `REST_REPORT_COMMAND_LOG_URL_ENABLED` | `skills/tools/testing/rest-api-testing/scripts/rest-report.sh` | Rename; strict `true|false` only. |
| `GQL_HISTORY` | `GQL_HISTORY_ENABLED` | `skills/tools/testing/graphql-api-testing/SKILL.md`<br>`skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`<br>`skills/tools/testing/graphql-api-testing/scripts/gql.sh`<br>`skills/tools/testing/graphql-api-testing/template/setup/graphql/gql.local.env.example` | Rename; update `--no-history` to set `GQL_HISTORY_ENABLED=false`. |
| `GQL_HISTORY_LOG_URL` | `GQL_HISTORY_LOG_URL_ENABLED` | `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`<br>`skills/tools/testing/graphql-api-testing/scripts/gql.sh`<br>`skills/tools/testing/graphql-api-testing/template/setup/graphql/gql.local.env.example` | Rename; strict `true|false` only. |
| `GQL_REPORT_INCLUDE_COMMAND` | `GQL_REPORT_INCLUDE_COMMAND_ENABLED` | `skills/tools/testing/graphql-api-testing/SKILL.md`<br>`skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`<br>`skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`<br>`skills/tools/testing/graphql-api-testing/template/setup/graphql/gql.local.env.example` | Rename; strict `true|false` only. |
| `GQL_REPORT_COMMAND_LOG_URL` | `GQL_REPORT_COMMAND_LOG_URL_ENABLED` | `skills/tools/testing/graphql-api-testing/references/GRAPHQL_API_TESTING_GUIDE.md`<br>`skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`<br>`skills/tools/testing/graphql-api-testing/template/setup/graphql/gql.local.env.example` | Rename; strict `true|false` only. |
| `GQL_ALLOW_EMPTY` | `GQL_ALLOW_EMPTY_ENABLED` | `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`<br>`skills/tools/testing/graphql-api-testing/template/setup/graphql/gql.local.env.example` | Rename; strict `true|false` only. |
| `API_TEST_ALLOW_WRITES` | `API_TEST_ALLOW_WRITES_ENABLED` | `.github/workflows/api-test-runner.yml`<br>`skills/tools/testing/api-test-runner/SKILL.md`<br>`skills/tools/testing/api-test-runner/scripts/api-test-summary.sh`<br>`skills/tools/testing/api-test-runner/scripts/api-test.sh` | Rename; update docs/workflow examples from `1` to `true`. |
| `CODEX_CURL_STUB_MODE` | `CODEX_CURL_STUB_MODE_ENABLED` | `tests/script_specs/skills/tools/testing/api-test-runner/scripts/api-test.sh.json`<br>`tests/script_specs/skills/tools/testing/rest-api-testing/scripts/rest.sh.json`<br>`tests/stubs/bin/curl` | Rename; update test specs from `\"1\"` to `\"true\"`. |
| `CODEX_XH_STUB_MODE` | `CODEX_XH_STUB_MODE_ENABLED` | `tests/script_specs/skills/tools/testing/api-test-runner/scripts/api-test.sh.json`<br>`tests/script_specs/skills/tools/testing/graphql-api-testing/scripts/gql.sh.json`<br>`tests/stubs/bin/xh` | Rename; update test specs from `\"1\"` to `\"true\"`. |
| `CODEX_GH_STUB_MODE` | `CODEX_GH_STUB_MODE_ENABLED` | `tests/script_specs/skills/automation/fix-bug-pr/scripts/bug-pr-patch.sh.json`<br>`tests/script_specs/skills/automation/fix-bug-pr/scripts/bug-pr-resolve.sh.json`<br>`tests/stubs/bin/gh`<br>`tests/test_script_smoke_gh_workflows.py` | Rename; update test specs from `\"1\"` to `\"true\"`. |
| `CODEX_GH_STUB_MERGE_HELP_HAS_YES` | `CODEX_GH_STUB_MERGE_HELP_HAS_YES_ENABLED` | `tests/stubs/bin/gh` | Rename; update default and parsing to strict `true|false`. |

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, close-progress-pr will auto-wrap the item text with Markdown strikethrough (use `- [ ] ~~like this~~`).

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Review and confirm the Inventory table (env list + renames + touched files).
    - [ ] Confirm explicit exclusions for upstream and non-boolean env vars (see Inventory exclusions).
    - [ ] Confirm enforcement scope (include tests + workflows; exclude `docs/progress/**`).
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - Inventory table (in this file)
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned.
    - [ ] I/O contract is defined (inputs/outputs/artifacts).
    - [ ] Risks and rollout plan are defined (including breaking-change notes).
    - [ ] Verification commands are defined:
      - `scripts/check.sh --all`
      - `scripts/audit-env-bools.zsh --check`
- [ ] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [ ] Introduce shared boolean env parsing helper(s) (single source of truth per shell).
    - [ ] Apply env renames + strict parsing across all Inventory flags in code.
    - [ ] Update docs/templates/examples and test specs to new names + `true|false` values.
  - Artifacts:
    - Updated sources under `.github/workflows/`, `scripts/`, `skills/`, `tests/`, `docs/` (excluding `docs/progress/**`)
  - Exit Criteria:
    - [ ] All Inventory flags use `*_ENABLED` names and accept only `true|false`.
    - [ ] No tracked examples/specs for Inventory flags use `0/1/yes/no/on/off`.
- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Add `scripts/audit-env-bools.zsh --check` and integrate into `scripts/check.sh --all`.
    - [ ] Add/adjust regression tests for the new audit script (and any updated specs/stubs).
  - Artifacts:
    - `scripts/audit-env-bools.zsh`
    - Updates to `scripts/check.sh`
    - Test coverage under `tests/`
  - Exit Criteria:
    - [ ] `scripts/audit-env-bools.zsh --check` passes.
    - [ ] `scripts/check.sh --all` passes with audit included.
    - [ ] No remaining legacy env names or forbidden values for Inventory flags outside `docs/progress/**`.
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Run and record full repo validation (`scripts/check.sh --all`).
    - [ ] Run and record the env-bools audit (`scripts/audit-env-bools.zsh --check`).
  - Artifacts:
    - PR `Testing` notes (pass/failed/skipped per command)
    - Any logs under `out/` (when produced)
  - Exit Criteria:
    - [ ] Validation and test commands executed with results recorded.
    - [ ] Script-smoke / regression coverage still passes after env changes.
    - [ ] Evidence exists (logs/outputs/commands) in PR description or `out/`.
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Set Status to `DONE`, archive progress file, and update index (close-progress-pr).
  - Artifacts:
    - Archived progress file under `docs/progress/archived/`
  - Exit Criteria:
    - [ ] Cleanup completed (set Status to `DONE`; move to `archived/`; update index; patch PR Progress link).

## Modules

- `scripts/audit-env-bools.zsh`: enforce boolean env conventions (`*_ENABLED`, `true|false` only).
- `scripts/check.sh`: integrate `scripts/audit-env-bools.zsh --check` into `--all`.
- `scripts/chrome-devtools-mcp.sh`: adopt renamed `CHROME_DEVTOOLS_*_ENABLED` flags and strict parsing.
- `skills/tools/testing/rest-api-testing/scripts/rest.sh`: adopt renamed `REST_*_ENABLED` flags and strict parsing.
- `skills/tools/testing/rest-api-testing/scripts/rest-report.sh`: adopt renamed `REST_REPORT_*_ENABLED` flags and strict parsing.
- `skills/tools/testing/graphql-api-testing/scripts/gql.sh`: adopt renamed `GQL_*_ENABLED` flags and strict parsing.
- `skills/tools/testing/graphql-api-testing/scripts/gql-report.sh`: adopt renamed `GQL_*_ENABLED` flags and strict parsing.
- `skills/tools/testing/api-test-runner/scripts/api-test.sh`: adopt renamed `API_TEST_ALLOW_WRITES_ENABLED` and strict parsing.
- `tests/stubs/bin/*`: adopt renamed `CODEX_*_STUB_*_ENABLED` flags and strict parsing.
