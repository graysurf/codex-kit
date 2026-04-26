---
name: create-plan-issue-sprint-pr
description:
  Open a draft GitHub sprint PR for a plan-issue implementation lane using the assigned dispatch record, PLAN_BRANCH base branch, and
  canonical sprint PR body schema.
---

# Create Plan-Issue Sprint PR

## Contract

Prereqs:

- Run inside, or have access to, the target git repository.
- `git`, `gh`, and `python3` available on `PATH`.
- `gh auth status` succeeds when creating a real PR.
- A plan-issue dispatch record exists for the assigned implementation lane.
- The assigned worktree is an existing git work tree under the plan-issue runtime root.

Inputs:

- Required:
  - `--dispatch-record <path>` pointing at `dispatch-<TASK_ID>.json`.
  - `--issue <number>` for the `## Issue` bullet.
  - At least one `--summary <text>`, `--scope <text>`, and `--testing <text>`.
- Optional:
  - `--repo-slug <owner/repo>` for title context.
  - `--title <text>` to override the default sprint title.
  - `--body-only` to render the PR body without calling `gh`.
  - `--body-out <path>` to write the rendered body before creating the PR.
  - `--ready` to run `gh pr ready` after draft creation.

Outputs:

- Rendered PR body matching `Summary / Scope / Testing / Issue`.
- In create mode, a draft PR opened from the dispatch-record worktree:
  - `--base` is the dispatch record `base_branch` (`PLAN_BRANCH`).
  - `--head` is the dispatch record `branch`.
  - body follows `$AGENT_HOME/skills/automation/plan-issue-delivery/references/SPRINT_PR_TEMPLATE.md`.
- PR URL printed on stdout after creation.

Exit codes:

- `0`: success
- `1`: failure
- `2`: usage error

Failure modes:

- Dispatch record missing or malformed.
- Dispatch record has no `branch`, `base_branch`, task ID, or worktree path.
- Assigned worktree path is not an existing git top-level.
- Rendered body contains validator-rejected placeholders (`TODO`, `TBD`, `<...>`, `#<number>`, `not run (reason)`, `<command> (pass)`).
- `gh pr create` fails because auth, branch, remote, or permission prerequisites are missing.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/pr/plan-issue/create-plan-issue-sprint-pr/scripts/create-plan-issue-sprint-pr.sh`

## Workflow

1. Read `DISPATCH_RECORD_PATH` and resolve:
   - `worktree_abs_path` (preferred) or `worktree`.
   - `branch`.
   - `base_branch` (`PLAN_BRANCH`).
   - `task_id` plus any sibling task IDs recorded for the lane.
2. Verify the worktree is the active git top-level:

   ```bash
   git -C "$WORKTREE" rev-parse --show-toplevel
   ```

3. Render the PR body with the bundled renderer:

   ```bash
   $AGENT_HOME/skills/workflows/pr/plan-issue/create-plan-issue-sprint-pr/scripts/create-plan-issue-sprint-pr.sh \
     --dispatch-record "$DISPATCH_RECORD_PATH" \
     --issue "$ISSUE_NUMBER" \
     --summary "Sprint 2 completes the grouped storage lane." \
     --scope "src/storage/: implements S2T2 and S2T3." \
     --testing "scripts/check.sh --tests -- -k storage (pass)" \
     --body-only
   ```

4. Create the draft PR only after local lane validation has run:

   ```bash
   $AGENT_HOME/skills/workflows/pr/plan-issue/create-plan-issue-sprint-pr/scripts/create-plan-issue-sprint-pr.sh \
     --dispatch-record "$DISPATCH_RECORD_PATH" \
     --issue "$ISSUE_NUMBER" \
     --summary "Sprint 2 completes the grouped storage lane." \
     --scope "src/storage/: implements S2T2 and S2T3." \
     --testing "scripts/check.sh --tests -- -k storage (pass)"
   ```

5. Send the printed PR URL back to the main agent so it can run `plan-issue link-pr`.

## Rules

- Sprint PRs target `PLAN_BRANCH`, not the default branch.
- Keep PRs draft until the implementation lane validation is green; pass `--ready` only after validation is complete.
- Do not use the feature/bug PR body templates for plan-issue sprint PRs.
- Do not self-merge the sprint PR. Merge authority belongs to the plan-issue main agent.
- For grouped lanes, include all task IDs in `--scope` bullets so reviewers can map diff scope back to the plan.
