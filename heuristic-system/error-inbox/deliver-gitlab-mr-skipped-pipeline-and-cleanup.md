# Deliver GitLab MR Skipped Pipeline And Cleanup Gaps

## Status

- Status: planned
- First observed: 2026-05-18
- Area: GitLab MR delivery skills / heuristic-system retention
- Severity: high

## Signal

A real `deliver-gitlab-mr` delivery for
`gim/backend/livekit-agents!103` succeeded only after manual judgment and
cleanup. The source branch pipeline was skipped by repo CI rules, while GitLab
MR merge checks showed the MR was mergeable after leaving draft state. The
delivery workflow still blocked on source-branch pipeline gating, then the close
script merged successfully but failed local cleanup.

This is a useful HEURISTIC_SYSTEM case because it exposed both unresolved
GitLab MR skill bugs and a missing promotion flow from retained `skill-usage`
evidence into `error-inbox/`.

## Evidence

- Raw record: `/Users/terry/.config/agent-kit/out/projects/backend__livekit-agents/20260518-150327-skill-usage/skill-usage.record.json`
- Corrupted raw record from an unsafe parallel write:
  `/Users/terry/.config/agent-kit/out/projects/backend__livekit-agents/20260518-145727-skill-usage/skill-usage.record.json`
- MR: `https://gitlab.gamania.com/gim/backend/livekit-agents/-/merge_requests/103`
- Source-branch pipeline:
  `https://gitlab.gamania.com/gim/backend/livekit-agents/-/pipelines/308909`
- Post-merge `test` pipeline:
  `https://gitlab.gamania.com/gim/backend/livekit-agents/-/pipelines/308915`

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
- The first `skill-usage.record.json` was corrupted by concurrent writes from
  multiple `skill-usage` commands. A second record was created serially and
  verified.

## Impact

Future GitLab MR deliveries can be blocked or reported incorrectly when a repo
uses target-branch CI rather than source-branch CI. This matters for deployment
branches such as `test`, where the meaningful build/deploy pipeline starts only
after merge.

The cleanup failure also makes a successful merge look like a failed delivery
unless the agent verifies MR state and repairs the local checkout. Without a
durable inbox entry, this failure would remain only in local `out/` evidence and
could be lost during cleanup.

The missing promotion flow means high-impact workflow gaps are recorded in
`skill-usage`, but they are not automatically turned into curated
`error-inbox/` entries. Agents must currently remember to do this manually.

## Current Workaround

- For `livekit-agents` style GitLab repos where feature branches only have a
  skipped/manual pipeline, verify GitLab MR merge checks directly before using
  `--skip-pipeline`.
- Treat `--skip-pipeline` as a user-confirmed merge control, not a default.
- After merge, if the close script fails during cleanup, verify MR state through
  `glab mr view`, then use an explicit fast-forward cleanup:
  `git fetch origin <target> && git merge --ff-only origin/<target>`.
- Do not run multiple `skill-usage` write commands in parallel against the same
  record directory.

## Findings

| Priority | Issue | Evidence | Likely fix location | Acceptance |
| --- | --- | --- | --- | --- |
| P1 | `deliver-gitlab-mr` does not parse `pipeline.status` from `glab ci status --output json`. | `pipeline.status=skipped` existed, but script reported parse failure. | `skills/workflows/mr/gitlab/deliver-gitlab-mr/scripts/deliver-gitlab-mr.sh`; likely shared with `close-gitlab-mr.sh`. | Stubbed tests cover JSON shaped as `{ "pipeline": { "status": "skipped" }, "jobs": [...] }`; script reports skipped/manual as a policy block, not a parse error. |
| P1 | GitLab delivery policy assumes source-branch pipeline must be green, which does not fit repos whose meaningful CI runs only on target branches. | `livekit-agents` feature branch only had manual `copy-image`; post-merge `test` pipeline started `build:service`. | `deliver-gitlab-mr` and `close-gitlab-mr` skill docs/scripts. | Workflow distinguishes missing/skipped source CI from GitLab mergeability and supports an explicit target-branch CI model with user-confirmed `--skip-pipeline`. |
| P2 | `close` workflow merged the MR but failed local cleanup under repo git config. | Close output: merge succeeded, then `fatal: Cannot rebase onto multiple branches`; manual fetch + ff succeeded. | `skills/workflows/mr/gitlab/close-gitlab-mr/scripts/close-gitlab-mr.sh`. | Cleanup uses deterministic `git fetch origin <target>` plus `git merge --ff-only origin/<target>` or equivalent, and tests cover problematic local pull config. |
| P2 | High-impact skill failures are retained as `skill-usage` records but not promoted into `error-inbox/`. | User had to ask whether the GitLab MR skill failure should be placed under `heuristic-system/error-inbox/`. | New workflow/skill such as `heuristic-error-inbox`; high-impact skill failure handling docs. | A command or workflow converts a verified `skill-usage.record.json` into a curated inbox entry using the README template. |
| P3 | `skill-usage` records can be corrupted by parallel writes. | First record had duplicated trailing JSON after parallel `skill-usage` commands. | `skill-usage` docs and/or CLI locking behavior. | Docs say writes to one record must be serial, or CLI uses file locking / atomic update tests. |

## Heuristic-System Gap

`heuristic-system/error-inbox/README.md` defines when to create
entries, but there is no workflow that helps an agent promote a real
`skill-usage` failure into a curated inbox document.

The missing flow should cover:

- Input: a verified `skill-usage.record.json`.
- Classification: identify `script-bug`, `skill-contract`, delivery gate
  failures, merge/release safety failures, and `worked-around` outcomes.
- Deduplication: update an existing inbox entry when the same failure class
  already exists.
- Output: a redacted, curated
  `heuristic-system/error-inbox/<slug>.md` entry.
- Guardrails: never copy raw terminal logs or secrets; link raw records and
  summarize the failure.
- Lifecycle: mark entries `promoted` after scripts, tests, skill docs, or
  operation records fix the gap.

## Backlog

- Fix `pipeline_status_from_json` in the GitLab MR scripts to read
  `pipeline.status` and `pipeline.detailed_status.group`.
- Add tests for `glab ci status --output json` payloads with top-level
  `pipeline` and nested `jobs[].pipeline` fields.
- Decide and document GitLab delivery behavior for repos whose source branch CI
  is intentionally skipped but whose target branch pipeline runs after merge.
- Fix close cleanup to avoid ambiguous `git pull` behavior under repo-local git
  config.
- Add a `heuristic-error-inbox` workflow/skill, or extend
  `review-to-improvement-doc`, to create/update inbox entries from verified
  `skill-usage` evidence.
- Add a `skill-usage` guardrail: do not run multiple write commands against the
  same record in parallel; consider CLI-side locking if the primitive owns this
  guarantee.

## Promotion Criteria

Promote this inbox entry to an operation record when all of these are true:

- GitLab MR pipeline status parsing has focused tests and script fixes.
- Close cleanup has a regression test for the local pull/ff failure mode.
- Skill docs explain target-branch CI / skipped source-branch CI handling.
- The heuristic-system has a documented and validated inbox promotion workflow.
- `scripts/check.sh --tests -- -k 'gitlab_mr and (deliver or close)'` and the
  relevant docs/markdown checks pass.

## Next Action

Create an implementation source or plan in the next `agent-kit` session that
uses this inbox entry as read-first context, then fix the GitLab MR scripts and
add the heuristic-system inbox promotion workflow.

Lifecycle link: `docs/plans/gitlab-mr-pipeline-cleanup/gitlab-mr-pipeline-cleanup-plan.md`
