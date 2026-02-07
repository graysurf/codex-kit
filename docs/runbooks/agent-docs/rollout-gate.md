# Agent-Docs Rollout Gate

## Scope

- Defines objective go/no-go thresholds for rollout after Sprint 5 trials.
- Applies to home-level and project-level rollout sequence.

## go/no-go thresholds

1. Trial pass rate threshold:
   - `>= 95%`
2. Command trace completeness threshold:
   - `100%` of scenarios must include non-empty command traces.
3. Hard failure threshold:
   - `0` unexpected hard failures.
4. Missing-doc control threshold:
   - Missing-doc scenario must fail deterministically in strict mode.
5. Auto-init threshold:
   - Auto-init scenario must pass strict baseline verification after apply.

## Decision matrix

- `go`:
  - all thresholds above pass.
- `no-go`:
  - any threshold fails.
  - rollout is blocked until remediation is complete and trials are rerun.

## Rollback trigger criteria

- Trigger rollback immediately when any of the following occurs after rollout:
  1. Required-doc preflight is skipped in production workflows.
  2. Strict resolve behavior becomes non-deterministic across repeated runs.
  3. `agent-doc-init` introduces destructive overwrite without explicit `--force`.
  4. Operator correction rate rises above baseline guardrails.

## Evidence inputs

- Trial raw results: `out/agent-docs-rollout/trial-results.json`
- Trial summary: `out/agent-docs-rollout/trial-summary.md`
- Pilot decision: `docs/runbooks/agent-docs/nils-cli-adoption-decision.md`
