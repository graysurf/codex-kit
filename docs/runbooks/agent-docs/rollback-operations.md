# Agent-Docs Rollback Operations

## Scope

- Command-level rollback procedure for `agent-docs` dispatcher rollout.
- Includes evidence collection requirements before and after rollback.

## Trigger conditions

1. Preflight regressions:
   - startup/task-tools/project-dev/skill-dev strict resolves fail unexpectedly.
2. Safety regressions:
   - `agent-doc-init` behaves destructively without explicit `--force`.
3. Operational regressions:
   - rollout gate flips to `no-go`.

## Immediate rollback steps

1. Capture incident evidence:
   - `agent-docs baseline --check --target all --strict --format text > out/agent-docs-rollout/rollback-baseline-before.txt`
   - `agent-docs resolve --context startup --strict --format checklist > out/agent-docs-rollout/rollback-startup-before.txt`
2. Revert dispatcher-oriented policy files to last known good revision.
3. Remove newly introduced extension entries in `AGENT_DOCS.toml` when they are the regression source.
4. Disable bootstrap guidance references if rollback requires temporary deactivation:
   - remove `agent-doc-init` startup references in AGENTS/README.
5. Re-run strict checks:
   - `agent-docs baseline --check --target all --strict --format text`
   - `agent-docs resolve --context startup --strict --format checklist`

## Project rollback (`nils-cli`)

1. If project-level extension is unstable, remove or revert `/Users/terry/Project/graysurf/nils-cli/AGENT_DOCS.toml`.
2. Validate project strict baseline:
   - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli baseline --check --target project --strict --format text`
3. Keep `nils-cli/AGENTS.md` unchanged unless a dedicated policy PR is approved.

## Post-rollback evidence requirements

1. Save outputs:
   - `out/agent-docs-rollout/rollback-baseline-after.txt`
   - `out/agent-docs-rollout/rollback-startup-after.txt`
2. Document decision:
   - include root cause, rollback commands, owner, and next remediation date.
3. Archive failed trial artifacts:
   - `out/agent-docs-rollout/failed-<date>/`
