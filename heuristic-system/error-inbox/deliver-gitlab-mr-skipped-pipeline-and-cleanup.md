# Deliver GitLab MR Skipped Pipeline And Cleanup Gaps

## Status

- Status: promoted
- First observed: 2026-05-18
- Area: GitLab MR delivery skills
- Severity: high
- GitLab MR workflow status: complete

## Signal

A real `deliver-gitlab-mr` delivery for
`gim/backend/livekit-agents!103` succeeded only after manual judgment and
cleanup. The source branch pipeline was skipped by repo CI rules, while GitLab
MR merge checks showed the MR was mergeable after leaving draft state. The
delivery workflow still blocked on source-branch pipeline gating, then the close
script merged successfully but failed local cleanup.

This entry covers the GitLab MR skill bugs exposed by retained delivery
evidence. The defects are now fixed and validated.

## Evidence

- Raw record: `/Users/terry/.config/agent-kit/out/projects/backend__livekit-agents/20260518-150327-skill-usage/skill-usage.record.json`
- MR: `https://gitlab.gamania.com/gim/backend/livekit-agents/-/merge_requests/103`
- Source-branch pipeline:
  `https://gitlab.gamania.com/gim/backend/livekit-agents/-/pipelines/308909`
- Post-merge `test` pipeline:
  `https://gitlab.gamania.com/gim/backend/livekit-agents/-/pipelines/308915`
- Agent-kit delivery PR:
  `https://github.com/graysurf/agent-kit/pull/254`
- Live acceptance MR:
  `https://gitlab.gamania.com/gim/backend/livekit-agents/-/merge_requests/104`
- Live acceptance source pipeline:
  `https://gitlab.gamania.com/gim/backend/livekit-agents/-/pipelines/308998`

Relevant evidence summary:

- `deliver-gitlab-mr.sh --kind feature wait-pipeline --mr 103` failed with
  `failed to parse pipeline status` and printed `PIPELINE_STATUS=` even though
  `glab ci status --branch feat/reservation-graph-router-resilience --output json`
  contained `pipeline.status=skipped`.
- GitLab MR metadata showed `merge_status=can_be_merged` and
  `detailed_merge_status=draft_status`; the only UI blocking check was
  `Merge request must not be draft`.
- `.gitlab-ci.yml` in `livekit-agents` only runs `build:service` on `main`,
  `test`, and `stg`. Feature branches only get the manual, allow-failure
  `copy-image` job, so their pipeline is expected to be skipped.
- `deliver-gitlab-mr.sh --kind feature close --mr 103 --skip-pipeline` marked
  the MR ready and merged it, then exited during local cleanup with
  `fatal: Cannot rebase onto multiple branches`.
- Manual cleanup succeeded with:
  `git fetch origin test && git merge --ff-only origin/test && git branch -d feat/reservation-graph-router-resilience`.
- Live acceptance MR `!104` targeted a temporary non-deploy branch,
  `agent-kit-gitlab-mr-smoke-target`, to avoid merging smoke content into
  `test`, `main`, `stg`, or `prod`.
- `deliver-gitlab-mr.sh --kind docs wait-pipeline --mr 104` reported
  `PIPELINE_STATUS=skipped` and blocked with the documented target-branch CI
  guidance, proving the nested GitLab JSON was parsed instead of failing with an
  empty status.
- `deliver-gitlab-mr.sh --kind docs close --mr 104 --skip-pipeline` marked the
  draft MR ready, merged it, fast-forwarded the temporary target branch from
  `origin/<target>`, and deleted the local source branch.
- Temporary remote branches `docs/agent-kit-gitlab-mr-smoke` and
  `agent-kit-gitlab-mr-smoke-target` were deleted after validation.

## Impact

Future GitLab MR deliveries can be blocked or reported incorrectly when a repo
uses target-branch CI rather than source-branch CI. This matters for deployment
branches such as `test`, where the meaningful build/deploy pipeline starts only
after merge.

