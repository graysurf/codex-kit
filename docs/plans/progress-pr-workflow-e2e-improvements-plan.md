# Plan: Progress PR workflow E2E tests & improvements

## Overview

This plan validates and hardens the end-to-end “progress PR → handoff → multiple stacked implementation PRs (via git worktree) → close/archive” workflow in `skills/workflows/pr/progress/`. It closes automated coverage gaps (especially around the worktree helper scripts), adds a repeatable real-`gh` E2E runbook/harness, executes the flow against a safe sandbox target, and iterates on scripts/docs until the workflow is deterministic and policy-compliant.

Primary success criteria: we can reliably create/merge/close a planning progress PR, spin up 2+ implementation PRs (stacked), and close the final PR with correct progress-file archival + link patching — while keeping local tests green and avoiding “manual glue”.

## Scope

- In scope:
  - Skills + scripts under `skills/workflows/pr/progress/`:
    - `create-progress-pr`, `handoff-progress-pr`, `worktree-stacked-feature-pr`, `close-progress-pr`, `progress-addendum`
  - The worktree helper scripts:
    - `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh`
    - `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh`
  - Automated tests in `tests/` for the above scripts and workflows (using the existing gh-stub harness).
  - A repeatable, safe real-`gh` E2E harness/runbook (guarded so it never runs in CI).
  - Documentation updates so “create → implement (stacked) → close” is a single coherent flow.
- Out of scope:
  - Changing GitHub org/repo settings (branch protection, merge methods, required checks).
  - Redesigning non-progress PR workflows unrelated to progress tracking.
  - Building a full generic framework for all repos (we target Codex Kit’s shipped skills + minimal assumptions).

## Assumptions

1. `gh auth status` succeeds on the machine executing the plan.
2. We can create and merge PRs in at least one safe sandbox target:
   - **Option A (recommended)**: a temporary GitHub repo created for E2E runs, OR
   - **Option B**: a temporary base branch in `graysurf/codex-kit` used only for E2E PR merges.
3. Base branch name is `main` (parameterize where possible).
4. Worktrees can be created under `<repo_root>/../.worktrees/<repo_name>/` (default policy in `worktree-stacked-feature-pr`).
5. We will store E2E logs and artifacts under `out/e2e/progress-pr-workflow/` (never `/tmp`).

## Sprint 1: Baseline audit + coverage gaps

**Goal**: lock down the invariants we expect from the workflow, then add automated tests for the missing parts (especially the worktree helpers).

**Demo/Validation**:
- Command(s):
  - `scripts/test.sh -m script_smoke -k 'progress or gh_workflows'`
  - `scripts/test.sh -m script_smoke -k worktree`
- Verify:
  - New tests pass locally.
  - We can reproduce failures with deterministic logs under `out/tests/`.

### Task 1.1: Map workflow invariants + edge cases

- **Complexity**: 4
- **Location**:
  - `docs/workflows/progress-pr-workflow.md`
- **Description**: Draft a contract-style doc for the progress PR workflow invariants and failure modes.
  - Write a concise “contract-style” doc for the full flow across skills:
    - progress PR creation (file + PR body link rules)
    - handoff (merge planning PR + patch Progress link to base branch)
    - stacked PR creation (PR base rules, progress link rules, planning PR link rules)
    - close (archive progress file + patch links + update planning PR body)
  - Include a short “Known failure modes” section that becomes the checklist for tests/E2E.
- **Dependencies**: none
- **Parallelizable**: yes (with Tasks 1.2–1.3)
- **Acceptance criteria**:
  - Doc lists the minimum invariants we will enforce with tests/E2E (links, base branches, cleanup, safety rules).
  - Doc includes the sandbox strategy (Option A/B) and cleanup rules.
- **Validation**:
  - `rg -n "## " docs/workflows/progress-pr-workflow.md` shows the expected sections (Progress, Handoff, Stacked PRs, Close, Failure modes).

### Task 1.2: Add fixture tests for worktree helper scripts

- **Complexity**: 7
- **Location**:
  - `tests/test_script_smoke_worktree_helpers.py`
  - `tests/fixtures/worktree-specs/worktree-basic.tsv`
  - `tests/fixtures/worktree-specs/worktree-invalid.tsv`
