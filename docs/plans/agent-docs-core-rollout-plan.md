# Plan: agent-docs core rollout across home and project contexts

## Overview

This plan makes `agent-docs` the primary policy orchestration layer instead of a single `task-tools` hook. The rollout covers `AGENTS_HOME` global behavior and a real project-level pilot in `/Users/terry/Project/graysurf/nils-cli`, with explicit evidence for whether project `AGENTS.md` must change. It also designs and validates an `agent-doc-init` skill to bootstrap missing baseline/policy docs safely for new projects.

## Scope

- In scope:
  - Redesign `$AGENTS_HOME/AGENTS.md` and `$AGENTS_HOME/AGENTS.override.md` as context dispatchers.
  - Expand `$AGENTS_HOME/AGENT_DOCS.toml` to cover `startup`, `task-tools`, `skill-dev`, and `project-dev`.
  - Add context-specific policy documents under `$AGENTS_HOME` and wire them via `agent-docs`.
  - Pilot the same mechanism at project-level in `/Users/terry/Project/graysurf/nils-cli`.
  - Define, implement, and validate an `agent-doc-init` skill for safe baseline initialization.
  - Execute a subagent-based feasibility test and collect measurable outcomes.
- Out of scope:
  - Rewriting `agent-docs` binary internals.
  - Forcing auto-edit behavior inside third-party repos without explicit opt-in.
  - Building non-Codex integrations (IDE plugins, CI bots outside current repos).

## Assumptions

1. `agent-docs`, `plan-tooling`, and `semantic-commit` are available on `PATH`.
2. `$AGENTS_HOME` points to `/Users/terry/.config/codex-kit` in this environment.
3. Pilot changes in `/Users/terry/Project/graysurf/nils-cli` can be tested in a dedicated branch/worktree.
4. Subagent execution is available and can be used to run reproducible scenario checks.

## Success criteria

1. `agent-docs resolve --context <ctx>` succeeds for all four contexts at `AGENTS_HOME`.
2. `agent-docs baseline --check --target all --strict` passes at `AGENTS_HOME`.
3. A documented decision exists for `/Users/terry/Project/graysurf/nils-cli`: keep current `AGENTS.md` as-is or patch it, with evidence.
4. `agent-doc-init` can initialize missing baseline/policy docs in dry-run and apply modes without destructive overwrites.
5. Subagent trial reports show the new flow improves consistency (fewer missing-doc starts, clearer context loading sequence).

## Parallelization opportunities

- Parallel batch A:
  - Task 1.2 (dispatcher contract) and Task 1.3 (evaluation protocol).
- Parallel batch B:
  - Task 2.2 (context docs) and Task 2.3 (home `AGENT_DOCS.toml` expansion) after Task 1.1.
- Parallel batch C:
  - Task 3.1 (nils-cli gap assessment) and Task 4.1 (`agent-doc-init` contract) after Sprint 2 demo.
- Parallel batch D:
  - Task 4.3 (skill tests) and Task 5.1 (subagent trials) after Task 4.2.

## Sprint 1: Architecture and measurement design

**Goal**: Define a precise, testable context model and evaluation protocol before broad changes.

**Demo/Validation**:
- Command(s):
  - `agent-docs contexts --format text`
  - `agent-docs resolve --context startup --format checklist`
  - `agent-docs resolve --context task-tools --format checklist`
- Verify:
  - A written context matrix and dispatcher policy exists with unambiguous trigger rules.

### Task 1.1: Build context-to-trigger decision matrix
- **Location**:
  - `docs/runbooks/agent-docs/context-dispatch-matrix.md`
  - `AGENTS.md`
  - `AGENTS.override.md`
- **Description**: Define an explicit mapping from runtime intent to context resolution order, including required preflight per workflow type: startup session load, technical research, project implementation, and skill authoring. Include strictness policy and fallback behavior when required docs are missing.
- **Dependencies**: none
- **Complexity**: 5
- **Acceptance criteria**:
  - Matrix includes all built-in contexts and their trigger points.
  - Strict vs non-strict behavior is defined with concrete rules.
  - Both English and Chinese AGENTS variants reference the same dispatch contract.
- **Validation**:
  - `test -f docs/runbooks/agent-docs/context-dispatch-matrix.md`
  - `rg -n "context-dispatch-matrix|resolve --context" AGENTS.md AGENTS.override.md`

### Task 1.2: Define dispatcher-style AGENTS policy contract
- **Location**:
  - `AGENTS.md`
  - `AGENTS.override.md`
