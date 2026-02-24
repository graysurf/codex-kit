# Plan: Repo docs skill sync and reorg

## Overview
Review all tracked documentation files in this repo, identify outdated content, and correct references with special focus on recently deleted skills and newly added issue-related skills. The plan also evaluates consolidation/moves for overlapping docs to reduce future drift. Initial scan shows issue skills are already represented in `README.md` and `docs/runbooks/skills/TOOLING_INDEX_V2.md`, and `skills/README.md` substantially overlaps `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`. Use `git ls-files` (not only `rg --files`) for inventory because ignore rules can hide tracked files from discovery commands.

## Scope
- In scope:
  - Tracked markdown docs: root `*.md`, `docs/**/*.md`, `skills/**/SKILL.md`, `skills/**/*README*.md`, `skills/**/references/*.md`, `docker/**/README.md`, `scripts/README.md`, `prompts/*.md`.
  - Markdown fixtures/contracts under `tests/fixtures/**/*.md` when they encode user-facing templates, plan format examples, or issue workflow bodies.
  - Link/path/reference updates caused by skill additions/removals and doc moves.
  - Evaluating and executing doc consolidation/moves where duplication is high and audience remains clear.
- Out of scope:
  - Non-markdown code changes unless required to keep docs/tests valid after a move (for example, updating a test path reference).
  - Behavioral changes to skill scripts or workflow logic.
  - Retroactively rewriting historical changelog release notes except for adding a current cleanup entry (if needed).

## Assumptions (if any)
1. This turn delivers a plan only; documentation edits happen in a later execution pass.
2. "All documents" means tracked markdown files in the repo, plus markdown fixtures used as contract examples.
3. Recent skill additions/removals can be derived from git history and current tracked `skills/**/SKILL.md`.
4. `plan-tooling` is available on `PATH` and repo checks can run from the repository root.

## Success criteria
- A reproducible audit process exists for doc inventory, skill catalog drift, and broken skill/script references.
- All tracked markdown docs are reviewed and either updated, confirmed current, or explicitly marked no-change in an audit report.
- New issue-related skills are consistently documented in canonical catalogs/runbooks where applicable.
- Removed skills are no longer presented as active skills in current-facing docs.
- Overlapping docs are consolidated or given clear canonical-source links to reduce duplicate maintenance.

## Sprint 1: Inventory and drift baseline
**Goal**: Build a reliable documentation inventory, derive recent skill deltas, and produce a prioritized review queue before editing docs.
**Demo/Validation**:
- Command(s): `git ls-files '*.md' > /tmp/tracked-md-count.txt && wc -l /tmp/tracked-md-count.txt`; `git ls-files > /tmp/all-files.txt && rg -n '^skills/.*/SKILL\\.md$' /tmp/all-files.txt`; `ls out/docs-audit`
- Verify: Baseline artifacts exist and enumerate tracked docs/skills plus detected drift candidates.
**Parallelizable tasks**:
- `Task 1.1`, `Task 1.2`, and `Task 1.3` can run in parallel (read-only, separate outputs).
- `Task 1.4` depends on outputs from `Task 1.1`-`Task 1.3`.

### Task 1.1: Build tracked markdown inventory and classification
- **Location**:
  - `out/docs-audit/markdown-inventory.tsv`
  - `out/docs-audit/markdown-inventory-summary.md`
  - `docs/plans/repo-docs-skill-sync-reorg-plan.md`
- **Description**: Generate a tracked markdown inventory using `git ls-files` and classify files by area (`root`, `docs/runbooks`, `skills/*`, `docker`, `scripts`, `prompts`, `tests/fixtures`) so review coverage can be measured and assigned.
- **Dependencies**: none
- **Complexity**: 4
- **Acceptance criteria**:
  - Every tracked `*.md` file appears once in the inventory.
  - The summary reports per-area counts and review priority suggestions.
  - The inventory method documents why `git ls-files` is authoritative for tracked docs.
- **Validation**:
  - `git ls-files '*.md' > /tmp/tracked-md.txt && sort /tmp/tracked-md.txt -o /tmp/tracked-md.txt && cut -f1 out/docs-audit/markdown-inventory.tsv > /tmp/inventory-md.txt && sort /tmp/inventory-md.txt -o /tmp/inventory-md.txt && diff -u /tmp/tracked-md.txt /tmp/inventory-md.txt`
  - `rg -n 'git ls-files' out/docs-audit/markdown-inventory-summary.md`

