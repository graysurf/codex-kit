# Plan Authoring Baseline

Shared baseline guidance for `create-plan` and `create-dispatch-plan`.

Use this doc for the common plan-writing and executability rules. The shared
markdown template is a scaffold, not the full source of truth for workflow
policy.

## Authoring baseline

- Every plan needs a primary source artifact unless the user explicitly asks
  for a plan-only waiver. The plan is the execution-control document, not the
  durable place for requirements, review findings, rationale, or backlog
  details.
- Add a `Read First` section immediately after `Overview` with:
  - `Primary source`: repo path, issue/ticket URL, or explicit waiver.
  - `Source type`: `discussion-to-implementation-doc`,
    `review-to-improvement-doc`, `existing issue/spec`, or
    `plan-only waiver`.
  - `Open questions carried into execution`: short list or `none`.
- Default to one primary source. Add secondary references only when they are
  materially needed for execution.
- If source material is converged requirements, design, feasibility, product,
  or customer-facing discussion, create or reference a
  `discussion-to-implementation-doc` artifact before writing the plan.
- If source material is review findings, risks, lessons learned, or a
  fix-later backlog, create or reference a `review-to-improvement-doc` artifact
  before writing the plan.
- When creating a source artifact specifically for plan execution, save it next
  to the plan in `docs/plans/<slug>/` using `<slug>-discussion-source.md` or
  `<slug>-review-source.md`. Promote or rewrite it into domain docs/runbooks
  only when it has value after execution finishes.
- Existing issues, tickets, specs, or project docs can be the primary source
  only when they already separate facts, scope, decisions, acceptance criteria,
  and open questions well enough for execution.
- Keep only execution-relevant summaries in the plan. Link source documents
  instead of duplicating their full requirements, findings, or rationale.
- Use sprints/phases that each produce a demoable or testable increment.
- Treat sprints as sequential integration gates; do not imply cross-sprint
  execution parallelism.
- Break work into atomic, independently testable tasks with explicit
  dependencies when execution order matters.
- Prefer within-sprint parallel lanes only when file overlap and validation
  scope stay manageable.
- Include file paths whenever you can be specific.
- Include a validation step per sprint with commands, checks, and expected
  outcomes.
- Include a `Risks & gotchas` section that covers ambiguity, dependency
  bottlenecks, same-batch overlap hotspots, migrations, rollout, backwards
  compatibility, and rollback.
- The shared template includes a `Complexity` field:
  - `create-plan`: fill it when complexity materially affects
    batching/splitting or when a task looks oversized.
  - `create-dispatch-plan`: fill it for every task.
- The shared template also includes sprint execution placeholders:
  - Grouping metadata (`PR grouping intent`, `Execution Profile`) for plans
    that need explicit execution modeling.
  - Dispatch scorecard fields (`TotalComplexity`, `CriticalPathComplexity`,
    `MaxBatchWidth`, `OverlapHotspots`) for sizing-heavy plans.

## Save and lint

- Save plans to `docs/plans/<slug>/<slug>-plan.md`.
- Slug rules: lowercase kebab-case, 3-6 words, with a plan file named
  `<slug>-plan.md` inside the matching folder.
- Use `plan-tooling scaffold --slug <slug>` with `nils-cli >= 0.8.7`; the
  scaffold writes `docs/plans/<slug>/<slug>-plan.md` by default.
- Lint with:

  ```bash
  plan-tooling validate --file docs/plans/<slug>/<slug>-plan.md
  ```

- Tighten the plan until validation passes.

## Executability and grouping pass

- Default grouping policy when the user does not request one explicitly:
  metadata-first auto with `--strategy auto --default-pr-grouping group`.
- For each sprint, run:

  ```bash
  plan-tooling to-json --file docs/plans/<slug>/<slug>-plan.md --sprint <n>
  plan-tooling batches --file docs/plans/<slug>/<slug>-plan.md --sprint <n>
  plan-tooling split-prs --file docs/plans/<slug>/<slug>-plan.md --scope sprint \
    --sprint <n> --strategy auto --default-pr-grouping group --format json
  ```

- If the user explicitly requests deterministic/manual grouping:
  - Provide explicit mapping for every task:
    `--pr-group <task-id>=<group>` (repeatable).
  - Validate with:

    ```bash
    plan-tooling split-prs --file docs/plans/<slug>/<slug>-plan.md --scope sprint --sprint <n> --pr-grouping group --strategy deterministic --pr-group ... --format json
    ```

- If the user explicitly requests one shared lane per sprint:
  - Validate with:

    ```bash
    plan-tooling split-prs --file docs/plans/<slug>/<slug>-plan.md --scope sprint --sprint <n> --pr-grouping per-sprint --strategy deterministic --format json
    ```

- After each adjustment, rerun `plan-tooling validate` and the relevant
  `split-prs` command until the plan is stable and executable.

## Metadata guardrails

- Metadata labels are exact and case-sensitive:
  - `**PR grouping intent**: per-sprint|group`
  - `**Execution Profile**: serial|parallel-xN`
- Keep metadata coherent:
  - If `PR grouping intent` is `per-sprint`, do not declare parallel width
    `>1`.
  - If planning multi-lane parallel execution, set `PR grouping intent` to
    `group`.