- **Description**: Refactor AGENTS policy sections to delegate context details to external docs loaded via `agent-docs`, keeping AGENTS concise and deterministic. Ensure AGENTS only expresses dispatch logic, not duplicated long-form workflow bodies.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 6
- **Acceptance criteria**:
  - AGENTS policy becomes dispatcher-oriented and references external context docs.
  - Duplicate workflow text is removed from AGENTS where external docs are canonical.
  - Commands listed in AGENTS match actual `agent-docs` contexts.
- **Validation**:
  - `agent-docs contexts --format text`
  - `rg -n "resolve --context startup|resolve --context task-tools|resolve --context project-dev|resolve --context skill-dev" AGENTS.md AGENTS.override.md`

### Task 1.3: Design measurable effectiveness protocol (including subagent trials)
- **Location**:
  - `docs/runbooks/agent-docs/effectiveness-protocol.md`
  - `out/agent-docs-rollout/README.md`
- **Description**: Define quantitative and qualitative metrics to compare pre/post behavior: missing required doc incidence, context load ordering, task-start latency, and operator corrections. Include a subagent-based test matrix with fixed prompts and pass/fail rubric.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 7
- **Acceptance criteria**:
  - Protocol includes at least 8 deterministic scenarios across home/project contexts.
  - Metrics and evidence file locations are predefined.
  - Subagent rubric forbids requirement drift and asks for critique-only output.
- **Validation**:
  - `test -f docs/runbooks/agent-docs/effectiveness-protocol.md`
  - `bash -lc 'count=$(rg -n "^### Scenario " docs/runbooks/agent-docs/effectiveness-protocol.md | wc -l | tr -d " "); test "$count" -ge 8'`
  - `rg -n "Do not ask questions|critique-only|requirement drift|rubric" docs/runbooks/agent-docs/effectiveness-protocol.md`
  - `mkdir -p out/agent-docs-rollout && test -d out/agent-docs-rollout`

## Sprint 2: AGENTS_HOME full-context rollout

**Goal**: Complete home-level rollout from single-context to all contexts with strict baseline coverage.

**Demo/Validation**:
- Command(s):
  - `agent-docs resolve --context startup --strict --format checklist`
  - `agent-docs resolve --context task-tools --strict --format checklist`
  - `agent-docs resolve --context project-dev --strict --format checklist`
  - `agent-docs resolve --context skill-dev --strict --format checklist`
  - `agent-docs baseline --check --target home --strict --format text`
- Verify:
  - All required docs for home-level contexts are present and resolvable.

### Task 2.1: Expand home AGENT_DOCS coverage to four contexts
- **Location**:
  - `AGENT_DOCS.toml`
- **Description**: Add explicit `[[document]]` entries so each built-in context has required extension docs where needed, while keeping built-in documents intact. Ensure no ambiguous duplication keys and keep notes actionable.
- **Dependencies**:
  - Task 1.2
- **Complexity**: 6
- **Acceptance criteria**:
  - `AGENT_DOCS.toml` contains valid entries for startup/task-tools/project-dev/skill-dev extension docs.
  - `agent-docs resolve` for startup/task-tools/project-dev/skill-dev shows extension entries with `status=present`.
  - No schema validation errors occur.
- **Validation**:
  - `agent-docs resolve --context startup --format checklist`
  - `agent-docs resolve --context task-tools --format checklist`
  - `agent-docs resolve --context project-dev --format checklist`
  - `agent-docs resolve --context skill-dev --format checklist`

