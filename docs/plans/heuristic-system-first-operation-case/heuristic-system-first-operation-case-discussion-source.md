# Heuristic System First Operation Case Implementation Handoff

## Status

- Date: 2026-05-18
- Source type: discussion-to-implementation-doc
- Status: ready for implementation planning
- Intended next step: use this source to implement the first complete
  HEURISTIC_SYSTEM operating loop case.
- Recommended execution state:
  `docs/plans/heuristic-system-first-operation-case/heuristic-system-first-operation-case-execution-state.md`

## Purpose

Use the `deliver-github-pr` required-check gating bug as the first real
HEURISTIC_SYSTEM improvement case. The implementation should both fix the
workflow bug and leave a curated repo-local record proving that the heuristic
system operated end to end:

1. Capture a real workflow failure from retained evidence.
2. Diagnose the root cause from concrete artifacts.
3. Promote the lesson into code, tests, skill policy, or runbook guidance.
4. Record the outcome without committing raw runtime logs.
5. Compress temporary coordination material once the durable lesson exists.

## Confirmed Facts

- `HEURISTIC_SYSTEM.md` already defines agent-kit as an agent-facing heuristic
  system made of skills, scripts, runbooks, evidence records, tests, and
  guardrails.
- `HEURISTIC_SYSTEM.md` defines a core loop for new operational knowledge:
  run the skill, capture results, diagnose failures, fix or work around the
  issue, promote durable lessons, then compress accumulated notes.
- `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md` defines
  `skill-usage.record.v1`, including failure records, linked evidence, a
  promotion ladder, and compression guidance.
- A real `deliver-github-pr` execution produced a retained skill usage record at
  `/Users/terry/.config/agent-kit/out/projects/sympoies__nils-cli/20260518-013331-skill-usage/skill-usage.record.json`.
- That record documents a worked-around script bug: `deliver-github-pr`
  `wait-checks` and `close` blocked on an optional skipped `coverage_badge`
  job even though required checks were green enough to merge safely.
- The same check-classification logic exists in both:
  - `skills/workflows/pr/github/deliver-github-pr/scripts/deliver-github-pr.sh`
  - `skills/workflows/pr/github/close-github-pr/scripts/close-github-pr.sh`
- This handoff is documentation only. It does not implement the bug fix.

## Decisions

- Treat this as a HEURISTIC_SYSTEM pilot, not as a standalone bug fix.
- Keep raw `skill-usage.record.json` in `out/` as local evidence; do not commit
  the raw runtime record by default.
- Create a curated operation record in repo after implementation to prove the
  system actually ran.
- Keep the operation record concise and verifiable. It should summarize the
  signal, evidence, diagnosis, promotion decision, durable fix, validation, and
  retention outcome.
- Use tests and script behavior as the durable lesson. The operation record
  proves the loop happened; it must not become a replacement for regression
  coverage.

## Scope

- Fix GitHub PR delivery gating for required vs optional checks.
- Use the fix as the first complete HEURISTIC_SYSTEM operation case.
- Add or update tests that reproduce the optional skipped check failure.
- Add a curated operation record under a durable docs/runbooks location.
- Add minimal HEURISTIC_SYSTEM guidance so future agents know how to convert
  retained workflow evidence into durable improvements.

## Non-Scope

- Do not change `nils-cli`; the observed issue is in agent-kit delivery tooling.
- Do not redesign all skill usage recording.
- Do not commit raw `out/` records as normal repo artifacts.
- Do not add a large incident-report system.
- Do not create a broad top-level docs area unless the implementation proves it
  is needed.
- Do not treat this handoff as a detailed sprint plan; use `create-plan` if
  phased execution is needed.

## Implementation Boundaries

### GitHub PR Check Gating

The bug fix should update both `deliver-github-pr` and `close-github-pr`.
Required checks should be the merge gate. Optional checks should be summarized
but must not block delivery when skipped.

Recommended behavior:

- Required checks passed: allow `wait-checks` / `close` to proceed, even if
  optional checks are skipped.
- Required checks pending: keep waiting or block close.
- Required checks failed, canceled, timed out, action-required, blocked, or
  skipped: block merge.
- No required checks found:
  - If all checks are missing, keep existing `--allow-no-checks` behavior.
  - If the repo has checks but no branch-protection-required checks, decide
    whether to fall back to all-checks gating or require an explicit
    acknowledgement. Preserve conservative behavior unless tests justify the
    change.

### Shared Classifier

The two GitHub PR scripts currently duplicate check-classification logic.
Prefer a shared helper or a single reusable classifier path so future check
state fixes cannot drift between wait and close flows.

### Operation Record

Add a curated operation record after the fix lands. Recommended path:

`heuristic-system/operation-records/github-pr-required-check-gating.md`

The operation record should include:

- Signal: the real `deliver-github-pr` run misclassified optional
  `coverage_badge` as a hard block.
