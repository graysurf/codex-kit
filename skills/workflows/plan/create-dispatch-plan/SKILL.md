---
name: create-dispatch-plan
description:
  Create a dispatch-ready execution-modeling plan under docs/plans/<slug>/ with per-task complexity, required sprint metadata/scorecards,
  PR grouping, split-prs validation, and subagent review. Use when the plan must be ready for sprint dispatch, PR lanes, or subagent
  execution. Do not use as the primary artifact when the user only needs a durable review finding or improvement backlog; route that to
  review-to-improvement-doc first.
---

# Create Dispatch Plan

Build on the `create-plan` baseline, but turn the plan into a dispatch-ready execution model for sprint/PR lane handoff. It requires
per-task complexity, per-sprint scorecards, PR grouping, `split-prs` validation, tighter sizing guardrails, and subagent review.

## Contract

Prereqs:

- User explicitly requests dispatch-ready planning, sprint/PR execution
  modeling, or sizing/review beyond a standard plan.
- You can spawn a review subagent.
- `plan-tooling` available on `PATH` from `nils-cli >= 0.8.7` for scaffold/lint/parse/split flows (`scaffold`, `validate`,
  `to-json`, `batches`, `split-prs`; install via `brew install nils-cli`).

Inputs:

- User request (goal, scope, constraints, success criteria).
- Primary source artifact or source material to convert into one.
- Optional: repo context (files, architecture notes, existing patterns).

Outputs:

- A new plan file saved to `docs/plans/<slug>/<slug>-plan.md`.
- A `Read First` section that links the primary source artifact or records an
  explicit plan-only waiver.
- A short response linking the plan path and summarizing key decisions/risks.
- If the request is not actually a dispatch-ready implementation plan, a short recommendation to create or reference a durable improvement
  doc instead of forcing `docs/plans/`.

Exit codes:

- N/A (conversation/workflow skill)

Failure modes:

- Request remains underspecified and the user won’t confirm assumptions.
- No usable source artifact exists and the user does not approve a plan-only
  waiver.
- Plan requires repo access/info you can’t obtain.
- Subagent review yields conflicting guidance; reconcile and document the decision.

## Entrypoint

- None. This is a workflow-only skill with no `scripts/` entrypoint.

## Workflow

1. Clarify (if needed)

- If underspecified enough to block a useful dispatch plan, ask 1-5 "need to know" questions first.
- Use the blocking-question format from `$AGENT_HOME/skills/workflows/conversation/requirements-gap-scan/SKILL.md`.

1. Confirm that dispatch planning is the right artifact

- Use this skill only when the user needs dispatch-ready execution modeling: explicit sprints, atomic tasks, complexity scores, sprint
  scorecards, PR grouping, `split-prs` validation, and subagent review.
- Do not force `docs/plans/` when the request is mainly to preserve review findings, risks, lessons learned, improvement backlog, or
  "what to fix later" guidance. Use `review-to-improvement-doc` first for the durable project record.
- Do not force `docs/plans/` when the request is mainly to preserve converged
  requirements, design, feasibility, product, or customer-facing discussion.
  Use `discussion-to-implementation-doc` first for the implementation-readiness
  source artifact.
- If the user needs both a durable review/improvement record and a dispatch plan, keep them distinct: preserve the stable findings with
  `review-to-improvement-doc`, then create the dispatch plan and link that document as read-first context.

1. Establish the plan source artifact

- Dispatch plans must have exactly one primary source artifact unless the user
  explicitly asks for a plan-only waiver.
- For converged requirements, design, feasibility, product, architecture, or
  customer-facing discussion, first use `discussion-to-implementation-doc` or
  reference an equivalent existing doc/spec. When creating it for this plan,
  save it as `docs/plans/<slug>/<slug>-discussion-source.md`.
- For review findings, risks, lessons learned, or fix-later backlog, first use
  `review-to-improvement-doc` or reference an equivalent existing issue/doc.
  When creating it for this plan, save it as
  `docs/plans/<slug>/<slug>-review-source.md`.
