# Docs Freshness Rules

## Purpose

- Define the initial scope and deterministic checks for `scripts/ci/docs-freshness-audit.sh`.
- Keep command/path drift detection focused on high-impact docs referenced by contributors and CI workflows.

## Scope

The helper audits these docs for command/path freshness:

- `README.md`
- `DEVELOPMENT.md`
- `docs/runbooks/agent-docs/context-dispatch-matrix.md`
- `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
- `docs/testing/script-regression.md`
- `docs/testing/script-smoke.md`

## Rule Coverage

The helper enforces four rule classes:

- `DOC`: scoped documents that must exist.
- `REQUIRED_COMMAND`: exact command claims that must remain documented in scope.
- `REQUIRED_PATH`: critical repo paths that must both exist and be referenced in scope.
- `ALLOW_MISSING_PATH`: explicit false-positive suppression for known environment/example-only paths.

In addition to explicit rules, the helper scans scoped docs for repo-local command/path references under:

- `scripts/...`
- `$AGENT_HOME/scripts/...`
- `skills/**/scripts/...`
- `$AGENT_HOME/skills/**/scripts/...`

Any discovered reference to a missing path is reported as a stale reference.

## False-Positive Policy

- Keep the default scope strict: only allow missing paths when examples intentionally reference non-repo locations.
- Prefer fixing docs over suppressing findings.
- When suppression is unavoidable, add a targeted `ALLOW_MISSING_PATH|...` entry with an explanatory note in the PR.
- Revisit allowlist entries during docs maintenance and remove stale suppressions quickly.

## Machine-Readable Rules

The audit script parses only the block below.

<!-- markdownlint-disable MD075 -->
<!-- docs-freshness-audit:begin -->
## Scoped docs

DOC|README.md
DOC|DEVELOPMENT.md
DOC|docs/runbooks/agent-docs/context-dispatch-matrix.md
DOC|docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md
DOC|docs/testing/script-regression.md
DOC|docs/testing/script-smoke.md

## Required commands

REQUIRED_COMMAND|scripts/check.sh --all
REQUIRED_COMMAND|scripts/check.sh --tests -- -m script_smoke
REQUIRED_COMMAND|agent-docs --docs-home "$AGENT_HOME" resolve --context startup --strict --format checklist
REQUIRED_COMMAND|agent-docs --docs-home "$AGENT_HOME" baseline --check --target all --strict --format text
REQUIRED_COMMAND|bash scripts/ci/stale-skill-scripts-audit.sh --check
REQUIRED_COMMAND|$AGENT_HOME/scripts/test.sh -m script_smoke

## Required critical paths

REQUIRED_PATH|scripts/check.sh
REQUIRED_PATH|scripts/ci/stale-skill-scripts-audit.sh
REQUIRED_PATH|scripts/ci/third-party-artifacts-audit.sh
REQUIRED_PATH|scripts/check_plan_issue_worktree_cleanup.sh
REQUIRED_PATH|scripts/test.sh
REQUIRED_PATH|skills/tools/agent-doc-init/scripts/agent_doc_init.sh
REQUIRED_PATH|docs/testing/script-smoke.md
<!-- docs-freshness-audit:end -->
<!-- markdownlint-enable MD075 -->
