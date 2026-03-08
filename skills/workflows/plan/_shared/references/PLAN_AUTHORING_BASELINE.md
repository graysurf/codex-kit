# Plan Authoring Baseline

Shared baseline guidance for `create-plan` and `create-plan-rigorous`.

Use this doc for the common plan-writing and executability rules. The shared
markdown template is a scaffold, not the full source of truth for workflow
policy.

## Authoring baseline

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
  - `create-plan-rigorous`: fill it for every task.
- The shared template also includes sprint execution placeholders:
  - Grouping metadata (`PR grouping intent`, `Execution Profile`) for plans
    that need explicit execution modeling.
  - Rigorous scorecard fields (`TotalComplexity`, `CriticalPathComplexity`,
    `MaxBatchWidth`, `OverlapHotspots`) for sizing-heavy plans.

## Save and lint

- Save plans to `docs/plans/<slug>-plan.md`.
- Slug rules: lowercase kebab-case, 3-6 words, end with `-plan.md`.
- Lint with:

  ```bash
  plan-tooling validate --file docs/plans/<slug>-plan.md
  ```

- Tighten the plan until validation passes.

## Executability and grouping pass

- Default grouping policy when the user does not request one explicitly:
  metadata-first auto with `--strategy auto --default-pr-grouping group`.
- For each sprint, run:

  ```bash
  plan-tooling to-json --file docs/plans/<slug>-plan.md --sprint <n>
  plan-tooling batches --file docs/plans/<slug>-plan.md --sprint <n>
  plan-tooling split-prs --file docs/plans/<slug>-plan.md --scope sprint \
    --sprint <n> --strategy auto --default-pr-grouping group --format json
  ```

- If the user explicitly requests deterministic/manual grouping:
  - Provide explicit mapping for every task:
    `--pr-group <task-id>=<group>` (repeatable).
  - Validate with:

    ```bash
    plan-tooling split-prs --file docs/plans/<slug>-plan.md --scope sprint --sprint <n> --pr-grouping group --strategy deterministic --pr-group ... --format json
    ```

- If the user explicitly requests one shared lane per sprint:
  - Validate with:

    ```bash
    plan-tooling split-prs --file docs/plans/<slug>-plan.md --scope sprint --sprint <n> --pr-grouping per-sprint --strategy deterministic --format json
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
