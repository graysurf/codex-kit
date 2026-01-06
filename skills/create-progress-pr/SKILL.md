---
name: create-progress-pr
description: Create a traceable progress planning file under docs/progress/ from PROGRESS_TEMPLATE.md, capturing goals/acceptance criteria/scope/I-O contract/decisions/risks/step checklist, then open a GitHub PR with gh (no feature implementation yet). Use when the user and Codex have aligned on a new feature and want an executable plan to guide future work and review.
---

# Create Progress PR

## Setup

- Load commands with `source ~/.codex/tools/_codex-tools.zsh`
- Work from the target repo root.
- Ensure `gh auth status` succeeds.
- Ensure the working tree is clean (stash or commit unrelated work first).

## Inputs (minimum)

- Short title (used in H1, slug, and PR title).
- Goals (2–5 bullets).
- Acceptance criteria (verifiable; include commands/queries when applicable).
- Scope boundaries (in-scope / out-of-scope).
- I/O contract (inputs, outputs, intermediate artifacts).
- Decisions (rationale + trade-offs) and known risks/uncertainties.
- Step checklist (Step 0..N) with work items, artifacts, and exit criteria.

If information is missing, ask brief targeted questions. If still unknown, use `TBD` and record the gap explicitly as an open question under Risks/Uncertainties and/or Step 0 Exit Criteria.

## Templates (default vs project)

- Default (preferred):
  - PR body template: `references/PR_TEMPLATE.md`
  - Progress templates:
    - `references/PROGRESS_TEMPLATE.md`
    - `references/PROGRESS_GLOSSARY.md`
- Project templates (use only when the user explicitly asks to use the repo’s templates):
  - Progress templates:
    - `docs/templates/PROGRESS_TEMPLATE.md`
    - `docs/templates/PROGRESS_GLOSSARY.md`
  - PR body template (GitHub standard locations; pick the project’s canonical one):
    - `.github/pull_request_template.md` / `.github/PULL_REQUEST_TEMPLATE.md`
    - `.github/PULL_REQUEST_TEMPLATE/*.md`

Upstream reference (example):

- `/Users/terry/Project/rytass/WebCrawler/docs/progress/archived/20260105_crawl_pipeline_architecture.md`

## File naming

- Create `docs/progress/<YYYYMMDD>_<feature_slug>.md`.
- `feature_slug` rules: lowercase; replace non-alphanumeric with `-`; collapse `-`; trim to ~3–6 words.
- Set status to `DRAFT` by default (`IN PROGRESS` only if implementation starts immediately).
- Set `Created` / `Updated` to today (`YYYY-MM-DD`).

## Authoring rules

- Replace every `[[...]]` placeholder token (use `TBD` if unknown).
- Follow the glossary language policy: headings/labels/narrative in English; keep paths/commands/identifiers as code.
- Make the checklist executable:
  - Each Step has Work Items, Artifacts, Exit Criteria.
  - Exit Criteria includes verification commands/queries plus where evidence/logs live.
- Keep “unknowns” explicit and actionable (what is unknown + how to resolve).

## Index update (if `docs/progress/README.md` exists)

- Add a row under “In progress”:
  - Date: `YYYY-MM-DD`
  - Feature: short title
  - PR: `TBD` (or `[#<number>](<url>)` after PR creation)

## Validate before commit

- Ensure no placeholders remain: `rg -n "\\[\\[.*\\]\\]" docs/progress -S` should return no output.
- Ensure progress index PR links are well-formed: `scripts/validate_progress_index.sh` should succeed.

## Optional helper scripts

- Create a new progress file skeleton (defaults to this skill’s templates; use `--use-project-templates` only when requested):
  - `scripts/create_progress_file.sh --title "<short title>"`
- Validate progress index formatting:
  - `scripts/validate_progress_index.sh`
- Render templates for copy/paste or `gh pr create --body-file ...`:
  - `scripts/render_progress_pr.sh --pr`
  - `scripts/render_progress_pr.sh --progress-template`
  - `scripts/render_progress_pr.sh --glossary`
  - Add `--project` to use the repo’s templates (only when requested).

## Branch / commit / PR

- Branch naming:
  - Prefix: `docs/progress/`
  - Form: `docs/progress/<yyyymmdd>-<feature_slug>`
  - If a ticket ID like `ABC-123` exists, prefix it (example: `docs/progress/abc-123-<yyyymmdd>-<slug>`).
- Commit only progress-related docs; do not implement feature code in this skill.
- Commit message: `docs(progress): add <short title>` (or use the `commit-message` skill).
- Push and open a PR with `gh` (draft by default unless the user asks otherwise).
- PR body must include a full GitHub blob URL link to the progress file (PR bodies resolve relative links under `/pull/`):
  - `[docs/progress/<file>.md](https://github.com/<owner>/<repo>/blob/<branch>/docs/progress/<file>.md)`

If using the project’s PR template, patch the body to include the Progress link (do not assume the project template already has it).

After PR creation, replace `TBD` PR links in both the progress file and `docs/progress/README.md`, then commit and push the update (optional but preferred).

## Output (chat response)

- Use `references/OUTPUT_TEMPLATE.md` as the response format.
- Use `scripts/render_progress_pr.sh --output` to generate the output template quickly.
- If there are no open questions or next steps, write `None` under those sections (do not leave them blank).