### Task 2.2: Externalize context-specific policy docs
- **Location**:
  - `RESEARCH_WORKFLOW.md`
  - `docs/runbooks/agent-docs/STARTUP_WORKFLOW.md`
  - `docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
  - `docs/runbooks/agent-docs/SKILL_DEV_WORKFLOW.md`
- **Description**: Move context-specific operational detail into dedicated docs and keep each document tightly scoped to one context. Reuse existing `RESEARCH_WORKFLOW.md` for task-tools and add the remaining context docs for startup/project-dev/skill-dev.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 6
- **Acceptance criteria**:
  - Each context has a dedicated workflow doc referenced by `AGENT_DOCS.toml`.
  - Workflow docs include entry commands, failure handling, and validation checklist.
  - No duplicated long-form process text remains in AGENTS dispatcher sections.
- **Validation**:
  - `test -f RESEARCH_WORKFLOW.md`
  - `test -f docs/runbooks/agent-docs/STARTUP_WORKFLOW.md`
  - `test -f docs/runbooks/agent-docs/PROJECT_DEV_WORKFLOW.md`
  - `test -f docs/runbooks/agent-docs/SKILL_DEV_WORKFLOW.md`

### Task 2.3: Run home-level strict baseline and capture evidence
- **Location**:
  - `out/agent-docs-rollout/home-baseline.txt`
  - `out/agent-docs-rollout/home-resolve-matrix.json`
- **Description**: Execute strict baseline and per-context resolve checks, store machine-readable outputs, and summarize pass/fail deltas against Sprint 1 protocol. Preserve command outputs for auditability.
- **Dependencies**:
  - Task 2.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Strict home baseline exits 0.
  - Resolve outputs for all contexts are archived in `out/agent-docs-rollout`.
  - Evidence files can be re-generated with documented commands.
- **Validation**:
  - `agent-docs baseline --check --target home --strict --format text | tee out/agent-docs-rollout/home-baseline.txt`
  - `agent-docs resolve --context startup --format json > out/agent-docs-rollout/startup.json`
  - `agent-docs resolve --context task-tools --format json > out/agent-docs-rollout/task-tools.json`
  - `agent-docs resolve --context project-dev --format json > out/agent-docs-rollout/project-dev.json`
  - `agent-docs resolve --context skill-dev --format json > out/agent-docs-rollout/skill-dev.json`

## Sprint 3: project-level pilot in nils-cli

**Goal**: Validate project-level adoption in `/Users/terry/Project/graysurf/nils-cli` and decide whether project `AGENTS.md` must change.

**Demo/Validation**:
- Command(s):
  - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli resolve --context startup --format checklist`
  - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli resolve --context project-dev --format checklist`
  - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli baseline --check --target project --strict --format text`
- Verify:
  - Pilot results include a yes/no decision with evidence on `nils-cli` AGENTS modifications.

### Task 3.1: Assess current nils-cli policy gaps and compatibility
- **Location**:
  - `out/agent-docs-rollout/nils-cli-gap-analysis.md`
  - `out/agent-docs-rollout/nils-cli-current-baseline.txt`
- **Description**: Analyze current policy/document setup in `nils-cli`, identify missing baseline/extension docs, and compare against the new core model. Produce a compatibility report with concrete diff candidates.
- **Dependencies**:
  - Task 2.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Gap report lists current state, missing docs, and migration risk.
  - Evidence includes raw baseline output against `nils-cli`.
  - Candidate change set is separated into required vs optional changes.
- **Validation**:
  - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli baseline --check --target project --format text | tee out/agent-docs-rollout/nils-cli-current-baseline.txt`
  - `test -f out/agent-docs-rollout/nils-cli-gap-analysis.md`

### Task 3.2: Pilot project-level AGENT_DOCS integration in nils-cli
- **Location**:
  - `out/agent-docs-rollout/nils-cli-pilot-changes.md`
  - `docs/runbooks/agent-docs/nils-cli-adoption-decision.md`
- **Description**: Apply a minimal pilot integration in `nils-cli` (prefer dedicated branch/worktree): add `AGENT_DOCS.toml`, decide whether to patch `AGENTS.md` dispatcher text, and avoid unrelated refactors. Record exact changes and rationale in a pilot note.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 7
- **Acceptance criteria**:
  - Pilot branch/worktree contains only policy-related changes.
  - `resolve --context project-dev` picks up project-level extension docs.
  - A clear statement answers whether `nils-cli/AGENTS.md` requires modification.
- **Validation**:
  - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli resolve --context project-dev --strict --format checklist`
  - `agent-docs --project-path /Users/terry/Project/graysurf/nils-cli baseline --check --target project --strict --format text`
  - `test -f out/agent-docs-rollout/nils-cli-pilot-changes.md`

### Task 3.3: Publish project-level decision record
- **Location**:
  - `docs/runbooks/agent-docs/nils-cli-adoption-decision.md`
- **Description**: Consolidate pilot evidence into a decision record: keep existing `AGENTS.md` unchanged, patch partially, or fully adopt dispatcher pattern. Include tradeoffs, rollout cost, and fallback plan.
- **Dependencies**:
  - Task 3.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Decision record includes explicit recommendation and rejected alternatives.
  - Recommendation is directly traceable to pilot evidence files.
  - Next actions are split into required now vs later.
- **Validation**:
  - `test -f docs/runbooks/agent-docs/nils-cli-adoption-decision.md`
  - `rg -n "Recommendation|Evidence|Rollback" docs/runbooks/agent-docs/nils-cli-adoption-decision.md`

## Sprint 4: `agent-doc-init` skill and auto-init flow

**Goal**: Provide a safe initialization mechanism for new projects with missing baseline docs.

