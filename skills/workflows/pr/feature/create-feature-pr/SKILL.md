---
name: create-feature-pr
description: Create a new feature branch, open a draft implementation PR early, and continue implementation in the same PR using standardized templates.
---

# Create Feature PR

## Contract

Prereqs:

- Run inside the target git repo with a clean working tree (or stash unrelated changes).
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- `$AGENTS_HOME` points at the repo root (or tools are otherwise available).

Inputs:

- Required: feature summary + acceptance criteria.
- Optional: kickoff artifacts already prepared (for example plan/progress/scaffold/docs files) to commit before opening the PR.
- Optional (only when this feature PR is created from a progress PR): planning PR number and progress file reference.

Outputs:

- A new branch `feat/<slug>`, one or more commits, and a GitHub draft PR created via `gh`.
- PR title/body describe the target feature outcome (not a kickoff commit subject).
- When kickoff artifacts already exist, they can be committed first and used to open the draft PR before implementation code lands.
- PR body populated from `references/PR_TEMPLATE.md` (include a full GitHub URL to the progress file when provided).

Exit codes:

- N/A (multi-command workflow; failures surfaced from underlying `git`/`gh` commands)

Failure modes:

- Dirty working tree or wrong base branch.
- Missing `gh` auth or insufficient permissions to push/create PR.
- Missing feature summary/acceptance criteria (cannot produce an outcome-oriented PR).
- PR title/body follows a housekeeping commit subject (for example `Add plan file`) instead of the feature outcome.
- PR body missing required sections; if using a progress file, missing/invalid progress link.

## Preflight (mandatory)

1. Confirm runtime intent:
   - `kickoff-only`: open draft implementation PR now, implementation continues later.
   - `kickoff+implementation`: open draft PR now and continue implementation in the same turn.
2. Collect required feature context:
   - feature summary + acceptance criteria (required before PR creation).
   - optional progress file URL and/or planning PR number.
3. If summary/criteria are missing:
   - ask for a 1-2 sentence feature outcome and expected behavior.
   - do not derive PR title/body from `git log -1 --pretty=%B`.
4. Confirm kickoff artifacts in scope (if present) and commit them before opening the PR.

## Inputs

- Prefer explicit user feature description and acceptance criteria.
- If still unclear, ask for a 1-2 sentence feature summary and expected behavior.
- Do not use a latest commit subject as PR narrative input; commits like `Add plan file` are not valid PR title/body sources.
- Existing plan/progress/scaffold files can be committed first, then used to open the draft PR.

## Branch naming

- Prefix: `feat/`.
- Build the slug from the feature summary.
- Slug rules: lowercase; replace non-alphanumeric with hyphens; collapse hyphens; trim to 3-6 words.
- If a ticket ID like ABC-123 appears, prefix it: `feat/abc-123-<slug>`.

## Workflow

1. Run preflight (above) and stop if feature summary/acceptance criteria remain missing.
2. Confirm the working tree is clean; stash or commit unrelated changes if needed.
3. Determine the base branch (default `origin/HEAD`); ask if unclear.
4. Create the branch: `git checkout -b feat/<slug>`.
5. If kickoff artifacts already exist (plan/progress/scaffold/docs), commit them first:
   - use `$semantic-commit-autostage` skill by default.
   - implement it via the autostage flow defined by that skill (`git add` + `semantic-commit ...`).
   - use `semantic-commit` only when the user has explicitly staged a reviewed subset.
6. Generate PR body from `references/PR_TEMPLATE.md`.
7. Push the branch and open a draft PR immediately:
   - `gh pr create --draft ...`
8. Continue implementation on the same PR (code + tests), updating PR body/testing notes as progress changes.

## PR rules

- Title: capitalize the first word; reflect the feature outcome; never mirror a housekeeping commit subject.
- Replace the first H1 line in `references/PR_TEMPLATE.md` with the PR title.
- Body narrative (`Summary`, `Changes`, `Risk / Notes`) must describe the intended feature outcome even when the first commit is kickoff-only.
- Progress (optional):
  - Use this section only when the feature PR is derived from a progress PR.
  - Generate by passing `--from-progress-pr` plus either:
    - `--progress-url <full-github-url>`, or
    - `--progress-file docs/progress/<file>.md` (script auto-resolves full URL from origin remote + current branch).
  - If no progress file, omit the `## Progress` section entirely (do not write `None`).
- Planning PR (optional):
  - Use this section only when the feature PR is derived from a progress PR.
  - If this feature work follows a planning PR, add `## Planning PR` and reference it as `- #<number>` (no extra text/URL).
  - If no planning PR, omit the `## Planning PR` section entirely (do not write `None`).
- Always include Summary, Changes, Testing, and Risk/Notes sections.
- If tests are not run, state "not run (reason)".
- Use `$AGENTS_HOME/skills/workflows/pr/feature/create-feature-pr/scripts/render_feature_pr.sh --pr` to generate the PR body quickly.
  - Non-progress flow: run with `--pr` only (no `Progress`/`Planning PR` sections).
  - Progress-derived flow: add `--from-progress-pr --planning-pr <number>` and either `--progress-url <full-github-url>` or `--progress-file docs/progress/<file>.md`.
- Open draft PRs by default; only open non-draft when the user explicitly requests it.

## Output

- Use `references/ASSISTANT_RESPONSE_TEMPLATE.md` as the response format.
- Use `$AGENTS_HOME/skills/workflows/pr/feature/create-feature-pr/scripts/render_feature_pr.sh --output` to generate the output template quickly.