- **Description**: Add fixture-based tests for the worktree helper scripts (create + cleanup).
  - Build a local fixture repo (similar to `tests/test_script_smoke_gh_workflows.py`):
    - create a work tree + bare `origin.git`
    - create a baseline branch (default `main`)
  - Add tests that run:
    - `create_worktrees_from_tsv.sh` and assert:
      - the worktree root is `<repo_root>/../.worktrees/<repo_name>/`
      - each worktree path exists
      - each worktree has the expected branch checked out
    - `cleanup_worktrees.sh` and assert:
      - matching worktrees are removed
      - `git worktree list --porcelain` no longer lists them
  - Cover failure cases:
    - invalid TSV rows (wrong column count)
    - existing path collisions
- **Dependencies**: none
- **Parallelizable**: yes (with Tasks 1.1 and 1.3)
- **Acceptance criteria**:
  - Tests pass on macOS/Linux runners without needing real `gh`.
  - Failure cases assert on exit code + stderr regex.
- **Validation**:
  - `scripts/test.sh -m script_smoke -k worktree`

### Task 1.3: Decide (and document) what stays “real-gh only”

- **Complexity**: 3
- **Location**:
  - `docs/workflows/progress-pr-workflow.md`
- **Description**: Document which behaviors must be validated against real GitHub vs CI fixtures/stubs.
  - Explicitly separate:
    - behaviors we can validate in CI with fixtures + `tests/stubs/bin/gh`
    - behaviors we must validate against real GitHub (`gh pr create`, merge policies, base retargeting)
  - Define the required evidence from the real run (URLs, merged state, patched links, archived progress file).
- **Dependencies**: Task 1.1
- **Parallelizable**: no
- **Acceptance criteria**:
  - Doc includes an “Evidence checklist” for the real run that can be pasted into PR comments.
- **Validation**:
  - N/A (doc review)

## Sprint 2: Script/doc improvements (determinism + policy alignment)

**Goal**: implement low-risk fixes we already expect (commit policy, worktree safety, clearer docs), then keep tests green.

**Demo/Validation**:
- Command(s):
  - `scripts/check.sh --lint --contracts --tests -- -m script_smoke`
- Verify:
  - No new lint/contract violations.
  - Script smoke stays green.

### Task 2.1: Align `close_progress_pr.sh` with semantic commit policy

- **Complexity**: 6
- **Location**:
  - `skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh`
- **Description**: Remove direct `git commit` usage and align with the semantic commit helper.
  - Remove direct `git commit ...` usage.
  - Prefer calling the existing semantic-commit helper script:
    - `skills/tools/devex/semantic-commit/scripts/commit_with_message.sh`
  - Keep behavior deterministic:
    - commit only when there are staged changes
    - keep commit message stable (`docs(progress): archive <slug>`)
  - Ensure tests using fixture repos continue to pass.
- **Dependencies**:
  - Task 1.1
  - Task 1.2
- **Parallelizable**: yes (with Tasks 2.2–2.3, but watch for merge conflicts)
- **Acceptance criteria**:
  - `close_progress_pr.sh` no longer contains `git commit` invocations.
  - Existing `tests/test_script_smoke_gh_workflows.py` close-progress cases still pass.
- **Validation**:
  - `scripts/test.sh -m script_smoke -k close_progress_pr`

### Task 2.2: Harden `create_worktrees_from_tsv.sh` for real-world usage

- **Complexity**: 7
- **Location**:
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh`
- **Description**: Improve preflight checks and add safe/portable flags (adjust based on Sprint 3 findings).
  - Add clearer preflight errors:
    - detect un-fetched `start_point` and fetch from `origin` when needed (best-effort)
    - detect existing branch name collisions and fail with actionable guidance
  - Add optional flags for safe/portable runs:
    - `--worktrees-root <path>` override (so users can avoid `../.worktrees` if needed)
    - `--dry-run` to print planned worktrees without creating them
  - Emit a machine-readable summary artifact to `out/` (e.g., JSON with `branch`, `path`, `start_point`, `gh_base`) for follow-up automation.
- **Dependencies**: Task 1.2
- **Parallelizable**: yes (with Tasks 2.1 and 2.3)
- **Acceptance criteria**:
  - Fixture tests cover the new behavior (including `--dry-run` if added).
  - Script remains backwards compatible when invoked with only `--spec`.
- **Validation**:
  - `scripts/test.sh -m script_smoke -k worktree`
  - `bash -n skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh`

### Task 2.3: Make `cleanup_worktrees.sh` safer (and test it)

- **Complexity**: 5
- **Location**:
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh`
- **Description**: Add confirmation guards and a dry-run mode, and cover behavior with fixture tests.
  - Add a `--dry-run` mode that prints removals.
  - Add a `--yes` confirmation gate for destructive removals (default to dry-run or fail without `--yes`).
  - Keep the existing `--prefix` behavior, but reduce footguns.
