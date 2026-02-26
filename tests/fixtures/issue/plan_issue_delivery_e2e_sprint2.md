# issue-body: sprint-2 normalized pr + done sync

## Goal
- Capture Sprint 2 state after PR normalization and done-state synchronization.

## Task Decomposition
| Task | Summary | Owner | Branch | Worktree | Execution Mode | PR | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S2T1 | Extend Sprint 2 runbook gating checklist | subagent-s2-t1 | `issue/s2-t1-extend-runbook-with-sprint-2-gating-checklist` | `$AGENT_HOME/out/plan-issue-delivery/graysurf-agent-kit/issue-186/worktrees/pr-shared/s2-auto-g1` | pr-shared | #202 | done | lane `s2-auto-g1` is pr-shared; status is done after merge sync |
| S2T2 | Add Sprint 2 fixture for normalized PR and done-state sync | subagent-s2-t2 | `issue/s2-t2-add-sprint-2-fixture-for-normalized-pr-and-done` | `$AGENT_HOME/out/plan-issue-delivery/graysurf-agent-kit/issue-186/worktrees/pr-shared/s2-auto-g2` | pr-shared | #201 | done | lane `s2-auto-g2` is pr-shared; PR/status mirror across grouped rows |
| S2T3 | Add regression test for Sprint 2 invariants | subagent-s2-t2 | `issue/s2-t2-add-sprint-2-fixture-for-normalized-pr-and-done` | `$AGENT_HOME/out/plan-issue-delivery/graysurf-agent-kit/issue-186/worktrees/pr-shared/s2-auto-g2` | pr-shared | #201 | done | grouped with S2T2 in pr-shared lane; done-state sync marker enforced |

## Lane Sync Notes
- `pr-shared` lanes synchronize PR references and done-state across grouped task rows.
- Canonical PR references use issue-style markers (`#201`, `#202`) instead of URL-only values.

## Evidence
- Fixture supports Sprint 2 acceptance-gate regression checks.
