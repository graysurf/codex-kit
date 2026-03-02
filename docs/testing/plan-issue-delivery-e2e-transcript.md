# Plan-Issue-Delivery Sprint Review Transcript Template

## Context

- Issue: `<issue-number>`
- Sprint: `<sprint-number>`
- Plan file: `docs/plans/plan-issue-delivery-e2e-test-plan.md`
- Runtime lane / group: `<pr-group>`
- Review sequence: `ready-sprint` (pre-merge) -> merge decisions -> merged PR evidence -> `accept-sprint`

## Command Output

### `ready-sprint`

- Command:

```bash
plan-issue ready-sprint --plan docs/plans/plan-issue-delivery-e2e-test-plan.md --issue <issue-number> --sprint <n> --strategy auto --default-pr-grouping group
```

- Output:

```text
<paste command output>
```

### `accept-sprint`

- Command:

```bash
plan-issue accept-sprint --plan docs/plans/plan-issue-delivery-e2e-test-plan.md --issue <issue-number> --sprint <n> --strategy auto --default-pr-grouping group --approved-comment-url <comment-url>
```

- Output:

```text
<paste command output>
```

## Review Notes

- Reviewer summary:
- Follow-up items:
- Merge decision:
- Review mode (`pre-merge` or `post-merge-audit`):
- Base branch verification (`baseRefName == PLAN_BRANCH`):

## Merged PR List

- Confirm every linked sprint PR is merged into `PLAN_BRANCH` before running `accept-sprint`.
- Merged PR 1: `#<number>` - `<title>`
- Merged PR 2: `#<number>` - `<title>`

## approval comment URL

- `accept-sprint` approval comment URL: `<https://github.com/.../issues/<issue-number>#issuecomment-...>`

## Post-Acceptance Status

- Note: the issue remains open after sprint acceptance and is only closed by the final plan-close gate.
- Local sync after acceptance (`PLAN_BRANCH`): `<command + output>`
