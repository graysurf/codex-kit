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
- Sprint commands still require `--issue <number>`; use a local placeholder when no live issue exists (for example `999`).
- Sprint commands default to no comment posting during dry-run/local rehearsal.
- `link-pr` supports `--issue` (live) or `--body-file` (offline); local rehearsal should use `--body-file` (and typically `--dry-run`).
- `ready-plan` requires one of `--issue` or `--body-file`; dry-run/local rehearsal should use `--body-file <path>`.
- `close-plan` requires `--approved-comment-url`; dry-run/local rehearsal also requires `--body-file <path>`.

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
   - Accept sprint:

     ```bash
     plan-issue-local accept-sprint --plan <plan.md> --issue <local-placeholder-number> --sprint <n> --strategy auto --default-pr-grouping group --approved-comment-url <comment-url>
     ```

2. Plan-level local/offline rehearsal (`plan-issue --dry-run`)
   - Ready plan: `plan-issue ready-plan --dry-run --body-file <ready-plan-comment.md>`
   - Close plan: `plan-issue close-plan --dry-run --approved-comment-url <comment-url> --body-file <close-plan-comment.md>`

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