### Task 1.2: Derive recent skill add/remove history with issue-skill focus
- **Location**:
  - `out/docs-audit/skill-history-delta.md`
  - `out/docs-audit/current-skill-inventory.txt`
- **Description**: Build a current tracked skill inventory and derive recent added/removed skill paths (including issue-related skills) from git history to create a concrete review target list for documentation drift.
- **Dependencies**: none
- **Complexity**: 5
- **Acceptance criteria**:
  - Current tracked skills are listed from git-tracked `SKILL.md` files.
  - Added/removed skill paths are summarized with enough history context to review impacted docs.
  - Issue-related skills are explicitly highlighted as a review subset.
- **Validation**:
  - `git ls-files > /tmp/all-files.txt && rg -n '^skills/.*/SKILL\\.md$' /tmp/all-files.txt > /tmp/current-skill-inventory-raw.txt && sort /tmp/current-skill-inventory-raw.txt -o out/docs-audit/current-skill-inventory.txt`
  - `git log --name-status --max-count 50 -- skills > /tmp/skills-history.log && rg -n '^commit ' /tmp/skills-history.log && rg -n '/SKILL\\.md$' /tmp/skills-history.log`
  - `rg -n 'issue-[a-z-]+' out/docs-audit/skill-history-delta.md`

### Task 1.3: Run automated documentation drift checks for skill references
- **Location**:
  - `out/docs-audit/drift-checks/README-skill-catalog-diff.txt`
  - `out/docs-audit/drift-checks/broken-skill-links.txt`
  - `out/docs-audit/drift-checks/missing-agent-home-script-paths.txt`
  - `out/docs-audit/drift-checks/reference-audit-summary.md`
- **Description**: Run repeatable checks for common drift patterns: skill catalog mismatches vs tracked skills, markdown links to skill paths that no longer map to tracked skills/docs, and `$AGENT_HOME/skills/.../scripts/...` references to missing entrypoints.
- **Dependencies**: none
- **Complexity**: 6
- **Acceptance criteria**:
  - Each check writes a machine-readable or plain-text output file (including empty/no-findings cases).
  - Results distinguish true issues from example/placeholders (for example `skills/...` literal examples).
  - The summary lists candidate files for manual review with severity (catalog, runbook, skill contract, template).
- **Validation**:
  - `test -f out/docs-audit/drift-checks/reference-audit-summary.md`
  - `rg -n 'README' out/docs-audit/drift-checks/reference-audit-summary.md`
  - `rg -n 'TOOLING_INDEX' out/docs-audit/drift-checks/reference-audit-summary.md`
  - `rg -n 'SKILL' out/docs-audit/drift-checks/reference-audit-summary.md`
  - `wc -l out/docs-audit/drift-checks/*.txt`

### Task 1.4: Produce prioritized review queue and consolidation candidate matrix
- **Location**:
  - `out/docs-audit/review-queue.md`
  - `out/docs-audit/consolidation-candidates.md`
- **Description**: Convert inventory and drift outputs into an execution queue with priority (`P0 correctness`, `P1 consistency`, `P2 consolidation`) and identify high-overlap docs (starting with `skills/README.md` vs `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`) for merge/move decisions.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
  - Task 1.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Every tracked markdown file is mapped to a review bucket or explicitly marked excluded with reason.
  - Consolidation candidates include rationale, target canonical doc, and migration risk.
  - The queue marks which tasks are safe to execute in parallel.
- **Validation**:
  - `rg -n 'P[0-2]' out/docs-audit/review-queue.md`
  - `rg -n 'skills/README.md' out/docs-audit/consolidation-candidates.md`
  - `rg -n 'docs/runbooks/skills/SKILLS_ANATOMY_V2.md' out/docs-audit/consolidation-candidates.md`

## Sprint 2: Correctness updates for active documentation
**Goal**: Update current-facing docs to accurately reflect the present skill set (especially issue-related skills and removed skills) and eliminate concrete reference drift.
**Demo/Validation**:
- Command(s): rerun Sprint 1 drift checks; `git diff --stat`; `rg -n 'issue-[a-z-]+' README.md docs/runbooks/skills/TOOLING_INDEX_V2.md`
- Verify: P0 correctness issues are resolved and no active-skill catalog entries point to deleted skills.
**Parallelizable tasks**:
- `Task 2.1`, `Task 2.2`, and `Task 2.3` can run in parallel if file ownership is split (avoid overlapping edits to `README.md`).
- `Task 2.4` runs after the targeted updates as a sweep/cleanup pass.

