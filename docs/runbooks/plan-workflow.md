# Plan Workflow Runbook

Status: Active  
Last updated: 2026-01-24

Use this workflow to create a plan, lint it, inspect JSON output, compute parallel batches, and run `/execute-plan-parallel`.

## 1) Create the plan

- Create `docs/plans/<kebab-case>-plan.md`.
- Follow Plan Format v1: `docs/plans/FORMAT.md`.
- If you want Codex to draft the plan, use the `create-plan` or `create-plan-rigorous` workflow and save the result under `docs/plans/`.

## 2) Lint the plan

From repo root:

```bash
$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh --file docs/plans/<kebab-case>-plan.md
```

## 3) Export JSON (for inspection or tooling)

```bash
$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_to_json.sh --file docs/plans/<kebab-case>-plan.md --pretty
```

## 4) Compute parallel batches

```bash
$CODEX_HOME/skills/workflows/plan/plan-tooling/scripts/plan_batches.sh --file docs/plans/<kebab-case>-plan.md --sprint 1 --format text
```

## 5) Run `/execute-plan-parallel`

Use the plan and sprint number you just batched:

```text
/execute-plan-parallel docs/plans/<kebab-case>-plan.md sprint 1
```

After each batch, integrate results and run the plan's `Validation` commands.

## Optional: repo check runner

Run plan lint via `scripts/check.sh`:

```bash
scripts/check.sh --plans
```
