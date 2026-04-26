# Plan Issue Delivery: Local Rehearsal

This document contains the local/offline rehearsal flow that is intentionally excluded from the main `SKILL.md`.

Use this playbook only when the user explicitly requests local rehearsal.

## Purpose

- Rehearse sprint orchestration without mutating GitHub state.
- Keep command ergonomics close to live mode while preserving deterministic gate checks.

## Entrypoints

- `plan-issue-local` for local sprint/status orchestration.
- `plan-issue --dry-run` for plan-level `ready-plan` / `close-plan` rehearsal.

## Local Rehearsal Contract

- `plan-issue-local` runs without GitHub API usage for local sprint orchestration rehearsal.
- `plan-issue --dry-run` provides live-binary rehearsal behavior without mutating GitHub.
- nils-cli ≥ 0.8.0: every `plan-issue` / `plan-issue-local` invocation in this
  document must be prefixed with `--state-dir "$AGENT_HOME"` (or run with
  `PLAN_ISSUE_HOME="$AGENT_HOME"` exported). Templates below omit the flag for
  readability — treat it as required so rehearsal artefacts land under
  `$AGENT_HOME/out/plan-issue-delivery/...` instead of the new XDG default.
- Sprint commands still require `--issue <number>`; use a local placeholder when no live issue exists (for example `999`).
- Sprint commands default to no comment posting during dry-run/local rehearsal.
- `link-pr` supports `--issue` (live) or `--body-file` (offline); local rehearsal should use `--body-file` (and typically `--dry-run`).
- `ready-plan` requires one of `--issue` or `--body-file`; dry-run/local rehearsal should use `--body-file <path>`.
- `close-plan` requires `--approved-comment-url`; dry-run/local rehearsal also requires `--body-file <path>`.
- Keep the same branch contract as live mode:
  - sprint PRs target `PLAN_BRANCH`
  - `ready-sprint` is pre-merge review
  - final integration PR is `PLAN_BRANCH -> DEFAULT_BRANCH` before `close-plan`
  - record a plan-issue mention-comment URL for the final integration PR before
    `close-plan`
  - run local sync commands after sprint acceptance (`PLAN_BRANCH`) and final
    close (`DEFAULT_BRANCH`)

## Command Templates

1. Local sprint orchestration (`plan-issue-local`)
   - Validate: `plan-tooling validate --file <plan.md>`
   - Start plan:
     `plan-issue-local start-plan --plan <plan.md> --strategy auto --default-pr-grouping group`
   - Start sprint:
     `plan-issue-local start-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --strategy auto --default-pr-grouping group`
   - Link PR (task scope):

     ```bash
     plan-issue-local link-pr --body-file <issue-body.md> --task <task-id> --pr <#123|123|pull-url> --status <planned|in-progress|blocked> --dry-run
     ```

   - Link PR (sprint lane scope):

     ```bash
     plan-issue-local link-pr --body-file <issue-body.md> --sprint <n> [--pr-group <group>] --pr <#123|123|pull-url> --status <planned|in-progress|blocked> --dry-run
     ```

   - Status checkpoint (optional): `plan-issue-local status-plan --body-file <issue-body.md> --dry-run`
   - Ready sprint:
     `plan-issue-local ready-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --strategy auto --default-pr-grouping group`
   - `ready-sprint` expectation in rehearsal:
     - linked sprint PR entries are open/reviewable (not merged yet)
     - linked sprint PR base matches rehearsal `PLAN_BRANCH`
   - Accept sprint:

     ```bash
     plan-issue-local accept-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --strategy auto --default-pr-grouping group --approved-comment-url <comment-url>
     ```

   - Local sync after sprint acceptance:

     ```bash
     git fetch origin --prune
     git switch "$PLAN_BRANCH" || git switch -c "$PLAN_BRANCH" --track "origin/$PLAN_BRANCH"
     git pull --ff-only
     ```

2. Plan-level local/offline rehearsal (`plan-issue --dry-run`)
   - Ready plan: `plan-issue ready-plan --dry-run --body-file <ready-plan-comment.md>`
   - Final integration PR rehearsal artifact: record planned `PLAN_BRANCH -> DEFAULT_BRANCH` PR details in `<ready-plan-comment.md>` (or
     companion note file) before `close-plan`.
   - Integration mention rehearsal artifact: include a placeholder/final
     `PLAN_INTEGRATION_MENTION_URL` in `<ready-plan-comment.md>` (or companion
     note file) before `close-plan`.
   - Close plan: `plan-issue close-plan --dry-run --approved-comment-url <comment-url> --body-file <close-plan-comment.md>`
   - Local sync after final close:

     ```bash
     git fetch origin --prune
     git switch "$DEFAULT_BRANCH" || git switch -c "$DEFAULT_BRANCH" --track "origin/$DEFAULT_BRANCH"
     git pull --ff-only
     ```

## Grouping Policy During Rehearsal

- Keep the same grouping contract used in live flow:
  - Default: `--strategy auto --default-pr-grouping group`
  - Explicit deterministic/manual override:
    `--strategy deterministic --pr-grouping group` plus full `--pr-group`
    coverage
  - Explicit per-sprint override:
    `--strategy deterministic --pr-grouping per-sprint` with no `--pr-group`

## Rehearsal-Specific Failure Modes

- Dry-run/local `ready-plan` invoked without `--issue` or `--body-file`.
- Dry-run/local `close-plan` invoked without required `--approved-comment-url` and `--body-file`.
- `link-pr` target ambiguity (for example sprint selector spans multiple runtime lanes without `--pr-group`).
- `link-pr` PR selector invalid (`--pr` does not resolve to a concrete PR number).

## Exit Criteria Note

- Local rehearsal proves command correctness and artifact generation.
- Production completion still requires running the live close gate from the main skill flow:
  - `plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]`
