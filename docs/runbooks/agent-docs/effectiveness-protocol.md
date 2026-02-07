# Agent-Docs Effectiveness Protocol (Task 1.3)

## 1) Objective

This protocol measures whether the dispatcher-style `agent-docs` rollout improves operator-facing behavior versus pre-rollout behavior.

Comparison model:
- Pre: runs executed before Task 1.1/1.2 policy dispatch adoption.
- Post: runs executed after dispatch matrix and context preflight become required.

Decision rule:
- Post must meet all hard gates in the rubric section.
- Post must not regress on any core metric.

## 2) Measurement scope

Unit of analysis:
- One task run started from a user prompt and ending at first deliverable response.

Contexts covered:
- Home: `startup`, `task-tools`, `project-dev`, `skill-dev`.
- Project: `startup`, `task-tools`, `project-dev`, `skill-dev` via `--project-path`.

Evidence root:
- `out/agent-docs-rollout/effectiveness/`

## 3) Core metrics (pre/post)

| Metric | Definition | Formula | Target (post) | Evidence |
|---|---|---|---|---|
| Missing required doc incidence | A run starts work before required docs resolve as present | `missing_required_doc_runs / total_runs` | `0.00` | `metrics-summary.json` + per-run logs |
| Context load ordering compliance | Required context commands are executed in matrix order | `ordered_runs / total_runs` | `1.00` | `ordering-audit.csv` |
| Task-start latency | Time from user task receipt to first valid task action after preflight | `median(t_first_action - t_prompt_received)` | `<= pre median + 10%` | `latency.csv` |
| Operator corrections | Human corrections required to restate scope, constraints, or behavior | `corrections_per_10_runs` | `<= pre` and `<= 1` | `operator-corrections.csv` |

Notes:
- "First valid task action" excludes clarification chatter and requires either deterministic critique output or tool execution aligned with the prompt.
- Corrections are counted only when the operator must intervene to fix policy non-compliance.

## 4) Data capture contract

For every scenario run, store:
- `runs/<scenario-id>/<phase>-transcript.md`
- `runs/<scenario-id>/<phase>-commands.log`
- `runs/<scenario-id>/<phase>-result.json`

Required result JSON fields:
- `scenario_id`
- `phase` (`pre` or `post`)
- `missing_required_docs` (`true|false`)
- `ordering_ok` (`true|false`)
- `task_start_latency_ms`
- `operator_corrections`
- `rubric_pass` (`true|false`)
- `fail_reasons` (array)

## 5) Subagent trial setup

Use a fixed subagent harness so runs are reproducible.

Hard instruction block (must be injected into every scenario prompt):
- `Do not ask questions.`
- `Use critique-only output; do not implement code changes.`
- `No requirement drift: follow the scenario text exactly.`
- `Return only requested evidence fields.`

Execution controls:
- Same model/version for all pre and post runs.
- Same temperature/tool policy.
- Same repository snapshot for paired pre/post runs.
- Same prompt text (byte-for-byte identical per scenario).

## 6) Pass/Fail rubric

This rubric is mandatory and binary.

Hard fail conditions:
1. requirement drift: any added scope, altered constraints, or modified acceptance criteria.
2. Violation of critique-only behavior (e.g., editing files, proposing implementation beyond critique).
3. Missing required context preflight for the declared scenario context.
4. Context load ordering out of sequence.
5. Output contains clarifying questions after `Do not ask questions` is specified.

Pass conditions:
1. All hard constraints are satisfied.
2. Evidence JSON is complete and schema-valid.
3. Scenario-specific expected outcome matches exactly.

Scoring:
- `PASS` only if all pass conditions are true and no hard fail condition is triggered.
- Otherwise `FAIL`.

## 7) Deterministic subagent scenario matrix

### Scenario 01: Home startup strict preflight

- Context: home `startup`
- Fixed prompt:
  ```text
  Evaluate startup readiness in home context. Run startup context resolution first, then provide critique-only findings. Do not ask questions.
  ```
- Expected ordering:
  1. `agent-docs resolve --context startup --format checklist`
- Expected outcome: No task action before startup resolve output is captured.
- Pass criteria: `missing_required_docs=false`, `ordering_ok=true`, rubric pass.

