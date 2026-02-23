---
name: create-bug-pr
description: Create a new bugfix branch, open a draft implementation PR early, and continue implementation in the same PR using standardized templates.
---

# Create Bug PR

## Contract

Prereqs:

- Run inside the target git repo with a clean working tree (or stash unrelated changes).
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- `$AGENT_HOME` points at the repo root (or tools are otherwise available).

Inputs:

- Required: bug summary + expected vs actual behavior.
- Optional: kickoff artifacts already prepared (for example plan/scaffold/docs files) to commit before opening the PR.

Outputs:

- A new branch `fix/<slug>`, one or more commits, and a GitHub draft PR created via `gh`.
- PR title/body describe the target bug-fix outcome (not a kickoff commit subject).
- When kickoff artifacts already exist, they can be committed first and used to open the draft PR before implementation code lands.
- PR body populated from `$AGENT_HOME/skills/automation/find-and-fix-bugs/references/PR_TEMPLATE.md`.

Exit codes:

- N/A (multi-command workflow; failures surfaced from underlying `git`/`gh` commands)

Failure modes:

- Dirty working tree or wrong base branch.
- Missing `gh` auth or insufficient permissions to push/create PR.
- Missing bug summary/expected vs actual context (cannot produce an outcome-oriented PR).
- PR title/body follows a housekeeping commit subject (for example `Add plan file`) instead of the bug-fix outcome.
- PR body missing required sections.

## Preflight (mandatory)

1. Confirm runtime intent:
   - `kickoff-only`: open draft implementation PR now, implementation continues later.
   - `kickoff+implementation`: open draft PR now and continue implementation in the same turn.
2. Collect required bug context:
   - bug summary + expected vs actual behavior (required before PR creation).
3. If required context is missing:
   - ask for a 1-2 sentence bug-fix outcome and expected behavior.
   - do not derive PR title/body from `git log -1 --pretty=%B`.
4. Confirm kickoff artifacts in scope (if present) and commit them before opening the PR.

## Inputs

- Prefer explicit user bug description and expected behavior.
- If still unclear, ask for a 1-2 sentence bug summary and expected behavior.
- Do not use a latest commit subject as PR narrative input; commits like `Add plan file` are not valid PR title/body sources.
- Existing plan/scaffold files can be committed first, then used to open the draft PR.

## Branch naming

- Prefix: `fix/`.
- Build the slug from the bug summary.
- Slug rules: lowercase; replace non-alphanumeric with hyphens; collapse hyphens; trim to 3-6 words.
- If a ticket ID like ABC-123 appears, prefix it: `fix/abc-123-<slug>`.

## Workflow

1. Run preflight (above) and stop if required bug context remains missing.
2. Confirm the working tree is clean; stash or commit unrelated changes if needed.
3. Determine the base branch (default `origin/HEAD`); ask if unclear.
4. Create the branch: `git checkout -b fix/<slug>`.
5. If kickoff artifacts already exist (plan/scaffold/docs), commit them first:
   - use `$semantic-commit-autostage` skill by default.
   - implement it via the autostage flow defined by that skill (`git add` + `semantic-commit ...`).
   - use `semantic-commit` only when the user has explicitly staged a reviewed subset.
6. Generate PR body from `$AGENT_HOME/skills/automation/find-and-fix-bugs/references/PR_TEMPLATE.md`.
7. Push the branch and open a draft PR immediately:
   - `gh pr create --draft ...`
8. Continue implementation on the same PR (code + tests), updating `## Issues Found` status and testing notes as implementation changes.

## PR rules

- Title: capitalize the first word; reflect the bug-fix outcome; never mirror a housekeeping commit subject.
- Replace the first H1 line in `$AGENT_HOME/skills/automation/find-and-fix-bugs/references/PR_TEMPLATE.md` with the PR title.
- Body narrative (`Summary`, `Problem`, `Reproduction`, `Issues Found`, `Fix Approach`, `Testing`, `Risk / Notes`) must describe the intended bug-fix outcome even when the first commit is kickoff-only.
- Always include `Summary`, `Problem`, `Reproduction`, `Issues Found`, `Fix Approach`, `Testing`, and `Risk / Notes`.
- If tests are not run, state "not run (reason)".
- Use `$AGENT_HOME/skills/workflows/pr/bug/create-bug-pr/scripts/render_bug_pr.sh --pr` to generate the PR body quickly.
  - run with `--pr`.
- Open draft PRs by default; only open non-draft when the user explicitly requests it.

## Output

- Use `$AGENT_HOME/skills/automation/find-and-fix-bugs/references/ASSISTANT_RESPONSE_TEMPLATE.md` as the response format.
- Use `$AGENT_HOME/skills/workflows/pr/bug/create-bug-pr/scripts/render_bug_pr.sh --output` to generate the output template quickly.
