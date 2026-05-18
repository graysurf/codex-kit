# Skills Tooling Index v2

This doc lists canonical entrypoints (skill scripts, PATH-installed tooling, and scriptless command contracts). Install `nils-cli` via
`brew install nils-cli` to get `plan-tooling`, `api-*`, `semantic-commit`, `agent-out`, and the current evidence and guardrail primitives
on PATH. The workflow primitive skills below require `nils-cli 0.8.4` or newer unless a skill explicitly states a newer binary-surface
boundary. For skill directory layout/path rules, use
`docs/runbooks/skills/SKILLS_ANATOMY_V2.md` as the canonical reference. For create/validate/remove workflows, see
`skills/tools/skill-management/README.md`.

Public skill domains remain `skills/workflows/`, `skills/tools/`, and
`skills/automation/`. Nested folders below those domains are allowed as catalog
taxonomy when they express a stable behavior boundary; they do not change the
workflow/tool/automation contract.

This index lists implemented entrypoints only.

## Stale path audits after skill moves

After moving a skill directory, audit current-contract references to the old
path before declaring the move complete. Use `rg -n` across `README.md docs
skills tests scripts .github`, then update executable paths, script specs,
tests, catalog links, and maintained runbook references. Leave historical notes
only when they are intentionally retained as migration history.

## SKILL.md format

- SKILL.md format spec:
  - `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`
- Skill directory anatomy (canonical):
  - `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`

## Skill governance