### Task 2.1: Update root-facing catalogs and onboarding docs
- **Location**:
  - `README.md`
  - `AGENTS.md`
  - `DEVELOPMENT.md`
  - `CLI_TOOLS.md`
  - `RESEARCH_WORKFLOW.md`
- **Description**: Review and correct top-level docs that shape first-time usage and repo navigation so skill additions/removals (including issue workflow/automation skills) are represented consistently in user-facing guidance.
- **Dependencies**:
  - Task 1.4
- **Complexity**: 6
- **Acceptance criteria**:
  - Root skill catalog and setup docs do not reference removed skills as active current options.
  - Issue-related skills are documented consistently where top-level catalogs or workflows enumerate supported capabilities.
  - Any intentionally omitted skills are documented as such (for example internal-only or non-public domains).
- **Validation**:
  - `git diff -- README.md AGENTS.md DEVELOPMENT.md CLI_TOOLS.md RESEARCH_WORKFLOW.md`
  - `rg -n 'issue-[a-z-]+' README.md`
  - `rg -n '\\./skills/.+\\/' README.md > /tmp/readme-skill-links.txt && wc -l /tmp/readme-skill-links.txt`
  - `git ls-files > /tmp/all-files.txt && rg -n '^skills/.*/SKILL\\.md$' /tmp/all-files.txt`

### Task 2.2: Update skill-governance and tooling index documentation
- **Location**:
  - `skills/tools/skill-management/README.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`
  - `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`
- **Description**: Correct command references, policy descriptions, and examples in skills/governance runbooks so they align with the current skill tree, current automation wrappers, and current path conventions.
- **Dependencies**:
  - Task 1.4
- **Complexity**: 7
- **Acceptance criteria**:
  - Referenced `$AGENT_HOME/skills/.../scripts/...` entrypoints exist or are clearly marked as examples.
  - Governance docs and anatomy docs use current tracked-skill rules and directory layout terminology.
  - Cross-links between the skill-management README and runbooks point to canonical docs after the reorg decision.
- **Validation**:
  - `rg -n '\\$AGENT_HOME/skills/.+/scripts/.+' skills/tools/skill-management/README.md docs/runbooks/skills/*.md`
  - `git diff -- skills/tools/skill-management/README.md docs/runbooks/skills/*.md`

### Task 2.3: Review issue workflow and issue automation skill docs for cross-link consistency
- **Location**:
  - `skills/workflows/issue/issue-lifecycle/SKILL.md`
  - `skills/workflows/issue/issue-subagent-pr/SKILL.md`
  - `skills/workflows/issue/issue-pr-review/SKILL.md`
  - `skills/automation/issue-delivery-loop/SKILL.md`
  - `skills/automation/plan-issue-delivery-loop/SKILL.md`
  - `skills/workflows/issue/issue-lifecycle/references/ISSUE_TEMPLATE.md`
  - `skills/workflows/issue/issue-subagent-pr/references/PR_BODY_TEMPLATE.md`
  - `skills/workflows/issue/issue-pr-review/references/ISSUE_SYNC_TEMPLATE.md`
- **Description**: Perform a focused consistency review of issue-related skills added recently to confirm naming, orchestration roles (main-agent vs subagent), script entrypoints, and cross-skill references are accurate and aligned with current repo workflow terminology.
- **Dependencies**:
  - Task 1.2
  - Task 1.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Issue-skill docs use consistent terminology and cross-link names.
  - Any stale references to deleted or renamed companion skills are removed or redirected.
  - The issue workflow chain (`issue-lifecycle` -> `issue-subagent-pr` -> `issue-pr-review` -> delivery loop wrappers) is documented without contradictions.
- **Validation**:
  - `rg -n 'issue-[a-z-]+' skills/workflows/issue skills/automation/issue-delivery-loop skills/automation/plan-issue-delivery-loop -g '*.md'`
  - `git diff -- skills/workflows/issue skills/automation/issue-delivery-loop skills/automation/plan-issue-delivery-loop`