- Evidence: link or cite the local retained record path and summarize the
  relevant failure fields; do not copy raw JSON wholesale.
- Diagnosis: required and optional GitHub checks were not separated.
- Promotion decision: this is a reproducible workflow bug and a first
  HEURISTIC_SYSTEM pilot.
- Durable fix: scripts, tests, and skill policy updated.
- Validation: focused tests and `scripts/check.sh --all`.
- Retention: raw record remains local, this source doc can be cleaned up after
  execution, operation record remains as proof of system operation.

## Requirements

- `deliver-github-pr wait-checks` must not fail only because an optional check is
  skipped while required checks have passed.
- `deliver-github-pr close` must not fail only because an optional check is
  skipped while required checks have passed.
- Required skipped checks must still block.
- Required pending checks must still wait or block close.
- Required failed checks must still block.
- Repos with no checks must still require `--allow-no-checks` unless the
  implementation explicitly preserves an equivalent conservative gate.
- The HEURISTIC_SYSTEM operation record must prove the loop without becoming a
  raw log archive.
- Temporary plan-source docs should remain cleanup-friendly.

## Acceptance Criteria

- Focused tests cover:
  - required pass plus optional skipped `coverage_badge` passes;
  - required pending plus optional skipped remains pending or blocked;
  - required failed blocks;
  - required skipped blocks;
  - missing checks still require `--allow-no-checks`.
- `tests/stubs/bin/gh` supports the required-check test scenarios without
  depending on live GitHub.
- The duplicated check classifier is removed or deliberately kept in sync with a
  documented reason.
- `deliver-github-pr` and `close-github-pr` skill docs describe required vs
  optional check policy.
- A curated HEURISTIC_SYSTEM operation record exists in repo.
- `HEURISTIC_SYSTEM.md` or the skill usage runbook explains when to create an
  operation record from retained evidence.
- Validation passes with the focused PR workflow tests and the repo-required
  docs/check gate.

## Validation Plan

Recommended commands:

```bash
scripts/check.sh --tests -- -k 'github_pr and (deliver or close)'
scripts/check.sh --markdown
scripts/check.sh --all
```

If implementation changes skill entrypoint scripts or smoke specs, also run the
entrypoint drift guards from `DEVELOPMENT.md`.

## Risks And Guardrails

- Do not weaken merge safety by allowing failed required checks through.
- Do not infer required status from optional check names such as
  `coverage_badge`; use GitHub required-check evidence when available.
- Do not hide optional check status. Summaries should still show skipped or
  failed optional checks as non-blocking context.
- Do not make the operation record too verbose. It should be a curated proof of
  learning, not a raw transcript.
- Do not promote this one case into broad policy until the implementation proves
  the shape is useful.

## Execution

- Execution source:
  `docs/plans/heuristic-system-first-operation-case/heuristic-system-first-operation-case-discussion-source.md`
- Recommended execution state:
  `docs/plans/heuristic-system-first-operation-case/heuristic-system-first-operation-case-execution-state.md`
- Starting status: not started
- Suggested next task source:
  1. Add failing regression tests for required pass plus optional skipped check.
  2. Fix shared GitHub PR check classification.
  3. Update skill docs and HEURISTIC_SYSTEM guidance.
  4. Add curated operation record.
  5. Validate and run docs cleanup decision.

## Retention Intent

This source document should be retained during implementation. After the bug fix,
operation record, and guidance updates are complete, this plan-source document
can be removed by `docs-plan-cleanup` unless it is still needed for audit or
follow-up work.

The curated operation record should remain in repo as the durable proof that the
HEURISTIC_SYSTEM loop operated on a real workflow failure.

## Resolved Implementation Decisions

- Repos with no required checks fall back to the existing all-checks gate. Repos
  with no checks still require explicit `--allow-no-checks`.
- Operation records live under
  `heuristic-system/operation-records/`.
- `HEURISTIC_SYSTEM.md` owns the short operation-record concept and location;
  `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md` continues to own raw
  `skill-usage.record.v1` mechanics.

## Read First References

- `HEURISTIC_SYSTEM.md`
- `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`
- `skills/workflows/pr/github/deliver-github-pr/SKILL.md`
- `skills/workflows/pr/github/close-github-pr/SKILL.md`
- `skills/workflows/pr/github/deliver-github-pr/scripts/deliver-github-pr.sh`
- `skills/workflows/pr/github/close-github-pr/scripts/close-github-pr.sh`
- `/Users/terry/.config/agent-kit/out/projects/sympoies__nils-cli/20260518-013331-skill-usage/skill-usage.record.json`

## Recommended Next Artifact

Use `execute-from-implementation-doc` directly if the next session should start
implementation from this source. Use `create-plan` only if the work should first
be split into explicit phases, task groups, or PR boundaries.
