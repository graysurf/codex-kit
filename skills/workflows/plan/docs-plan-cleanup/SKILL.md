---
name: docs-plan-cleanup
description: Prune outdated docs/plans markdown and reconcile plan-related docs safely for a target project.
---

# Docs Plan Cleanup

## Contract

Prereqs:

- `bash`, `git`, `find`, and `rg` available on `PATH`.
- Target project must be a git work tree and contain `docs/plans/`.
- Choose preserved plans first; run dry-run before `--execute`.

Inputs:

- Optional:
  - `--project-path <path>`: target project path override.
    Default resolution order: `--project-path` > `$PROJECT_PATH` > current directory.
  - `--keep-plan <path|name>`: plan to preserve (repeatable). Supports:
    - repo-relative path (for example `docs/plans/foo-plan.md`),
    - filename (`foo-plan.md`),
    - stem (`foo-plan`).
  - `--keep-plans-file <path>`: newline list of plans to preserve (`#` comments allowed).
  - `--execute`: apply deletions (default is dry-run).
  - `--delete-important`: also delete `docs/specs/**` and `docs/runbooks/**` files only tied to removed plans.
  - `--delete-empty-dirs`: remove empty directories under `docs/` after deletion.

Outputs:

- Stable dry-run/execute report `docs-plan-cleanup-report:v1` with sections:
  - `[plan_md_to_clean]`
  - `[plan_related_md_to_clean]`
  - `[plan_related_md_kept_referenced_elsewhere]`
  - `[plan_related_md_to_rehome]`
  - `[plan_related_md_manual_review]`
  - `[non_docs_md_referencing_removed_plan]`
- In `--execute` mode:
  - removes non-preserved `docs/plans/**/*.md`,
  - removes related `docs/**/*.md` that only depend on removed plans and are not externally referenced,
  - preserves important docs unless `--delete-important` is explicitly set.

Exit codes:

- `0`: success
- `1`: runtime failure
- `2`: usage error or invalid keep-plan input

Failure modes:

- Target is not inside a git work tree.
- `docs/plans/` is missing in the target project.
- Required tool missing (`git`, `rg`, `find`).
- `--keep-plan` / `--keep-plans-file` references unknown or ambiguous plans.
- Deletion fails due to filesystem permissions or path conflicts.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/workflows/plan/docs-plan-cleanup/scripts/docs-plan-cleanup.sh`

## Workflow

1. Identify plans that must be kept.
2. Run dry-run first (defaults to `$PROJECT_PATH` when exported):
   - `PROJECT_PATH=/path/to/project bash $AGENT_HOME/skills/workflows/plan/docs-plan-cleanup/scripts/docs-plan-cleanup.sh --keep-plan active-plan`
3. Review report sections:
   - `plan_related_md_kept_referenced_elsewhere` are protected from auto-delete.
   - `plan_related_md_to_rehome` should be consolidated before deletion.
4. Apply cleanup after review:
   - `bash $AGENT_HOME/skills/workflows/plan/docs-plan-cleanup/scripts/docs-plan-cleanup.sh --project-path /path/to/project --keep-plan active-plan --execute --delete-empty-dirs`
5. Use `--delete-important` only when you are sure `docs/specs/**` and `docs/runbooks/**` candidates are obsolete.

## Output and clarification rules

- Use `references/ASSISTANT_RESPONSE_TEMPLATE.md` as the response format when reporting cleanup results.
- When script output contains `[execution]` with `status: applied`, the response must include:
  1. The exact summary counters from script output, rendered as a Markdown table:
     - `total_plan_md`
     - `plan_md_to_keep`
     - `plan_md_to_clean`
     - `plan_related_md_to_clean`
     - `plan_related_md_kept_referenced_elsewhere`
     - `plan_related_md_to_rehome`
     - `plan_related_md_manual_review`
     - `non_docs_md_referencing_removed_plan`
  2. All itemized sections from the script report, rendered as Markdown tables:
     - `plan_md_to_keep`
     - `plan_md_to_clean`
     - `plan_related_md_to_clean`
     - `plan_related_md_kept_referenced_elsewhere`
     - `plan_related_md_to_rehome`
     - `plan_related_md_manual_review`
     - `non_docs_md_referencing_removed_plan`
- Do not omit empty sections. If a section has no values, keep it and render a `none` row in that table.
- Copy values from script output directly; do not infer or re-count manually.