- Existing issues, tickets, specs, or project docs can be the primary source
  when they already separate facts, scope, decisions, acceptance criteria, and
  open questions well enough for execution.
- Link the primary source under `Read First`; do not duplicate the full
  requirements, findings, or rationale in the plan.
- Treat plan-created source docs as coordination artifacts that are eligible
  for cleanup after execution unless they are explicitly promoted.

1. Research

- Identify existing patterns and the minimal touch points.
- Identify tricky edge cases, migrations, rollout, and compatibility constraints.
- For repo-wide skill work, use `skills/README.md` and `docs/runbooks/skills/SKILL_REVIEW_CHECKLIST.md` as the baseline inventory,
  plus `docs/runbooks/skills/SCRIPT_SIMPLIFICATION_PLAYBOOK.md` when planning entrypoint consolidation.

1. Draft the plan (do not implement)

- Follow the shared baseline in `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.
- Dispatch deltas:
  - Fill a per-task **Complexity** score (1–10).
  - Make dependencies explicit for every task and call out parallelizable work when it helps execution planning.
  - Treat each sprint as an integration gate; do not plan cross-sprint execution parallelism.
  - Focus parallelization design inside each sprint (task/PR dependency graph), not across sprints.
  - Record sprint metadata for every sprint with these exact labels:
    - `**PR grouping intent**: per-sprint|group`
    - `**Execution Profile**: serial|parallel-xN`
  - Add a “Rollback plan” that is operationally plausible.

1. Save the plan

- Use the shared save rules from `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.

1. Lint the plan (format + executability)

