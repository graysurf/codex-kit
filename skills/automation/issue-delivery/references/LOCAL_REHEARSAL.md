# Issue Delivery: Local Rehearsal

This document contains local/offline rehearsal commands that are intentionally excluded from the main `SKILL.md`.

Use this playbook only when the user explicitly requests rehearsal.

## Purpose

- Rehearse issue handoff/close gates without mutating GitHub state.
- Validate command shape and gate behavior against a local issue body file.

## Entrypoints

- `plan-issue-local ... --dry-run` for local `link-pr` and `status-plan` orchestration from body files.
- `plan-issue --dry-run --body-file ...` for plan-level `ready-plan` and `close-plan` rehearsal.

## Inputs

- Local rehearsal body markdown file (`--body-file <path>`) for dry-run handoff/close checks.
- Approval comment URL for close rehearsal (`--approved-comment-url <url>`).
- Optional review summary text (`--summary`).

## Command Templates

1. Link implementation PRs locally:
   - `plan-issue-local link-pr --body-file <path> --task <task-id> --pr <#123|123|pull-url> --dry-run`
2. Snapshot local status:
   - `plan-issue-local status-plan --body-file <path> --dry-run`
3. Rehearse review handoff:
   - `plan-issue ready-plan --summary "<review focus>" --dry-run --body-file <path>`
4. Rehearse close gates:
   - `plan-issue close-plan --approved-comment-url <url> --dry-run --body-file <path>`

## Rehearsal-Specific Failure Modes

- `close-plan --dry-run` invoked without required `--body-file`.
- Invalid approval URL format during close rehearsal.
- `link-pr` target ambiguity (for example sprint selector spans multiple runtime lanes without `--pr-group`).
- `link-pr` PR selector invalid (`--pr` does not resolve to a concrete PR number).

## Exit Criteria Note

- Rehearsal success does not complete delivery.
- To complete delivery, return to live flow and run:
  - `plan-issue close-plan --repo <owner/repo> --issue <number> --approved-comment-url <url>`
