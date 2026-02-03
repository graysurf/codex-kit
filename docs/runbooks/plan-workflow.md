# Plan Workflow Runbook

Status: Active  
Last updated: 2026-01-24

Use this workflow to create a plan, lint it, inspect JSON output, compute parallel batches, and run `/execute-plan-parallel`.
Install tooling via `brew install nils-cli` to get `plan-tooling`, `api-*`, and `semantic-commit` on PATH.

## 1) Create the plan

- Create `docs/plans/<kebab-case>-plan.md`.
- Optional: scaffold from the shared plan template:
  - `plan-tooling scaffold --slug <kebab-case> --title "<task name>"`
- Follow Plan Format v1: `docs/plans/FORMAT.md`.
- If you want Codex to draft the plan, use the `create-plan` or `create-plan-rigorous` workflow and save the result under `docs/plans/`.

## 2) Lint the plan

From repo root:

```bash
plan-tooling validate --file docs/plans/<kebab-case>-plan.md
```

## 3) Export JSON (for inspection or tooling)

```bash
plan-tooling to-json --file docs/plans/<kebab-case>-plan.md --pretty
```

## 4) Compute parallel batches

```bash
plan-tooling batches --file docs/plans/<kebab-case>-plan.md --sprint 1 --format text
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