- Use the shared lint flow from `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.
- Fix until it passes (no placeholders in required fields; explicit validation commands; dependency IDs exist).

1. Run the shared executability + grouping pass (mandatory)

- Use the shared executability + grouping workflow in `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`.

1. Run a sizing + parallelization pass (mandatory)

- Parallelization policy for this skill:
  - `Sprint` is an integration/decision gate. Do not schedule cross-sprint execution parallelism.
  - Optimize for parallel execution inside a sprint by improving the task DAG (dependencies, file overlap, PR grouping).
- Metadata guardrails:
  - Metadata field names are strict; do not use variants such as `PR Grouping Intent`.
  - `plan-tooling validate` now blocks metadata mismatch by default (`per-sprint` cannot pair with parallel width `>1`).
- Per-sprint sizing/parallelization scorecard (record in the plan or sprint notes):
  - `Execution Profile`: `serial` | `parallel-x2` | `parallel-x3`
  - `TotalComplexity`: sum of task complexity in the sprint
  - `CriticalPathComplexity`: sum of complexity on the longest dependency chain
  - `MaxBatchWidth`: widest dependency batch returned by `plan-tooling batches`
  - `OverlapHotspots`: same-batch file/module overlap risks to watch
- Sizing guardrails (adjust plan when violated):
  - Task complexity target is `1-6`; complexity `>=7` should usually be split into smaller tasks.
  - PR complexity target is `2-5`; preferred max is `6`.
  - PR complexity `7-8` is an exception and requires explicit justification (single responsibility, low overlap, isolated validation).
  - PR complexity `>8` should be split before execution planning.
  - Sprint target is `2-5` tasks and total complexity `8-24`, but evaluate it with the sprint's execution profile:
    - `serial`: target `2-4` tasks, `TotalComplexity 8-16`, `CriticalPathComplexity 8-16`, `MaxBatchWidth = 1`
    - `parallel-x2`: target `3-5` tasks, `TotalComplexity 12-22` (up to `24` if justified), `CriticalPathComplexity 8-14`,
      `MaxBatchWidth <= 2`
    - `parallel-x3`: target `4-6` tasks, `TotalComplexity 16-24`, `CriticalPathComplexity 10-16`, `MaxBatchWidth <= 3`
  - Do not use `TotalComplexity` alone as the sizing signal; `CriticalPathComplexity` is the primary throughput constraint.
  - If dependency layers become mostly serial (for example a chain of `>3` tasks), rebalance/split to recover parallel lanes unless the
    sequence is intentionally strict.
  - For a task with complexity `>=7`, try to split first; if it cannot be split cleanly, keep it as a dedicated lane and dedicated PR (when
    parallelizable and isolated enough).
  - Default limit is at most one task with complexity `>=7` per sprint; more than one requires explicit justification plus low overlap,
    frozen contracts, and non-blocking validation.
  - For tasks in the same dependency batch, avoid heavy file overlap in `Location`; if overlap is unavoidable, either group those tasks into
    one PR or serialize them explicitly.
- After each adjustment, rerun `plan-tooling validate` and the relevant `split-prs` command(s) until output is stable and executable in the
  intended grouping mode.

1. Subagent review

- Spawn a subagent to review the saved plan file.
- Give it: the plan path + the original request + any constraints.
- Explicitly instruct it: “Do not ask questions; only provide critique and improvements.”
- Review rubric for the subagent:
  - Check for missing required task fields (`Location`, `Description`, `Dependencies`, `Acceptance criteria`, `Validation`).
  - Check for placeholder tokens left behind (`<...>`, `TODO`, `TBD`) in required fields.
  - Check task atomicity (single responsibility) and parallelization opportunities (dependency clarity, minimal file overlap).
  - Check the plan can be split with `plan-tooling split-prs` in the intended
    grouping mode (`--strategy auto --default-pr-grouping group` by default;
    `--strategy deterministic --pr-grouping group` with full mapping or
    `--strategy deterministic --pr-grouping per-sprint` when explicitly
    requested).
  - Check sprint metadata labels are exact (`PR grouping intent`, `Execution Profile`) and consistent with grouping strategy.
  - Check that `Read First` names one primary source artifact or an explicit
    plan-only waiver, and that the plan does not duplicate the source artifact.
  - Check sprint/task sizing is realistic for subagent PR execution (not just conceptually valid).
  - Check the sprint scorecard (`Execution Profile`, `TotalComplexity`, `CriticalPathComplexity`, `MaxBatchWidth`, `OverlapHotspots`) is
    present and consistent with dependencies.
  - Check no cross-sprint execution parallelism is implied by the plan sequencing.
  - Check that validation is runnable and matches acceptance criteria.
- Incorporate useful feedback into the plan (keep changes minimal and coherent).

1. Final gotchas pass

- Ensure the plan has clear success criteria, validation commands, risk mitigation, and explicit execution grouping intent per sprint.

1. Docs completion checklist (when plans drive repo refactors)

- In the same execution cycle as implementation PRs, ensure docs that claim check/workflow behavior are updated:
  - `README.md`
  - `DEVELOPMENT.md`
  - `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
  - Relevant `docs/testing/*.md` pages
- Require these validation commands before declaring the plan lane complete:

  ```bash
  scripts/check.sh --docs
  scripts/check.sh --markdown
  ```

## Plan Template

Shared markdown scaffold:

- `skills/workflows/plan/_shared/assets/plan-template.md`

Canonical shared authoring and validation rules:

- `skills/workflows/plan/_shared/references/PLAN_AUTHORING_BASELINE.md`

Dispatch requirement:

- Fill `Complexity` for every task (int 1–10).
- Treat sprints as sequential integration gates (no cross-sprint execution parallelism).
- Optimize parallelism within each sprint and document the per-sprint scorecard (`Execution Profile`, `TotalComplexity`,
  `CriticalPathComplexity`, `MaxBatchWidth`, `OverlapHotspots`).
- When the plan changes tracked skill entrypoints or review rules, update the inventory/checklist/playbook docs in the same plan lane:
  - `skills/README.md`
  - `docs/runbooks/skills/SKILL_REVIEW_CHECKLIST.md`
  - `docs/runbooks/skills/SCRIPT_SIMPLIFICATION_PLAYBOOK.md`
