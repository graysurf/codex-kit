# Agent-Docs Rollout Checklist

## Preflight

1. Validate startup and context docs:
   - `agent-docs resolve --context startup --strict --format checklist`
   - `agent-docs resolve --context task-tools --strict --format checklist`
   - `agent-docs resolve --context project-dev --strict --format checklist`
   - `agent-docs resolve --context skill-dev --strict --format checklist`
2. Validate baseline coverage:
   - `agent-docs baseline --check --target home --strict --format text`
3. Validate trial evidence exists:
   - `test -f out/agent-docs-rollout/trial-results.json`
   - `test -f out/agent-docs-rollout/trial-summary.md`

## Staged rollout order

1. Stage 1: home-level rollout
   - ensure `AGENTS.md`, `AGENTS.override.md`, and `AGENT_DOCS.toml` are aligned.
   - run `agent-doc-init --dry-run` for representative repos.
2. Stage 2: project-level rollout
   - apply project `AGENT_DOCS.toml` changes only where needed.
   - verify strict preflight per project.
3. Stage 3: operator handoff
   - publish `rollout-gate.md`, `rollout-checklist.md`, and `rollback-operations.md`.

## Monitoring checkpoints

1. Check pass rate and go/no-go threshold from trial summary.
2. Verify command trace completeness is 100%.
3. Confirm no unexpected strict failures in daily runs.
4. Track operator corrections and compare with baseline.

## nils-cli branch point

- Use `docs/runbooks/agent-docs/nils-cli-adoption-decision.md` as the branch decision:
  1. If only project-level extension is required, keep `nils-cli/AGENTS.md` unchanged.
  2. If local portability becomes mandatory, schedule a separate `nils-cli/AGENTS.md` dispatcher update.

## Exit criteria

1. Rollout gate decision is `go`.
2. All preflight checks pass in both home and selected project scopes.
3. Rollback runbook is reviewed and executable by another engineer.
