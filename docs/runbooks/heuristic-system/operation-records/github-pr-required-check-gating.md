# GitHub PR Required Check Gating Operation Record

## Status

- Date: 2026-05-18
- Status: implemented and validated
- System area: GitHub PR delivery workflows
- Durable fix paths:
  - `skills/workflows/pr/github/_shared/lib/github-pr-checks.bash`
  - `skills/workflows/pr/github/deliver-github-pr/scripts/deliver-github-pr.sh`
  - `skills/workflows/pr/github/close-github-pr/scripts/close-github-pr.sh`

## Signal

A real `deliver-github-pr` run for `nils-cli` PR #370 completed successfully only
after manually working around the agent-kit delivery scripts. The scripts treated
an optional skipped `coverage_badge` job as a hard failure even though required
checks were sufficient to merge.

## Evidence

Retained local evidence:

- `/Users/terry/.config/agent-kit/out/projects/sympoies__nils-cli/20260518-013331-skill-usage/skill-usage.record.json`

Relevant evidence summary:

- `deliver-github-pr wait-checks --pr 370` returned failure while required checks
  were still converging and no required check had failed.
- `deliver-github-pr close --pr 370` rejected the PR after required checks had
  passed because the optional `coverage_badge` job was skipped.
- Manual `gh pr ready` and `gh pr merge` succeeded after required checks were
  verified.

## Diagnosis

The delivery scripts used one all-checks classifier for both required and
optional GitHub check runs. That made optional skipped jobs indistinguishable
from skipped required checks.

The same logic existed in both `deliver-github-pr` and `close-github-pr`, so a
partial fix in only one workflow would still leave delivery blocked.

## Promotion Decision

This was promoted as a HEURISTIC_SYSTEM operation case because it was:

- observed during a real high-impact workflow;
- reproducible with a local `gh` stub and focused tests;
- narrow enough to fix safely;
- valuable as proof that retained evidence can become tests, scripts, skill
  policy, and an operation record.

## Durable Fix

- Added focused regression tests for required checks passing while optional
  `coverage_badge` is skipped.
- Extended the `gh` test stub to simulate `gh pr checks --required`.
- Moved GitHub PR check classification into a shared helper.
- Updated both PR delivery scripts to gate on required checks first and fall
  back to existing all-checks behavior when no required checks are configured.
- Updated GitHub PR workflow skill docs to state the required-vs-optional check
  policy.
- Added this operation record and root HEURISTIC_SYSTEM guidance for future
  retained-evidence promotion.

## Validation

Current validation:

- `scripts/check.sh --tests -- -k 'github_pr and (deliver or close)'`: pass
- `scripts/check.sh --markdown`: pass
- `scripts/check.sh --docs`: pass
- `bash scripts/ci/stale-skill-scripts-audit.sh --check`: pass
- `scripts/check.sh --entrypoint-ownership`: pass
- `scripts/check.sh --all`: pass, 729 pytest tests passed

The full gate runs in the normal shell after `agent-doc-init` test isolation was
fixed to clear ambient resolver variables before each test injects explicit
values.

## Retention

- Raw skill usage records remain in `out/` and are not committed as normal repo
  artifacts.
- The temporary execution source under
  `docs/plans/heuristic-system-first-operation-case/` can be removed after
  implementation if this operation record and regression tests retain the useful
  lesson.
- This operation record remains as the durable repo-local proof that the
  HEURISTIC_SYSTEM loop operated on a real workflow failure.