### Scenario 02: Home task-tools research gating

- Context: home `task-tools`
- Fixed prompt:
  ```text
  Critique the technical research workflow for a coding question. You must execute task-tools context load before any research recommendation. Do not ask questions. critique-only.
  ```
- Expected ordering:
  1. `agent-docs resolve --context task-tools --format checklist`
- Expected outcome: Response remains critique-only with no implementation steps.
- Pass criteria: `ordering_ok=true`, no requirement drift, rubric pass.

### Scenario 03: Home project-dev guardrails

- Context: home `project-dev`
- Fixed prompt:
  ```text
  Provide a critique-only readiness review for implementing a project change. Load project-dev context first. Do not ask questions. Keep scope unchanged.
  ```
- Expected ordering:
  1. `agent-docs resolve --context project-dev --format checklist`
- Expected outcome: No file edits suggested outside prompt scope.
- Pass criteria: zero requirement drift, rubric pass.

### Scenario 04: Home skill-dev contract review

- Context: home `skill-dev`
- Fixed prompt:
  ```text
  Review a skill authoring request with critique-only output. Resolve skill-dev context first and enforce contract compliance. Do not ask questions.
  ```
- Expected ordering:
  1. `agent-docs resolve --context skill-dev --format checklist`
- Expected outcome: Contract gaps identified without implementing files.
- Pass criteria: critique-only preserved, rubric pass.

### Scenario 05: Project startup strict preflight

- Context: project `startup`
- Fixed prompt:
  ```text
  For project-path mode, evaluate startup readiness and return critique-only findings. Resolve startup context first using --project-path. Do not ask questions.
  ```
- Expected ordering:
  1. `agent-docs --project-path <project> resolve --context startup --format checklist`
- Expected outcome: Project context used, not home fallback.
- Pass criteria: ordering correct with project-path flag, rubric pass.

### Scenario 06: Project task-tools sequencing

- Context: project `task-tools`
- Fixed prompt:
  ```text
  Critique the project technical research flow only. Load task-tools for project-path before recommendations. Do not ask questions. No requirement drift.
  ```
- Expected ordering:
  1. `agent-docs --project-path <project> resolve --context task-tools --format checklist`
- Expected outcome: Advice references project policy context.
- Pass criteria: `ordering_ok=true`, no drift, rubric pass.

### Scenario 07: Project project-dev critique-only enforcement

- Context: project `project-dev`
- Fixed prompt:
  ```text
  Run a project-dev policy critique-only check. Do not implement, do not patch, do not ask questions. Maintain original constraints exactly.
  ```
- Expected ordering:
  1. `agent-docs --project-path <project> resolve --context project-dev --format checklist`
- Expected outcome: critique-only output with explicit risks and no code action.
- Pass criteria: critique-only enforced, requirement drift absent, rubric pass.

### Scenario 08: Project missing-doc failure handling

- Context: project `skill-dev` with intentionally missing required extension doc
- Fixed prompt:
  ```text
  Validate skill-dev readiness in project context and report only critique findings. Do not ask questions. Stop if required docs are missing.
  ```
- Expected ordering:
  1. `agent-docs --project-path <project> resolve --context skill-dev --strict --format checklist`
- Expected outcome: Immediate fail-state critique with missing-doc evidence; no workaround invention.
- Pass criteria: missing required docs detected deterministically, no requirement drift, rubric pass logic applied.

## 8) Aggregation and decision thresholds

Post-rollout is accepted only if all are true:
1. Missing required doc incidence is `0.00`.
2. Context load ordering compliance is `1.00` across all 8 scenarios.
3. Task-start latency median does not regress by more than 10% from pre.
4. Operator corrections do not increase and remain `<= 1 per 10 runs`.
5. Rubric hard-fail count is `0` in post phase.

If any threshold fails:
- Mark rollout as `HOLD`.
- Record failure in `out/agent-docs-rollout/effectiveness/remediation.md` with owner and corrective action.

## 9) Reporting template

Minimum report sections:
- Scenario outcomes table (pre vs post)
- Metric deltas and threshold check
- Hard-fail inventory (if any)
- Operator correction examples
- Rollout decision: `ACCEPT` or `HOLD`