The cleanup failure also makes a successful merge look like a failed delivery
unless the agent verifies MR state and repairs the local checkout. Without a
durable inbox entry, this failure would remain only in local `out/` evidence and
could be lost during cleanup.

The GitLab MR delivery impact is resolved in agent-kit.

## Current Workaround

No GitLab MR workaround remains after PR #254 and live MR !104 validation.
Continue using explicit `--skip-pipeline` only for user-confirmed target-branch
CI models.

## Verified Behavior

- GitLab MR source-branch `skipped`, `manual`, `blocked`, and
  `action_required` pipeline states remain blocked by default.
- For repos whose meaningful CI runs on target branches, `--skip-pipeline` is
  still an explicit user-confirmed merge control, not a default.
- Close cleanup uses explicit fetch plus fast-forward:
  `git fetch origin <target>` and `git merge --ff-only origin/<target>`.

## Findings

| Priority | Issue | Evidence | Likely fix location | Acceptance |
| --- | --- | --- | --- | --- |
| P1 | `deliver-gitlab-mr` does not parse `pipeline.status` from `glab ci status --output json`. | `pipeline.status=skipped` existed, but script reported parse failure. | `skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh`; likely shared with `close-gitlab-mr.sh`. | Stubbed tests cover JSON shaped as `{ "pipeline": { "status": "skipped" }, "jobs": [...] }`; script reports skipped/manual as a policy block, not a parse error. |
| P1 | GitLab delivery policy assumes source-branch pipeline must be green, which does not fit repos whose meaningful CI runs only on target branches. | `livekit-agents` feature branch only had manual `copy-image`; post-merge `test` pipeline started `build:service`. | `deliver-gitlab-mr` and `close-gitlab-mr` skill docs/scripts. | Workflow distinguishes missing/skipped source CI from GitLab mergeability and supports an explicit target-branch CI model with user-confirmed `--skip-pipeline`. |
| P2 | `close` workflow merged the MR but failed local cleanup under repo git config. | Close output: merge succeeded, then `fatal: Cannot rebase onto multiple branches`; manual fetch + ff succeeded. | `skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh`. | Cleanup uses deterministic `git fetch origin <target>` plus `git merge --ff-only origin/<target>` or equivalent, and tests cover problematic local pull config. |

GitLab MR findings P1/P2 are fixed and accepted by focused tests, full repo
validation, PR #254, and live acceptance MR !104.

## GitLab MR Backlog

- Done: parse nested GitLab pipeline status JSON in both GitLab MR scripts.
- Done: add focused tests for top-level and nested pipeline payloads.
- Done: keep skipped/manual source CI blocked by default and document explicit
  target-branch CI / `--skip-pipeline` handling.
- Done: replace ambiguous local cleanup with deterministic fetch plus
  fast-forward cleanup.
- Done: validate the fixed workflow with live GitLab MR !104.

## Promotion Criteria

The GitLab MR portion of this inbox entry is complete when all of these are
true:

- GitLab MR pipeline status parsing has focused tests and script fixes.
- Close cleanup has a regression test for the local pull/ff failure mode.
- Skill docs explain target-branch CI / skipped source-branch CI handling.
- `scripts/check.sh --tests -- -k 'gitlab_mr and (deliver or close)'` and the
  relevant docs/markdown checks pass.
- A live GitLab MR validates skipped source pipeline parsing, explicit
  `--skip-pipeline`, ready transition, merge, and local cleanup.

## Next Action

None. The GitLab MR workflow gap is resolved by PR #254 and live MR !104
validation.

Lifecycle link: `docs/plans/gitlab-mr-pipeline-cleanup/gitlab-mr-pipeline-cleanup-plan.md`

Lifecycle link: `docs/plans/gitlab-mr-pipeline-cleanup/gitlab-mr-pipeline-cleanup-execution-state.md`