- **Dependencies**: Task 1.2
- **Parallelizable**: yes (with Tasks 2.1 and 2.2)
- **Acceptance criteria**:
  - Fixture tests assert we don’t remove anything without explicit confirmation.
  - Script prints a clear summary (removed count + pruned).
- **Validation**:
  - `scripts/test.sh -m script_smoke -k cleanup_worktrees`
  - `bash -n skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh`

### Task 2.4: Update progress workflow docs to match the improved behavior

- **Complexity**: 4
- **Location**:
  - `skills/workflows/pr/progress/create-progress-pr/SKILL.md`
  - `skills/workflows/pr/progress/handoff-progress-pr/SKILL.md`
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/SKILL.md`
  - `skills/workflows/pr/progress/close-progress-pr/SKILL.md`
  - `skills/workflows/pr/progress/progress-addendum/SKILL.md`
  - `docs/workflows/progress-pr-workflow.md`
- **Description**: Update progress workflow docs to match the hardened scripts and intended evidence/links.
  - Ensure the skill docs:
    - reference the correct helper scripts + flags
    - clearly document the “stacked PR base” rules and the “after PR1 merges” retargeting workflow
    - explicitly call out where evidence should be recorded (PR body sections / comments)
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 2.3
- **Parallelizable**: yes (but easiest after scripts settle)
- **Acceptance criteria**:
  - No contradictions between SKILLs (especially Progress link rules).
  - `scripts/validate_skill_contracts.sh` passes.
- **Validation**:
  - `scripts/check.sh --contracts`

### Task 2.5: Add a repeatable real-`gh` E2E driver script (opt-in, never CI)

- **Complexity**: 8
- **Location**:
  - `scripts/e2e/progress_pr_workflow.sh`
  - `docs/workflows/progress-pr-workflow.md`
- **Description**: Add an opt-in real-`gh` E2E driver script with safety gates and durable artifacts.
  - Create a single entrypoint script that performs the Sprint 3 flow end-to-end using real GitHub:
    - hard safety gates:
      - refuse to run when `CI=true`
      - require `E2E_ALLOW_REAL_GH=1`
      - require clean git state (for the repo it operates in)
      - require `gh auth status` success
    - generate a `run-id` and write `out/e2e/progress-pr-workflow/<run-id>/run.json`
    - support sandbox selection:
      - Option A: create a temporary repo (default), OR
      - Option B: use a temporary base branch in an existing repo
    - support stepwise execution (so `/execute-plan-parallel` can run it incrementally), e.g.:
      - `--phase plan` (create planning progress PR)
      - `--phase handoff`
      - `--phase worktrees`
      - `--phase prs`
      - `--phase close`
      - `--phase cleanup`
    - create planning progress PR → handoff merge → create 2 stacked PRs via worktrees → merge → close progress
    - provide a deterministic cleanup mode that removes worktrees and deletes sandbox resources (after evidence capture)
  - Keep it “boringly bash”: explicit preflight checks, explicit failure messages, and durable artifacts in `out/`.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
  - Task 2.3
- **Parallelizable**: no
- **Acceptance criteria**:
  - Script exits non-zero with actionable errors when guards/prereqs fail.
  - Script always produces `run.json` (even on failure) with the last completed step and any created PR URLs.
  - Script never runs in CI (guard enforced).
- **Validation**:
  - `bash -n scripts/e2e/progress_pr_workflow.sh`
  - `scripts/e2e/progress_pr_workflow.sh --help` documents required env vars and cleanup.

### Task 2.6: Add a static policy check for forbidden `git commit` in progress scripts

- **Complexity**: 3
- **Location**:
  - `tests/test_no_direct_git_commit_in_progress_scripts.py`
  - `scripts/check.sh`
- **Description**: Add a static check that fails if progress scripts invoke `git commit` directly.
  - Add a small automated check that fails if any file under `skills/workflows/pr/progress/**/scripts/` contains a direct `git commit` invocation (exceptions must be explicit and justified).
- **Dependencies**: Task 2.1
- **Parallelizable**: yes
- **Acceptance criteria**:
  - The repo test suite fails fast if a future change reintroduces `git commit` directly in these scripts.
- **Validation**:
  - `scripts/test.sh -k git_commit_in_progress_scripts`

## Sprint 3: Real GitHub E2E run (create → handoff → stacked PRs → close)

**Goal**: run the full workflow against real GitHub using `gh`, capture evidence + logs, and identify gaps that CI tests can’t detect.

**Demo/Validation**:
- Command(s): documented in Task 3.3–3.7
- Verify:
  - Planning progress PR is merged and its Progress link points to `blob/<base>/docs/progress/...` (survives head-branch deletion).
  - Two implementation PRs exist:
    - PR1 base: `main`
    - PR2 base: PR1 branch (stacked) until PR1 merges
  - Final close run archives the progress file and patches PR body links correctly.

### Task 3.1: Pick a sandbox target and record it

- **Complexity**: 3
- **Location**:
  - `out/e2e/progress-pr-workflow/$RUN_ID/run.json`
- **Description**: Choose a sandbox target and record run metadata (repo/branch, PR IDs) in `run.json`.
  - Choose one:
    - **Option A (recommended)**: create a temporary GitHub repo (private) for the E2E run.
    - **Option B**: create a temporary base branch (e.g. `test/progress-e2e-<run-id>`) in `graysurf/codex-kit`.
  - Record the decision and identifiers in `out/` (repo URL, base branch, run-id, created PR numbers).
- **Dependencies**:
  - Task 2.5
- **Parallelizable**: no
- **Acceptance criteria**:
  - Artifact exists under `out/e2e/progress-pr-workflow/$RUN_ID/`.
  - Artifact includes enough info to clean up (repo name or branch name).
- **Validation**:
  - `ls out/e2e/progress-pr-workflow/$RUN_ID/run.json`

### Task 3.2: Preflight GitHub policy checks (mergeability, required reviews/checks)

- **Complexity**: 4
- **Location**:
  - `out/e2e/progress-pr-workflow/$RUN_ID/run.json`
- **Description**: Record mergeability and required-check signals for PRs before attempting merges.
  - Before attempting any merges, run and record:
    - `gh pr checks <pr>`
    - `gh pr view <pr> --json mergeable,mergeStateStatus,reviewDecision -q '[.mergeable,.mergeStateStatus,.reviewDecision] | @tsv'`
  - If blocked by policy, stop and record the blocking reason (don’t bypass).
- **Dependencies**:
  - Task 3.1
- **Parallelizable**: no
- **Acceptance criteria**:
  - We can distinguish “script bug” vs “repo policy blocked” from the recorded evidence.
- **Validation**:
  - Evidence is present in `run.json` for each PR that was attempted to merge.

### Task 3.3: Create a planning progress PR via real `gh`

- **Complexity**: 7
- **Location**:
  - `scripts/e2e/progress_pr_workflow.sh`
  - `docs/progress/YYYYMMDD_slug.md`
- **Description**: Create a planning progress PR via real `gh` and record its identifiers in `run.json`.
  - Preferred: `E2E_ALLOW_REAL_GH=1 scripts/e2e/progress_pr_workflow.sh --run-id <run-id> --phase plan` (writes PR URLs into `run.json`).
  - Manual fallback (if running without the driver script):
  - Use `create_progress_file.sh` to scaffold a progress file.
  - Fill all `[[...]]` placeholders (`TBD`/`None` where appropriate).
  - Create a planning branch `docs/progress/<yyyymmdd>-<slug>`, commit, push.
  - Create the PR via `gh pr create` (draft), ensuring PR body contains:
    - `## Progress` with a full blob URL to the progress file on the head branch.
    - `## Implementation PRs` section with the intended PR split (PRs TBD).