### Task 2.4: Run repo-wide stale-name and stale-path cleanup sweep
- **Location**:
  - `out/docs-audit/final-sweep-findings.md`
  - `README.md`
  - `docs/runbooks/agent-docs/context-dispatch-matrix.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `skills/README.md`
  - `skills/tools/skill-management/README.md`
  - `skills/workflows/issue/issue-lifecycle/SKILL.md`
  - `skills/automation/issue-delivery-loop/SKILL.md`
  - `docker/agent-env/README.md`
  - `scripts/README.md`
  - `prompts/parallel-first.md`
  - `tests/fixtures/issue/issue_body_valid.md`
- **Description**: After targeted fixes, run a repo-wide markdown sweep for removed skill names, outdated aliases, and stale path references discovered in Sprint 1, then patch remaining stragglers and record no-change results for historical references that should remain.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 2.3
- **Complexity**: 7
- **Acceptance criteria**:
  - All P0/P1 findings from the review queue are either fixed or explicitly justified in `final-sweep-findings.md`.
  - Historical changelog mentions remain intact unless a new cleanup entry is intentionally added.
  - No current-facing doc catalogs present deleted skills as active.
- **Validation**:
  - `test -s out/docs-audit/final-sweep-findings.md`
  - `rg -n 'P[01]' out/docs-audit/review-queue.md`
  - `rg -n 'resolv' out/docs-audit/final-sweep-findings.md`
  - `rg -n 'justif' out/docs-audit/final-sweep-findings.md`
  - `rg -n 'waiv' out/docs-audit/final-sweep-findings.md`
  - `git diff -- '*.md'`
  - `rg -n 'deprecat' out/docs-audit/final-sweep-findings.md`
  - `rg -n 'remov' out/docs-audit/final-sweep-findings.md`
  - `rg -n 'renam' out/docs-audit/final-sweep-findings.md`

## Sprint 3: Consolidation and document reorganization
**Goal**: Reduce duplicated documentation maintenance by merging, moving, or clearly canonicalizing overlapping docs without breaking discoverability.
**Demo/Validation**:
- Command(s): `git diff --name-status`; `rg -n 'SKILLS_ANATOMY_V2' -g '*.md'`; `rg -n 'skills/README' -g '*.md'`
- Verify: Consolidation decisions are implemented and inbound links still point to an existing document or redirect note.
**Parallelizable tasks**:
- `Task 3.1` must complete first.
- `Task 3.2` and `Task 3.3` can proceed in parallel only when they touch different doc clusters.
- `Task 3.4` runs after move paths stabilize.

### Task 3.1: Finalize consolidation decisions and canonical-source map
- **Location**:
  - `out/docs-audit/consolidation-candidates.md`
  - `out/docs-audit/canonical-doc-map.md`
  - `docs/plans/repo-docs-skill-sync-reorg-plan.md`
- **Description**: Convert draft consolidation candidates into a final canonical-source map that states which docs are authoritative, which become summaries/redirects, and which are kept separate because they serve different audiences.
- **Dependencies**:
  - Task 2.4
- **Complexity**: 5
- **Acceptance criteria**:
  - Each consolidation candidate is tagged `merge`, `move`, `link-only`, or `keep-separate`.
  - Canonical ownership is explicit for skills anatomy, tooling index, and skill-management guidance docs.
  - Migration risks are listed for each `move` or `merge`.
- **Validation**:
  - `rg -n 'merge' out/docs-audit/canonical-doc-map.md`
  - `rg -n 'move' out/docs-audit/canonical-doc-map.md`
  - `rg -n 'link-only' out/docs-audit/canonical-doc-map.md`
  - `rg -n 'keep-separate' out/docs-audit/canonical-doc-map.md`
  - `rg -n 'skills/README.md' out/docs-audit/canonical-doc-map.md`
  - `rg -n 'docs/runbooks/skills/SKILLS_ANATOMY_V2.md' out/docs-audit/canonical-doc-map.md`

### Task 3.2: Execute low-risk merges and summary/redirect rewrites
- **Location**:
  - `skills/README.md`
  - `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`
  - `docs/runbooks/skills/TOOLING_INDEX_V2.md`
  - `skills/tools/skill-management/README.md`
- **Description**: Implement approved low-risk consolidations (for example, converting one duplicate doc into a short canonical summary that points to the authoritative doc) while preserving user navigation and context.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 8
- **Acceptance criteria**:
  - Consolidated docs clearly declare the canonical source and intended audience.
  - Duplicated sections are removed or replaced by concise summaries/links.
  - No critical usage instructions are lost during the merge/rewrite.
- **Validation**:
  - `git diff -- skills/README.md docs/runbooks/skills/SKILLS_ANATOMY_V2.md docs/runbooks/skills/TOOLING_INDEX_V2.md skills/tools/skill-management/README.md`
  - `rg -n 'canonical' skills/README.md docs/runbooks/skills/SKILLS_ANATOMY_V2.md docs/runbooks/skills/TOOLING_INDEX_V2.md skills/tools/skill-management/README.md`
  - `rg -n 'See .*for' skills/README.md docs/runbooks/skills/SKILLS_ANATOMY_V2.md docs/runbooks/skills/TOOLING_INDEX_V2.md skills/tools/skill-management/README.md`

### Task 3.3: Execute doc moves/renames and update inbound markdown links
- **Location**:
  - `out/docs-audit/canonical-doc-map.md`
  - `README.md`
  - `skills/README.md`
  - `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`
  - `scripts/README.md`
  - `docker/agent-env/README.md`
  - `prompts/parallel-first.md`
- **Description**: Perform any approved doc moves/renames, then update inbound markdown links and path references across the repo so navigation remains intact and grep-based discovery remains predictable.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 7
- **Acceptance criteria**:
  - Moved docs remain discoverable via updated links or redirect stubs.
  - No internal markdown links point to removed paths.
  - Path conventions remain consistent (`$AGENT_HOME/...` for executable entrypoints, repo-relative for non-executable docs).
- **Validation**:
  - `git diff --name-status -- '*.md'`
  - `rg -n '\\]\\([^)]*\\.md\\)' -g '*.md' README.md docs skills scripts docker prompts > /tmp/all-md-links.txt && wc -l /tmp/all-md-links.txt`
  - `rg -n '\\$AGENT_HOME/skills/.+/scripts/.+' -g '*.md' README.md docs skills scripts`

### Task 3.4: Reconcile templates and fixtures impacted by doc moves or wording changes
- **Location**:
  - `tests/fixtures/plan/valid-plan.md`
  - `tests/fixtures/issue/issue_body_valid.md`
  - `skills/workflows/issue/issue-subagent-pr/references/PR_BODY_TEMPLATE.md`
  - `skills/workflows/issue/issue-pr-review/references/REQUEST_CHANGES_TEMPLATE.md`
  - `docs/testing/script-regression.md`
  - `docs/testing/script-smoke.md`
- **Description**: Update markdown fixtures, reference templates, and testing docs that intentionally encode examples or expected wording so they remain valid after doc reorganization and terminology cleanup.
- **Dependencies**:
  - Task 3.2
  - Task 3.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Fixtures/templates that reference moved docs or renamed skills are updated.
  - Historical example fixtures that are intentionally stale are documented as fixtures, not mistaken for active docs.
  - Testing docs still match current command names and repo layout.
- **Validation**:
  - `git diff -- tests/fixtures docs/testing skills -- '*.md'`
  - `rg -n 'fixture' tests/fixtures -g '*.md'`
  - `rg -n 'example' tests/fixtures -g '*.md'`
  - `rg -n 'historical' tests/fixtures -g '*.md'`
  - `rg -n 'issue-' tests/fixtures skills/workflows/issue -g '*.md'`
  - `rg -n 'SKILLS_ANATOMY_V2' tests/fixtures skills/workflows/issue -g '*.md'`
  - `rg -n 'skills/README.md' tests/fixtures skills/workflows/issue -g '*.md'`

## Sprint 4: Final validation and handoff
**Goal**: Verify doc correctness end-to-end, run relevant repo checks, and produce a clear handoff summary for future maintenance.
**Demo/Validation**:
- Command(s): rerun audit scripts from Sprint 1; `scripts/check.sh --plans`; `plan-tooling validate`; targeted checks for touched skill docs
- Verify: Audit outputs are clean/justified, repo checks pass for the touched doc classes, and a handoff report captures what changed and what remains deferred.
**Parallelizable tasks**:
- `Task 4.1` and `Task 4.2` can run in parallel after Sprint 3 completes.
- `Task 4.3` depends on validated results from `Task 4.1` and `Task 4.2`.

### Task 4.1: Re-run full audit and close remaining findings
- **Location**:
  - `out/docs-audit/markdown-inventory-summary.md`
  - `out/docs-audit/reference-audit-summary.md`
  - `out/docs-audit/final-audit-report.md`
- **Description**: Re-run the inventory/drift checks after all doc edits, compare outputs against the baseline, and resolve or explicitly waive any remaining findings with rationale.
- **Dependencies**:
  - Task 3.4
- **Complexity**: 5
- **Acceptance criteria**:
  - Final audit report compares baseline vs post-change findings.
  - Remaining findings (if any) are documented with owner and follow-up recommendation.
  - No unresolved P0 correctness issues remain.
- **Validation**:
  - `test -f out/docs-audit/final-audit-report.md`
  - `rg -n 'P0' out/docs-audit/final-audit-report.md`
  - `rg -n 'waived' out/docs-audit/final-audit-report.md`
  - `rg -n 'follow-up' out/docs-audit/final-audit-report.md`

### Task 4.2: Run repo validations relevant to documentation changes
- **Location**:
  - `DEVELOPMENT.md`
  - `scripts/check.sh`
  - `docs/plans/repo-docs-skill-sync-reorg-plan.md`
  - `out/docs-audit/final-audit-report.md`
- **Description**: Run the minimum appropriate repo validations for the touched docs (always plan lint; add skill contract/layout checks when `SKILL.md` files changed; run targeted tests if doc-guard tests or fixture-based tests are affected).
- **Dependencies**:
  - Task 3.4
- **Complexity**: 6
- **Acceptance criteria**:
  - Validation commands are selected based on changed file classes and recorded in the handoff.
  - Failures are either fixed or documented with command output and impact.
  - At minimum, plan validation and relevant markdown-affecting checks are executed.
- **Validation**:
  - `scripts/check.sh --plans`
  - `scripts/check.sh --contracts --skills-layout`
  - `plan-tooling validate`

### Task 4.3: Publish cleanup summary and maintenance guardrails
- **Location**:
  - `out/docs-audit/handoff-summary.md`
  - `README.md`
  - `CHANGELOG.md`
  - `skills/tools/skill-management/README.md`
- **Description**: Produce a concise handoff summary of reviewed docs, fixed drifts, consolidation/move outcomes, and recommended guardrails (for example, using `git ls-files` for inventories and re-running catalog sync after skill create/remove changes).
- **Dependencies**:
  - Task 4.1
  - Task 4.2
- **Complexity**: 4
- **Acceptance criteria**:
  - The handoff lists changed docs, moved/merged docs, deferred items, and repeatable audit commands.
  - If a changelog entry is added, it reflects current cleanup work without rewriting historical entries.
  - Maintenance guardrails explain how to prevent future skill-doc drift.
- **Validation**:
  - `rg -n 'git ls-files' out/docs-audit/handoff-summary.md`
  - `rg -n 'catalog' out/docs-audit/handoff-summary.md`
  - `rg -n 'drift' out/docs-audit/handoff-summary.md`
  - `rg -n 'consolidation' out/docs-audit/handoff-summary.md`
  - `rg -n 'deferred' out/docs-audit/handoff-summary.md`
  - `git diff -- CHANGELOG.md README.md skills/tools/skill-management/README.md`

## Testing Strategy
- Unit: None (documentation-only scope), unless a touched tool/script is modified to support docs sync.
- Integration: Re-run audit scripts from Sprint 1 and compare baseline vs final outputs.
- E2E/manual:
  - Open root `README.md` and follow links to issue skills and skill-management docs.
  - Spot-check moved/consolidated docs for discoverability and audience clarity.
  - If `SKILL.md` files changed, verify referenced `scripts/...` entrypoints still exist.

## Risks & gotchas
- `rg --files` may honor ignore rules and omit tracked files; use `git ls-files` for authoritative tracked-doc inventory.
- Changelog entries are historical records; treat old references to removed skills as valid history unless adding a new cleanup entry.
- Over-consolidation can hurt discoverability if audience-specific docs (public README vs internal runbook) are merged without summaries.
- Doc moves can break hardcoded links in skill references, tests, and templates; link updates must be part of the same change set.
- Example placeholders such as `skills/...` should not be flagged as broken references during automated audits.

## Rollback plan
- Execute the cleanup in sprint-scoped commits so each phase can be reverted independently if a consolidation decision proves wrong.
- Before moving or merging docs, keep the original content in git history and prefer summary/redirect rewrites over immediate deletion for high-traffic docs.
- If a move breaks link resolution or tests, revert the move commit, restore the original path, and ship only correctness fixes first.
- Preserve audit artifacts under `out/docs-audit/` to compare pre/post states when deciding whether to re-apply a reverted consolidation.