**Demo/Validation**:
- Command(s):
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/agent-doc-init/SKILL.md`
  - `$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh --dry-run --project-path /Users/terry/Project/graysurf/nils-cli`
  - `$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh --project-path /Users/terry/Project/graysurf/nils-cli`
- Verify:
  - Missing baseline documents are scaffolded safely and existing files are not overwritten unless explicitly forced.

### Task 4.1: Define `agent-doc-init` skill contract and safety model
- **Location**:
  - `skills/tools/agent-doc-init/SKILL.md`
  - `docs/runbooks/agent-docs/init-safety-model.md`
- **Description**: Define the skill interface and safety guarantees: default dry-run, missing-only scaffolding, explicit `--force` for overwrite, and deterministic logging. Include failure modes for absent `agent-docs`, invalid config, and permission errors.
- **Dependencies**:
  - Task 1.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Skill contract includes full five-field contract format.
  - Safety model documents non-destructive defaults and escalation path.
  - Inputs/outputs align with `agent-docs scaffold-baseline` capabilities.
- **Validation**:
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/agent-doc-init/SKILL.md`
  - `test -f docs/runbooks/agent-docs/init-safety-model.md`

### Task 4.2: Implement init script with baseline-aware behavior
- **Location**:
  - `skills/tools/agent-doc-init/scripts/agent_doc_init.sh`
  - `skills/tools/agent-doc-init/tests/test_tools_agent_doc_init.py`
  - `scripts/README.md`
- **Description**: Implement an init script that runs `agent-docs baseline --check`, scaffolds missing baseline docs with `scaffold-baseline --missing-only`, optionally adds project extension entries, and prints a deterministic summary. Ensure behavior is idempotent.
- **Dependencies**:
  - Task 4.1
- **Complexity**: 8
- **Acceptance criteria**:
  - Script supports `--dry-run`, apply mode, and explicit project path.
  - Re-running on an already initialized project produces no changes.
  - Test suite covers no-op, missing-doc creation, and forced overwrite safeguards.
- **Validation**:
  - `$AGENTS_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh --dry-run --project-path /Users/terry/Project/graysurf/nils-cli`
  - `$AGENTS_HOME/scripts/test.sh -k agent_doc_init`
  - `.venv/bin/python -m pytest skills/tools/agent-doc-init/tests -k agent_doc_init` (optional direct run when venv exists)
  - `bash -n skills/tools/agent-doc-init/scripts/agent_doc_init.sh`

### Task 4.3: Integrate init flow into startup guidance and docs
- **Location**:
  - `AGENTS.md`
  - `AGENTS.override.md`
  - `README.md`
  - `docs/runbooks/agent-docs/new-project-bootstrap.md`
- **Description**: Add a clear bootstrap sequence for new repositories: run `agent-doc-init`, verify baseline, then proceed with context resolves. Keep startup wording concise and avoid duplicated procedural details.
- **Dependencies**:
  - Task 4.2
- **Complexity**: 5
- **Acceptance criteria**:
  - Startup docs include one canonical bootstrap command path.
  - AGENTS references bootstrap guidance without duplicating runbook detail.
  - README includes short onboarding note for new project setup.
- **Validation**:
  - `test -f docs/runbooks/agent-docs/new-project-bootstrap.md`
  - `rg -n "agent-doc-init|baseline --check" AGENTS.md AGENTS.override.md README.md`

## Sprint 5: subagent feasibility trial and rollout decision

**Goal**: Prove operational benefit with subagent-driven trials and finalize rollout/rollback decisions.

**Demo/Validation**:
- Command(s):
  - `python3 scripts/e2e/run_agent_docs_subagent_trials.py --config out/agent-docs-rollout/trial-config.json --output out/agent-docs-rollout/trial-results.json`
  - `python3 scripts/e2e/summarize_agent_docs_trials.py --input out/agent-docs-rollout/trial-results.json --output out/agent-docs-rollout/trial-summary.md`
- Verify:
  - Trial summary quantifies success/failure and recommends go/no-go with rollback triggers.

### Task 5.1: Implement subagent trial harness and fixed scenarios
- **Location**:
  - `scripts/e2e/run_agent_docs_subagent_trials.py`
  - `out/agent-docs-rollout/trial-config.json`
  - `out/agent-docs-rollout/scenarios.md`
- **Description**: Build a deterministic harness that runs fixed prompts through subagents across home and project contexts, records which context resolves were executed, and captures failures. Include at least one scenario for missing docs and one for successful auto-init.
- **Dependencies**:
  - Task 3.3
  - Task 4.3
