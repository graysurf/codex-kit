# Plan-Issue-Delivery Sprint Review Transcript Template

## Context

- Issue: `<issue-number>`
- Sprint: `<sprint-number>`
- Plan file: `docs/plans/plan-issue-delivery-e2e-test-plan.md`
- Runtime lane / group: `<pr-group>`

## Command Output

### `ready-sprint`

- Command:
  `plan-issue ready-sprint --plan docs/plans/plan-issue-delivery-e2e-test-plan.md --issue <issue-number> --sprint <n> --pr-grouping group --strategy auto`
- Output:

```text
<paste command output>
```

### `accept-sprint`

- Command:
  `plan-issue accept-sprint --plan docs/plans/plan-issue-delivery-e2e-test-plan.md --issue <issue-number> --sprint <n> --pr-grouping group --strategy auto --approved-comment-url <comment-url>`
- Output:

```text
<paste command output>
```

## Review Notes

- Reviewer summary:
- Follow-up items:
- Merge decision:

## Merged PR List

- Merged PR 1: `#<number>` - `<title>`
- Merged PR 2: `#<number>` - `<title>`

## approval comment URL

- `accept-sprint` approval comment URL: `<https://github.com/.../issues/<issue-number>#issuecomment-...>`

## Post-Acceptance Status

- Note: the issue remains open after sprint acceptance and is only closed by the final plan-close gate.
