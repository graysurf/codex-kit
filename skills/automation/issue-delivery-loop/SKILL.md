---
name: issue-delivery-loop
description: "Orchestrate end-to-end issue execution loops for main-agent ownership: open issue, track task/PR status, request review, and close only after approval + merged PR gates."
---

# Issue Delivery Loop

## Contract

Prereqs:

- Run inside (or have access to) the target repository.
- `gh` available on `PATH`, and `gh auth status` succeeds for issue/PR reads and writes.
- Base workflow scripts exist:
  - `$AGENT_HOME/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh`

Inputs:

- Main-agent issue metadata (`title`, optional body/labels/assignees/milestone).
- Optional task decomposition TSV for bootstrap comments.
- Optional review summary text.
- Approval comment URL (`https://github.com/<owner>/<repo>/(issues|pull)/<n>#issuecomment-<id>`) when closing.

Outputs:

- Deterministic orchestration over issue lifecycle commands with explicit gate checks.
- Status snapshot and review-request markdown blocks for traceable issue history.
- Issue close only when review approval and merged-PR checks pass.

Exit codes:

- `0`: success
- non-zero: usage errors, missing tools, gh failures, or gate validation failures

Failure modes:

- Missing required options (`--title`, `--issue`, `--approved-comment-url`, etc.).
- Invalid approval URL format or repo mismatch with `--repo`.
- Task rows violate close gates (status not `done`, PR missing, or PR not merged).
- Issue/PR metadata fetch fails via `gh`.

## Entrypoint

- `$AGENT_HOME/skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh`

## Core usage

1. Start issue execution:
   - `.../manage_issue_delivery_loop.sh start --repo <owner/repo> --title "<title>" --label issue --task-spec <tasks.tsv>`
2. Update status snapshot (main-agent checkpoint):
   - `.../manage_issue_delivery_loop.sh status --repo <owner/repo> --issue <number>`
3. Request review (main-agent review handoff):
   - `.../manage_issue_delivery_loop.sh ready-for-review --repo <owner/repo> --issue <number> --summary "<review focus>"`
4. Close after explicit review approval:
   - `.../manage_issue_delivery_loop.sh close-after-review --repo <owner/repo> --issue <number> --approved-comment-url <url>`

## Notes

- `status` and `ready-for-review` also support `--body-file` for offline/dry-run rendering in tests.
- `close-after-review` supports `--body-file` for offline gate checks; it prints `DRY-RUN-CLOSE-SKIPPED` in body-file mode.
- Use `--dry-run` to suppress write operations while previewing commands.
