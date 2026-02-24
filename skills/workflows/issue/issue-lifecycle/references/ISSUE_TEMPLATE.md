# <feature>: <short title>

## Goal

- <target outcome>

## Acceptance Criteria

- <verifiable condition>

## Scope

- In-scope:
  - <item>
- Out-of-scope:
  - <item>

## Task Decomposition

| Task | Summary | Owner | Branch | Worktree | Execution Mode | PR | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | <summary> | TBD | TBD | TBD | TBD | TBD | planned | <notes> |

## Consistency Rules

- `Status` must be one of: `planned`, `in-progress`, `blocked`, `done`.
- `Status` = `in-progress` or `done` requires non-`TBD` execution metadata (`Owner`, `Branch`, `Worktree`, `Execution Mode`, `PR`).
- `Owner` must be a subagent identifier (contains `subagent`) once the task is assigned; `main-agent` ownership is invalid for implementation tasks.
- `Execution Mode` should be one of: `per-task`, `per-sprint`, `pr-isolated`, `pr-shared` (or `TBD` before assignment).
- `Branch` and `Worktree` uniqueness is enforced only for rows using `Execution Mode = per-task`.

## Risks / Uncertainties

- <risk or unknown>
- <mitigation or validation plan>

## Evidence

- <logs, test reports, screenshots, links>