- **Complexity**: 8
- **Acceptance criteria**:
  - Trial harness executes all configured scenarios without manual intervention.
  - Outputs include per-scenario status, command trace, and failure reason.
  - Scenario set is stable and replayable.
- **Validation**:
  - `python3 scripts/e2e/run_agent_docs_subagent_trials.py --config out/agent-docs-rollout/trial-config.json --output out/agent-docs-rollout/trial-results.json`
  - `jq -e '.scenarios | length >= 8' out/agent-docs-rollout/trial-config.json >/dev/null`
  - `jq -e '.results | length >= 8' out/agent-docs-rollout/trial-results.json >/dev/null`
  - `jq -e '.results[] | has("status") and has("command_trace") and has("failure_reason")' out/agent-docs-rollout/trial-results.json >/dev/null`
  - `test -f out/agent-docs-rollout/trial-results.json`

### Task 5.2: Analyze trial outcomes and decide rollout gate
- **Location**:
  - `out/agent-docs-rollout/trial-summary.md`
  - `docs/runbooks/agent-docs/rollout-gate.md`
- **Description**: Summarize trial metrics against Sprint 1 success criteria and define rollout gate thresholds. Include explicit criteria for blocking rollout and mandatory remediations before retry.
- **Dependencies**:
  - Task 5.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Summary includes pass rate, top failure modes, and remediation owners.
  - Rollout gate defines objective go/no-go thresholds.
  - Links to raw evidence are present.
- **Validation**:
  - `python3 scripts/e2e/summarize_agent_docs_trials.py --input out/agent-docs-rollout/trial-results.json --output out/agent-docs-rollout/trial-summary.md`
  - `test -f docs/runbooks/agent-docs/rollout-gate.md`
  - `rg -n "pass rate|go/no-go|threshold" out/agent-docs-rollout/trial-summary.md docs/runbooks/agent-docs/rollout-gate.md`
  - `rg -n "[0-9]+(\\.[0-9]+)?%" out/agent-docs-rollout/trial-summary.md`
  - `rg -n "go/no-go|threshold|rollback" docs/runbooks/agent-docs/rollout-gate.md`

### Task 5.3: Finalize rollout package and operator checklist
- **Location**:
  - `docs/runbooks/agent-docs/rollout-checklist.md`
  - `docs/runbooks/agent-docs/rollback-operations.md`
- **Description**: Package final rollout steps for operators, including preflight checks, staged rollout order (home then project), monitoring checkpoints, and rollback commands.
- **Dependencies**:
  - Task 5.2
- **Complexity**: 4
- **Acceptance criteria**:
  - Checklist is executable by another engineer without hidden context.
  - Rollback runbook has command-level steps and evidence requirements.
  - Includes the `nils-cli` pilot decision as an explicit branch point.
- **Validation**:
  - `test -f docs/runbooks/agent-docs/rollout-checklist.md`
  - `test -f docs/runbooks/agent-docs/rollback-operations.md`
  - `rg -n "nils-cli|rollback|preflight" docs/runbooks/agent-docs/rollout-checklist.md docs/runbooks/agent-docs/rollback-operations.md`

## Testing Strategy

- Unit:
  - Validate `agent-doc-init` script behavior, argument parsing, idempotency, and safety guards.
- Integration:
  - Context-by-context `agent-docs resolve` and `baseline --strict` checks at home and project scopes.
- E2E/manual:
  - Subagent scenario replay with fixed prompts and reproducible evidence artifacts.
  - Pilot run in `/Users/terry/Project/graysurf/nils-cli` with documented diff and decision record.

## Risks & gotchas

- Overloading AGENTS with duplicated process text can reintroduce drift; dispatcher-only policy must be enforced.
- Project-level pilots may conflict with repo-specific governance; changes should stay isolated in dedicated branches.
- Auto-init can become destructive if overwrite semantics are unclear; dry-run must remain default.
- Subagent trial outcomes may vary if prompts are not fixed; scenario config must be versioned.

## Rollback plan

1. Revert AGENTS dispatcher changes to the last known-good revision in `AGENTS_HOME`.
2. Remove newly added extension entries from `AGENT_DOCS.toml` and re-run `agent-docs baseline --check --target home`.
3. Disable `agent-doc-init` entrypoint from AGENTS/README startup guidance while preserving code for debugging.
4. For `nils-cli` pilot, reset policy files on pilot branch/worktree without touching unrelated project code.
5. Archive failed trial artifacts under `out/agent-docs-rollout/failed-<date>/` and open a remediation plan before reattempting rollout.
