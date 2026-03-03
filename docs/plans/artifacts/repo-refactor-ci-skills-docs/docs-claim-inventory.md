# Docs Claim Inventory and Drift Rubric (Task 1.4)

## Scope

- Task: S1T4 (`Build docs accuracy inventory and drift rubric`).
- Audited docs:
  - `README.md`
  - `DEVELOPMENT.md`
  - `docs/runbooks/agent-docs/context-dispatch-matrix.md`
  - `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
  - `docs/testing/script-regression.md`
  - `docs/testing/script-smoke.md`
- Goal: inventory command/path/workflow claims and prioritize updates by drift severity.

## Drift Rubric

| Drift severity | Criteria | Action target |
| --- | --- | --- |
| `Critical` | Incorrect claim can cause destructive behavior, invalid governance decisions, or guaranteed failure in required release/merge gates. | Fix before next merge to `main`. |
| `High` | Incorrect claim likely breaks default contributor workflows, CI parity checks, or routine copy/paste commands. | Fix in next sprint lane touching the area. |
| `Medium` | Claim is partially outdated or example-specific, but has a safe workaround and does not block default flows. | Fix in scheduled docs refresh. |
| `Low` | Cosmetic wording drift; command/path intent remains correct. | Batch in normal docs cleanup. |

## Docs Claim Checklist

### Commands

- [ ] Command exists at the documented entrypoint (`scripts/...`, `skills/.../scripts/...`, or tool binary).
- [ ] Flags/options in docs match current script parser behavior.
- [ ] Preconditions are explicit (`.venv`, `AGENT_HOME`, tool installation).

### File paths

- [ ] Referenced file/dir exists in repo or is clearly labeled as environment-dependent.
- [ ] Path style is consistent (`$AGENT_HOME/...` for absolute examples, repo-relative otherwise).
- [ ] Artifact/output paths match current writer locations.

### Workflow behavior

- [ ] Ordered preflight/validation steps match canonical runbooks.
- [ ] Hard-gate vs soft-gate behavior matches `context-dispatch-matrix.md`.
- [ ] Fallback behavior for missing docs/check failures is present and actionable.

## Claim Inventory

| Claim ID | Source doc | Claim type | Claim | Current state | Drift severity | Owner | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DCI-001` | `README.md` | Path | Repo structure includes `AGENTS.md` at repo root. | Drift detected: branch tracks `AGENT_DOCS.toml`, but no tracked `AGENTS.md` in this worktree. | `High` | Docs maintainer | `git ls-files` in lane includes `AGENT_DOCS.toml` and no `AGENTS.md`. |
| `DCI-002` | `README.md` | Command/path | New-project bootstrap uses `$AGENT_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh`. | Verified: script path exists. | `Low` | Agent-docs maintainer | File exists at `skills/tools/agent-doc-init/scripts/agent_doc_init.sh`. |
| `DCI-003` | `README.md` | Path | Prompt/skill links point to real repo content. | Spot-checked and verified for prompt + issue workflow paths. | `Low` | Docs maintainer | Verified examples: `prompts/actionable-advice.md`, `skills/workflows/issue/issue-subagent-pr/SKILL.md`. |
| `DCI-004` | `DEVELOPMENT.md` | Workflow | `scripts/check.sh --all` runs lint, markdown, third-party, contracts, layout, plans, env-bools, semgrep, tests. | Verified: all listed phases are invoked in `scripts/check.sh`. | `Low` | CI maintainer | `scripts/check.sh` lines include `scripts/lint.sh`, markdown/third-party audit, skill governance scripts, `plan-tooling`, env-bools, semgrep, pytest. |
| `DCI-005` | `DEVELOPMENT.md` | Command | `scripts/test.sh` writes coverage summaries under `out/tests/script-coverage/`. | Verified in script implementation. | `Low` | Testing maintainer | `scripts/test.sh` exports coverage paths to `out/tests/script-coverage/summary.md` and `summary.json`. |
| `DCI-006` | `DEVELOPMENT.md` | Command | `scripts/fix-typeset-empty-string-quotes.zsh` and `scripts/fix-zsh-typeset-initializers.zsh` are available autofix helpers. | Verified: both scripts exist. | `Low` | Shell tooling maintainer | Both paths present under `scripts/`. |
| `DCI-007` | `context-dispatch-matrix.md` | Workflow | Project implementation preflight is `startup --strict` then `project-dev --strict`. | Verified and aligned with `PROJECT_DEV_WORKFLOW.md`. | `Low` | Agent-docs maintainer | Matching command strings appear in both runbooks. |
| `DCI-008` | `context-dispatch-matrix.md` | Workflow | Strict-failure fallback is `agent-docs baseline --check --target all --strict --format text`. | Verified and aligned with project-dev workflow failure handling. | `Low` | Agent-docs maintainer | Same fallback appears in matrix and workflow docs. |
| `DCI-009` | `PROJECT_DEV_WORKFLOW.md` | Workflow | `task-tools` resolve is optional and only needed for external lookups. | Verified and consistent with dispatch matrix policy. | `Low` | Agent-docs maintainer | Optional Step 3 in workflow matches matrix row for project implementation. |
| `DCI-010` | `docs/testing/script-regression.md` | Command | Regression suite can be run with `$AGENT_HOME/scripts/test.sh`. | Verified: wrapper script exists and runs pytest. | `Low` | Testing maintainer | `scripts/test.sh` usage includes marker passthrough and pytest invocation. |
| `DCI-011` | `docs/testing/script-regression.md` | Workflow | Script discovery includes `commands/**`. | Drift detected: `discover_scripts()` currently includes `scripts/` and `skills/**/scripts/**`; `commands/**` is not included and `commands/` is absent in this branch. | `High` | Testing maintainer | `tests/conftest.py` `discover_scripts()` filter; `commands_dir_missing` in lane. |
| `DCI-012` | `docs/testing/script-regression.md` | Path | Regression/smoke evidence written under `out/tests/script-regression/**`, `out/tests/script-smoke/**`, and script coverage under `out/tests/script-coverage/**`. | Verified in test harness and script wrapper. | `Low` | Testing maintainer | `tests/conftest.py` `out_dir()`, `out_dir_smoke()`, and script coverage writer; `scripts/test.sh` coverage paths. |
| `DCI-013` | `docs/testing/script-smoke.md` | Command/path | Cleanup gate example path uses `$AGENT_HOME/out/plan-issue-delivery/graysurf-agent-kit/...`. | Drift detected: current slug convention in active lanes uses `graysurf__agent-kit`; documented slug path does not exist in this environment. | `High` | Plan-issue docs maintainer | `docs/testing/script-smoke.md` line with `graysurf-agent-kit`; actual directory present: `$AGENT_HOME/out/plan-issue-delivery/graysurf__agent-kit`. |
| `DCI-014` | `docs/testing/script-smoke.md` | Path | Fixture-driven smoke reference `tests/test_script_smoke.py` exists. | Verified. | `Low` | Testing maintainer | File exists and contains fixture-driven smoke tests. |

## Priority Order for Updates (Critical Docs First)

1. `docs/testing/script-smoke.md` (fix high-drift slug/path example in cleanup gate).
2. `docs/testing/script-regression.md` (fix high-drift script discovery scope claim for `commands/**`).
3. `README.md` (resolve root-file naming drift for `AGENTS.md` vs tracked policy file reality).
4. `DEVELOPMENT.md` (monitor command inventory parity with `scripts/check.sh` on each CI refactor).
5. `docs/runbooks/agent-docs/context-dispatch-matrix.md` and
   `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md` (currently aligned;
   keep as regression anchor docs).

## Suggested Drift Detection Routine

1. Run `rg -n "scripts/|agent-docs resolve|plan-tooling|out/tests|AGENT_HOME" README.md DEVELOPMENT.md docs/runbooks/agent-docs/*.md docs/testing/*.md`.
2. For each claim row touched by a PR, verify command/path existence and workflow order in-source.
3. If any `High` or `Critical` row changes, update this inventory in the same PR to keep drift status current.
