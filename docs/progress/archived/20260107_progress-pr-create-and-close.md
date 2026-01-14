# codex-kit: Progress PR create and close

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-07 | 2026-01-07 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/5
- Docs: `README.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Add a standard “progress file” workflow for new requirements (create + close) in `codex-kit`.
- Ensure PRs remain traceable over time (progress links survive branch deletion).
- Keep responsibilities separated: feature PR management vs progress file management.

## Acceptance Criteria

- A `create-progress-pr` skill exists that can generate a progress file and open a PR using a default template (with an opt-in project-template mode).
- A `close-progress-pr` skill exists that can finalize/archive the progress file, update the progress index, merge the PR, and patch the PR body Progress link to the base branch.
- `close-feature-pr` is paired with `create-feature-pr` and does not handle progress files.
- `create-feature-pr` output is PR-focused (no `git-scope` requirement) and supports linking to a progress file.

## Scope

- In-scope:
  - Add/update skills under `skills/`:
    - `create-progress-pr`, `close-progress-pr`
    - Align `close-feature-pr` with `create-feature-pr`
    - Adjust `create-feature-pr` output format to be PR-only
  - Add progress scaffolding under `docs/`:
    - `docs/progress/` (progress files + index)
    - `docs/templates/` (progress templates + glossary)
  - Add small deterministic scripts under skill folders to reduce repeated manual work
- Out-of-scope:
  - Enforcing progress files via CI checks across all repos
  - Implementing any business feature code outside `codex-kit`
  - Packaging/distributing `.skill` artifacts (optional; defer)

## I/O Contract

### Input

- Requirement summary with enough context to plan:
  - short title, goals, acceptance criteria, scope
  - known risks/unknowns and how to resolve them
- Target repo available locally with GitHub remote accessible via `gh`
- Template preference:
  - default templates (preferred)
  - project templates only when explicitly requested

### Output

- Progress file: `docs/progress/20260107_progress-pr-create-and-close.md` (later archived)
- Updated progress index: `docs/progress/README.md`
- GitHub PR(s) created/closed for the progress plan and (later) implementation changes

### Intermediate Artifacts

- PR body containing a full GitHub blob URL to the progress file
- Branch names:
  - progress plan: `docs/progress/<yyyymmdd>-<feature_slug>`
  - implementation: `feat/<slug>` (separate)
- Evidence (logs/commands) recorded in PR comments or referenced paths when needed

## Design / Decisions

### Rationale

- Default templates shipped inside the skill keep the workflow consistent and runnable even when a repo has no `docs/templates/` yet.
- Project templates are opt-in to avoid surprising repo-specific formatting unless the user requests it.
- Separate skills (`create-progress-pr`, `close-progress-pr`, `create-feature-pr`, `close-feature-pr`) reduce accidental scope creep and keep each workflow deterministic.
- Patch PR body Progress links to base branch after merge to avoid broken links from deleted head branches.

### Risks / Uncertainties

- Repos may use different `docs/progress/README.md` formats; index update should be best-effort and warn when it cannot patch.
- PR bodies may include multiple `docs/progress/...` links; close scripts should require `--progress-file` in ambiguous cases.
- `gh pr merge` behavior depends on repo policy (required reviews, merge method restrictions); scripts should fail fast with actionable errors.

## Steps (Checklist)

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm naming conventions (skill names, branch prefixes, progress filename rules).
    - [x] Confirm default vs project template rules (explicit opt-in for project templates).
    - [x] Confirm PR hygiene expectations for feature PRs (required sections + testing notes).
  - Artifacts:
    - `docs/progress/20260107_progress-pr-create-and-close.md` (this file)
    - `docs/templates/PROGRESS_TEMPLATE.md`
    - `docs/templates/PROGRESS_GLOSSARY.md`
    - `docs/progress/README.md`
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned (this document is complete).
    - [x] No progress placeholders remain: `rg -n "\\[\\[.*\\]\\]" docs/progress -S` returns no output.
    - [x] Default commands/ to validate behavior are listed under later steps.
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Add `create-progress-pr` skill with:
      - default templates (PR + progress + glossary)
      - scripts to create a progress file and render templates
      - explicit rules for “write `None` when empty” sections
    - [x] Ensure the skill defaults to docs-only changes for the progress PR.
  - Artifacts:
    - `skills/workflows/pr/progress/create-progress-pr/SKILL.md`
    - `skills/workflows/pr/progress/create-progress-pr/references/PR_TEMPLATE.md`
    - `skills/workflows/pr/progress/create-progress-pr/references/PROGRESS_TEMPLATE.md`
    - `skills/workflows/pr/progress/create-progress-pr/references/PROGRESS_GLOSSARY.md`
    - `skills/workflows/pr/progress/create-progress-pr/references/OUTPUT_TEMPLATE.md`
    - `skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh`
    - `skills/workflows/pr/progress/create-progress-pr/scripts/render_progress_pr.sh`
  - Exit Criteria:
    - [x] `bash -n skills/workflows/pr/progress/create-progress-pr/scripts/*.sh` passes.
    - [x] Create a progress file in this repo: `skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh --title "X"`.
    - [x] Placeholder check passes: `rg -n "\\[\\[.*\\]\\]" docs/progress -S` returns no output (after filling).
- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Add `close-progress-pr` skill and an automation script to:
      - locate the progress file (prefer PR body Progress link)
      - set Status to `DONE` and update dates/PR link
      - move to `docs/progress/archived/` and update index
      - merge PR and patch PR body Progress link to base branch
    - [x] Refactor `close-feature-pr` to match `create-feature-pr` (no progress handling).
    - [x] Update `create-feature-pr` output to be PR-focused (no `git-scope` section).
  - Artifacts:
    - `skills/workflows/pr/progress/close-progress-pr/SKILL.md`
    - `skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh`
    - `skills/workflows/pr/feature/close-feature-pr/SKILL.md`
    - `skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh`
    - `skills/workflows/pr/feature/create-feature-pr/SKILL.md`
    - `skills/workflows/pr/feature/create-feature-pr/references/OUTPUT_TEMPLATE.md`
    - `README.md`
  - Exit Criteria:
    - [x] `bash -n skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh` passes.
    - [x] `close-feature-pr` no longer mentions or edits progress files.
    - [x] `create-feature-pr` output template contains only PR-related info.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Dry-run `create-progress-pr` in this repo: create a progress PR using the templates and scripts.
    - [x] Verify the PR body contains a full blob URL to the progress file on the head branch.
    - [x] Run `close-progress-pr` on a test PR and confirm:
      - progress file is archived
      - PR body Progress link points to the base branch
  - Artifacts:
    - PR URLs for the progress PR and a test close run (or record “not run” with reasons)
    - Evidence logs in PR comments or local command outputs
  - Exit Criteria:
    - [x] Progress PR created successfully and links resolve.
    - [x] Close flow validated at least once (or explicitly deferred with a follow-up plan).
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Merge the progress PR (this PR) and ensure the progress file is updated with the PR URL.
    - [x] After implementation is complete, set Status to `DONE`, archive, and update index.
  - Artifacts:
    - `docs/progress/archived/20260107_progress-pr-create-and-close.md`
  - Exit Criteria:
    - [x] Archived progress file exists and index is updated.
    - [x] PR body Progress link points to the base branch (survives branch deletion).

## Modules

- `skills/workflows/pr/progress/create-progress-pr`: Create a docs-only progress planning PR (templates + scripts).
- `skills/workflows/pr/progress/close-progress-pr`: Finalize/archive progress and patch PR links to base branch after merge.
- `skills/workflows/pr/feature/create-feature-pr`: Create implementation PRs that reference a progress file.
- `skills/workflows/pr/feature/close-feature-pr`: Close feature PRs after hygiene review (no progress handling).