- **Dependencies**:
  - Task 3.1
- **Parallelizable**: no
- **Acceptance criteria**:
  - PR is visible on GitHub and contains exactly one `docs/progress/...` link under `## Progress`.
  - Placeholder check passes: `rg -n "\\[\\[.*\\]\\]" docs/progress -S` returns no matches.
- **Validation**:
  - `gh pr view "$PLANNING_PR" --json url,body -q .url`
  - `rg -n "\\[\\[.*\\]\\]" docs/progress -S`

### Task 3.4: Handoff/merge the planning PR and patch its Progress link

- **Complexity**: 5
- **Location**:
  - `skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh`
- **Description**: Merge the planning PR and patch its Progress link to the base branch.
  - Preferred: `E2E_ALLOW_REAL_GH=1 scripts/e2e/progress_pr_workflow.sh --run-id <run-id> --phase handoff`
  - Manual fallback:
  - Run the handoff script to merge the planning PR and patch the PR body progress link to base branch.
  - Confirm the head branch deletion does not break the Progress link.
- **Dependencies**:
  - Task 3.3
- **Parallelizable**: no
- **Acceptance criteria**:
  - Planning PR state is `MERGED`.
  - Planning PR body `## Progress` link points to `blob/$BASE_BRANCH/docs/progress/$PROGRESS_FILE`.