- Validate SKILL.md contract format:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Audit tracked skill directory layout:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- Validate runnable path rules in SKILL.md:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_paths.sh`

## Skill usage recording

- Skill usage recording convention:
  - `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`
- Draft JSON schema:
  - `docs/runbooks/skills/skill-usage-record-v1.schema.json`
- Canonical nils-cli primitive:
  - Skill contract: `skills/tools/workflow-evidence/skill-usage/SKILL.md`
  - `skill-usage init --out <dir> --skill <skill> --intent <intent> --user-request-summary <summary>`
  - `skill-usage link-record --out <dir> --type <record-type> --path <path>`
  - `skill-usage record-failure --out <dir> --phase preflight|execution|validation|cleanup|delivery --classification <classification>
    --symptom <text> --diagnosis <text> --handling <text> --result fixed|worked-around|blocked|accepted-risk`
  - `skill-usage record-validation --out <dir> --command <command> --status pass|fail|skipped --summary <summary>`
  - `skill-usage record-outcome --out <dir> --status pass|fail|blocked|worked-around|accepted-risk|skipped --summary <summary>`
  - `skill-usage verify --out <dir> --format json`
  - `skill-usage show --out <dir> --format json`
- Artifact contract: `skill-usage.record.json` with record schema `skill-usage.record.v1`.
- Durable unresolved workflow gaps: keep raw `skill-usage.record.json` in its
  evidence location, then commit a curated tracker under
  `heuristic-system/error-inbox/` when the gap must not be lost.
- Boundary: use a PATH `skill-usage` binary only after `skill-usage --version` reports 0.8.5 or newer. If the released PATH binary is
  absent or older, consume the primitive through a validated local `nils-cli` checkout:
  `cargo run --locked --manifest-path /path/to/nils-cli/Cargo.toml -p nils-agent-workflow-primitives --bin skill-usage -- <subcommand>
  ...`.
- Legacy fallback/reference validator:
  - `scripts/skills/validate_skill_usage_record.py path/to/skill-usage.record.json`
  - Keep this only for transition and fixtures; do not add new canonical behavior outside nils-cli.

## Skill management

- Create a new skill skeleton (validated):
  - `$AGENT_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh`
- Remove a skill and purge references (breaking change):
  - `$AGENT_HOME/skills/tools/skill-management/remove-skill/scripts/remove_skill.sh`

## Plan tooling (Plan Format v1)

- Scaffold a new plan file:
  - `plan-tooling scaffold --slug <slug>`
  - Requires `nils-cli >= 0.8.7` for the folder default
    `docs/plans/<slug>/<slug>-plan.md`.
- Lint plans:
  - `plan-tooling validate`
- Parse plan → JSON:
  - `plan-tooling to-json`
- Compute dependency batches:
  - `plan-tooling batches`

## Issue workflow (main-agent + subagent PR automation)

- Main-agent issue lifecycle:
  - `$AGENT_HOME/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh`
- Subagent worktree + PR execution:
  - Scriptless contract using native `git` + `gh` commands (see `skills/workflows/issue/issue-subagent-pr/SKILL.md`)
- Main-agent PR review + issue sync:
  - `$AGENT_HOME/skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh`

## Issue delivery automation (main-agent orchestration CLI)

- Live GitHub-backed orchestration (issue and plan flows):
  - `plan-issue <subcommand>`
- Local rehearsal / dry-run orchestration (same subcommands, no GitHub writes):
  - `plan-issue-local <subcommand> --dry-run`
- Key subcommands:
  - `start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`, `status-plan`, `ready-plan`, `close-plan`

## Artifact output paths

- Create a project-scoped ad hoc artifact run directory:
  - `agent-out project --topic <topic> --mkdir`
- Audit `$AGENT_HOME/out/` for noncanonical top-level entries:
  - `agent-out audit --agent-home "$AGENT_HOME"`

## Web evidence

- Capture deterministic, redacted static HTTP evidence bundles for agent
  workflows:
  - Skill contract: `skills/tools/browser/evidence/web-evidence/SKILL.md`
  - `web-evidence capture <url> --out <dir> [--format text|json] [--label <label>]`
  - `web-evidence capture <url> --out <dir> [--method get|head]`
  - `web-evidence completion <bash|zsh>`
- Artifact contract: `summary.json`, `headers.redacted.json`, and
  `body-preview.redacted.txt` under the requested output directory.
- Version floor: requires `nils-cli 0.8.4` or newer with the
  `nils-web-evidence` package on PATH.
- Scope boundary: this is static HTTP/HTTPS evidence only; use Browser, Chrome,
  Playwright, or `web-qa` active mode for JavaScript execution,
  screenshots, cookies, authenticated sessions, console logs, or browser state.

## Web QA

- Run scriptless static or active browser QA evidence workflows:
  - Skill contract: `skills/tools/browser/evidence/web-qa/SKILL.md`
  - Static mode: `web-evidence capture <url> --out <run-dir>/web-evidence --label <scenario> --format json`
  - Active mode: open or inspect the target with Browser, Chrome, Playwright, or
    a verified explicit nils-cli browser driver, then record the action and
    artifact paths with `browser-session record-step`.
  - Verify recorded evidence with
    `browser-session verify --out <run-dir>/browser-session --format json`.
- Artifact contract: static mode retains redacted `web-evidence` bundles; active
  mode retains redacted screenshots, DOM observations, console summaries,
  network summaries, traces, or equivalent browser artifacts.
- Version floor: `web-qa` relies on `web-evidence` and `browser-session` from
  `nils-cli 0.8.4` or newer when those evidence records are used.
- Scope boundary: `web-qa` chooses and documents browser evidence. It does not
  add skill-local scripts, persist raw cookies or credentials, bypass MFA/CAPTCHA
  or access controls, or replace project-owned E2E tests.

## Edit-scope locks

- Create, read, validate, and clear deterministic edit-scope locks for agent
  workflows:
  - Skill contract: `skills/tools/scope/agent-scope-lock/SKILL.md`
  - `agent-scope-lock create --path <repo-relative-path> [--path <path> ...]`
  - `agent-scope-lock validate --changes all --format json`
  - `agent-scope-lock read --format json`
  - `agent-scope-lock clear`
- Version floor: requires `nils-cli 0.8.4` or newer with the
  `nils-agent-scope-lock` package on PATH.
- Local checkout boundary: when PATH is absent or reports an older `nils-cli`,
  consume the same command surface only through a validated local `nils-cli`
  checkout, for example `cargo run --locked --manifest-path
  /path/to/nils-cli/Cargo.toml -p nils-agent-scope-lock --bin
  agent-scope-lock -- <subcommand> ...` from the target git work tree.

## Test-first evidence

- Record deterministic test-first evidence or waivers for agent workflows:
  - Skill contract: `skills/tools/workflow-evidence/test-first-evidence/SKILL.md`
  - `test-first-evidence init --out <dir> --classification <classification>`
  - `test-first-evidence record-failing --out <dir> --command <command> --exit-code <code> --summary <summary>`
  - `test-first-evidence record-waiver --out <dir> --reason <reason>`
  - `test-first-evidence record-final --out <dir> --command <command> --status pass|fail`
  - `test-first-evidence verify --out <dir> --format json`
  - `test-first-evidence show --out <dir> --format json`
- Artifact contract: `test-first-evidence.json` under the requested output
  directory, with record schema `test-first-evidence.record.v1`.
- Version floor: requires `nils-cli 0.8.4` or newer with the
  `nils-test-first-evidence` package on PATH.
- Local checkout boundary: when PATH is absent or reports an older `nils-cli`,
  consume the same command surface only through a validated local `nils-cli`
  checkout, for example `cargo run --locked --manifest-path
  /path/to/nils-cli/Cargo.toml -p nils-test-first-evidence --bin
  test-first-evidence -- <subcommand> ...`.

## Agent workflow primitives

- Record and verify deterministic workflow evidence through the
  `nils-agent-workflow-primitives` package:
  - Skill contracts:
    - `skills/tools/browser/evidence/browser-session/SKILL.md`
    - `skills/tools/workflow-evidence/canary-check/SKILL.md`
    - `skills/tools/workflow-evidence/docs-impact/SKILL.md`
    - `skills/tools/workflow-evidence/model-cross-check/SKILL.md`
    - `skills/tools/workflow-evidence/review-evidence/SKILL.md`
    - `skills/tools/workflow-evidence/skill-usage/SKILL.md`
  - `browser-session init|record-step|verify|show`
  - `canary-check run|verify|show`
  - `docs-impact scan`
  - `model-cross-check init|record-observation|verify|show`
  - `review-evidence init|record-finding|record-validation|verify|show`
  - `skill-usage init|link-record|record-failure|record-validation|record-outcome|verify|show`
- Artifact contracts:
  - `browser-session.json` with record schema `browser-session.record.v1`.
  - `canary-check.json` with record schema `canary-check.record.v1`.
  - `model-cross-check.json` with record schema `model-cross-check.record.v1`.
  - `review-evidence.json` with record schema `review-evidence.record.v1`.
  - `skill-usage.record.json` with record schema `skill-usage.record.v1`.
  - `docs-impact` emits JSON scan results and does not write project files.
- Version floor: requires `nils-cli 0.8.4` or newer with the
  `nils-agent-workflow-primitives` package on PATH.
- Local checkout boundary: when PATH is absent or reports an older `nils-cli`,
  consume the same command surfaces only through a validated local `nils-cli`
  checkout, for example `cargo run --locked --manifest-path
  /path/to/nils-cli/Cargo.toml -p nils-agent-workflow-primitives --bin
  docs-impact -- scan --format json`.
