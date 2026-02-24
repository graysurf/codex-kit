# issue-body: duplicate pr-isolated branch/worktree

## Goal
- Validate duplicate branch/worktree rejection under `Execution Mode = pr-isolated`.

## Task Decomposition
| Task | Summary | Owner | Branch | Worktree | Execution Mode | PR | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Implement endpoint | subagent-1 | `issue/401/shared` | `.worktrees/issue/401-shared` | pr-isolated | https://github.com/graysurf/agent-kit/pull/105 | in-progress | impl |
| T2 | Implement tests | subagent-2 | `issue/401/shared` | `.worktrees/issue/401-shared` | pr-isolated | https://github.com/graysurf/agent-kit/pull/106 | in-progress | impl |

## Risks / Uncertainties
- None.

## Evidence
- Fixture for duplicate-pr-isolated validation failures.