- **Validation**:
  - `gh pr view "$PLANNING_PR" --json state,body -q '[.state, .body] | @tsv'`

### Task 3.5: Create two worktrees + branches from a TSV spec

- **Complexity**: 6
- **Location**:
  - `out/e2e/progress-pr-workflow/$RUN_ID/pr-splits.tsv`
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh`
- **Description**: Create two worktrees from a TSV spec and make minimal scaffold commits in each.
  - Preferred: `E2E_ALLOW_REAL_GH=1 scripts/e2e/progress_pr_workflow.sh --run-id <run-id> --phase worktrees`
  - Manual fallback:
  - Create a TSV spec with at least:
    - PR1 branch (start `main`, gh_base `main`)
    - PR2 branch (start PR1 branch, gh_base PR1 branch)
  - Run the worktree creation script.
  - Make a “scaffold commit” in each worktree (small safe change).
- **Dependencies**:
  - Task 3.4
- **Parallelizable**: partially:
  - spec + worktree creation is sequential
  - **after** worktrees exist, scaffold commits can be parallelized (one per worktree)
- **Acceptance criteria**:
  - `git worktree list --porcelain` shows both worktrees.
  - Each worktree has the expected branch checked out.
- **Validation**:
  - `git worktree list --porcelain`

### Task 3.6: Create two implementation PRs (stacked) via real `gh`

- **Complexity**: 7
- **Location**:
  - `skills/workflows/pr/feature/create-feature-pr/references/PR_TEMPLATE.md`
- **Description**: Create two draft implementation PRs with correct stacked bases and required PR body links.
  - Preferred: `E2E_ALLOW_REAL_GH=1 scripts/e2e/progress_pr_workflow.sh --run-id <run-id> --phase prs`
  - Manual fallback:
  - For each branch:
    - push the branch
    - create a draft PR via `gh pr create` with correct base:
      - PR1 base: `main`
      - PR2 base: PR1 branch
    - ensure the PR body includes:
      - `## Progress` linking to `blob/main/docs/progress/<file>.md`
      - `## Planning PR` with `- #<planning_pr_number>`
- **Dependencies**:
  - Task 3.5
- **Parallelizable**: yes (one PR per worktree) **after** Task 3.4 finishes
- **Acceptance criteria**:
  - Two PRs exist, and the base branches are correct.
  - Both PRs reference the same progress file and planning PR number.
- **Validation**:
  - `gh pr view "$PR1" --json baseRefName,headRefName,body -q '[.baseRefName,.headRefName,.body] | @tsv'`
  - `gh pr view "$PR2" --json baseRefName,headRefName,body -q '[.baseRefName,.headRefName,.body] | @tsv'`

### Task 3.7: Merge PR1, then retarget/merge PR2, then close progress on the final PR

- **Complexity**: 8
- **Location**:
  - `skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh`
- **Description**: Merge PRs in order and run the close step on the final PR to archive progress and patch links.
  - Preferred: `E2E_ALLOW_REAL_GH=1 scripts/e2e/progress_pr_workflow.sh --run-id <run-id> --phase close`
  - Manual fallback:
  - Merge PR1 to base (`main`) and delete head branch.
  - For PR2:
    - rebase onto `main` (or keep stacked until mergeable, then retarget base)
    - ensure PR2’s base is `main` before final merge if that’s required by repo policy
  - Run `close_progress_pr.sh` on the **final** PR (PR2) to:
    - archive the progress file
    - patch the PR body `## Progress` link to base branch archived path
    - patch the planning PR body to include Implementation PR links
- **Dependencies**:
  - Task 3.6
- **Parallelizable**: no (ordering matters)
- **Acceptance criteria**:
  - Progress file is at `docs/progress/archived/$PROGRESS_FILE` on the base branch.
  - PR2 body `## Progress` links to `blob/$BASE_BRANCH/docs/progress/archived/$PROGRESS_FILE`.
  - Planning PR body contains `## Implementation PRs` and links to PR1 + PR2.
- **Validation**:
  - `gh pr view "$PR2" --json state,body -q '[.state, .body] | @tsv'`
  - `gh pr view "$PLANNING_PR" --json body -q .body`
  - `git show "$BASE_BRANCH:docs/progress/README.md" | rg -n "$PROGRESS_FILE" >/dev/null`

