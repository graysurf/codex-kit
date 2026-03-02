# Plan-Issue-Delivery Final Execution Summary Template

Use this template after the final `ready-plan` and `close-plan` flow. Fill each field from run outputs generated during the rehearsal.

## Context

- Plan file: `docs/plans/plan-issue-delivery-e2e-test-plan.md`
- Issue number: `ISSUE_NUMBER`
- Execution date window: `START_DATE -> END_DATE`
- Runtime root: `$AGENT_HOME/out/plan-issue-delivery/.../issue-ISSUE_NUMBER`
- Summary owner: `SUMMARY_OWNER`

## Issue Closure Evidence

- `close-plan` command used:

```bash
plan-issue close-plan \
  --issue ISSUE_NUMBER \
  --approved-comment-url APPROVED_COMMENT_URL
```

- Issue URL: `ISSUE_URL`
- Final issue state (`OPEN`/`CLOSED`): `STATE`
- Close confirmation evidence (comment/log URL): `EVIDENCE_URL`
- Plan-level approval URL used for close gate: `APPROVED_COMMENT_URL`
- Integration PR mention comment URL on plan issue: `PLAN_INTEGRATION_MENTION_URL`
- Integration mention gate status (`PASS`/`FAIL`): `MENTION_GATE_STATUS`
- Final local default-branch sync command/result: `git switch "$DEFAULT_BRANCH" && git pull --ff-only` -> `RESULT`

## Merged PRs

|Task ID|PR|Merge Commit|Merge Evidence|
|---|---|---|---|
|S1T\*|`#PR_NUMBER`|`MERGE_SHA`|`MERGE_EVIDENCE`|
|S2T\*|`#PR_NUMBER`|`MERGE_SHA`|`MERGE_EVIDENCE`|
|S3T\*|`#PR_NUMBER`|`MERGE_SHA`|`MERGE_EVIDENCE`|
|Integration|`#PR_NUMBER`|`MERGE_SHA`|`MERGE_EVIDENCE`|

## Cleanup Result

- Cleanup command used:

```bash
scripts/check_plan_issue_worktree_cleanup.sh \
  "$AGENT_HOME/out/plan-issue-delivery/graysurf-agent-kit/issue-ISSUE_NUMBER/worktrees"
```

- Cleanup status (`PASS`/`FAIL`): `STATUS`
- Runtime directories checked: `PATH_LIST`
- Leftover worktrees (if any): `NONE_OR_PATHS`

## Local Sync Evidence

- Sprint acceptance local sync evidence (`PLAN_BRANCH`): `SYNC_LOG_OR_URL`
- Final close local sync evidence (`DEFAULT_BRANCH`): `SYNC_LOG_OR_URL`

## Residual Risks

- Risk 1: `RISK` Impact: `IMPACT` Mitigation/owner: `MITIGATION`
- Risk 2: `RISK` Impact: `IMPACT` Mitigation/owner: `MITIGATION`