### Task 3.8: Cleanup worktrees + sandbox resources

- **Complexity**: 4
- **Location**:
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh`
  - `scripts/e2e/progress_pr_workflow.sh`
  - `out/e2e/progress-pr-workflow/$RUN_ID/run.json`
- **Description**: Remove worktrees and delete sandbox resources after evidence capture.
  - Preferred: `E2E_ALLOW_REAL_GH=1 scripts/e2e/progress_pr_workflow.sh --run-id <run-id> --phase cleanup`
  - Manual fallback:
  - Remove worktrees and prune.
  - Delete the sandbox repo (Option A) or delete the temporary base branch (Option B) **only after** evidence is captured.
- **Dependencies**:
  - Task 3.7
- **Parallelizable**: no
- **Acceptance criteria**:
  - `git worktree list --porcelain` no longer shows the created worktrees.
  - Sandbox resources are deleted (or explicitly kept with a reason).
- **Validation**:
  - `git worktree list --porcelain`

## Sprint 4: Iterate on findings + lock in regressions

**Goal**: convert Sprint 3 findings into deterministic fixes + tests, and ensure the full suite stays green.

**Demo/Validation**:
- Command(s):
  - `scripts/check.sh --all`
  - (Optional) re-run Sprint 3 with a fresh run-id
- Verify:
  - New regression tests cover every issue found in Sprint 3.
  - The real-gh run no longer needs ad-hoc manual edits beyond expected repo policy steps (e.g., approvals).

### Task 4.1: Add regression tests for issues found in the live run

- **Complexity**: 6
- **Location**:
  - `tests/test_progress_pr_workflow_regressions.py`
  - `tests/test_script_smoke_gh_workflows.py`
- **Description**: Turn Sprint 3 findings into deterministic fixture tests (and minimal fixes) for CI coverage.
  - For each issue discovered in Sprint 3, add a small fixture test that fails before the fix and passes after.
  - Prefer `tests/stubs/bin/gh` and fixture repos over real-gh for CI coverage.
- **Dependencies**:
  - Task 3.8
- **Parallelizable**: yes (one issue/test per subagent)
- **Acceptance criteria**:
  - Each live-run issue has a corresponding automated test (or an explicit justification for why it cannot be automated).
- **Validation**:
  - `scripts/test.sh -m script_smoke`

### Task 4.2: Final doc polish + “one-page runbook”

- **Complexity**: 4
- **Location**:
  - `docs/workflows/progress-pr-workflow.md`
  - `skills/workflows/pr/progress/worktree-stacked-feature-pr/SKILL.md`
- **Description**: Reduce ambiguity and add a one-page runbook/checklist for the workflow.
  - Reduce ambiguity:
    - exact required PR body sections
    - base/stack rules and “after merge” procedure
    - cleanup commands
  - Include a short “quickstart” checklist at the top.
- **Dependencies**: Task 4.1
- **Parallelizable**: yes
- **Acceptance criteria**:
  - A new contributor can run the flow by following the doc without reading the implementation scripts.
- **Validation**:
  - `scripts/check.sh --contracts`

## Testing Strategy

- Unit/fixture:
  - Extend existing pytest script-smoke tests that run scripts in a temporary git repo and use `tests/stubs/bin/gh`.
- Integration (local, no GitHub):
  - Worktree helpers run against a local bare `origin.git` fixture.
- E2E (real GitHub):
  - Sprint 3 run against Option A/B sandbox, capturing PR URLs + patched-link evidence.

## Risks & gotchas

- GitHub branch protections may block merges or require approvals; plan tasks must explicitly account for this (pause and record “blocked by policy” rather than hacking around it).
- Worktree paths can collide between runs; use a `run-id` prefix and ensure cleanup is deterministic.
- Running stacked PR workflows in parallel can cause conflicts; only parallelize tasks that touch disjoint files/worktrees.
- Deleting the sandbox base branch too early breaks “patched-to-base” links; keep it until evidence is captured.

## Rollback plan

- All script changes are isolated to `skills/workflows/pr/progress/**/scripts/`; rollback is a simple revert of the commit(s) touching those scripts.
- Any new E2E harness must be opt-in (requires explicit flags/env vars) so CI and normal usage remain unaffected.
- If worktree helper hardening causes unexpected breakage, keep backwards compatibility for `--spec` and guard new behaviors behind optional flags.
