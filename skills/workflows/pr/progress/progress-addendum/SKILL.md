---
name: progress-addendum
description: Add an append-only Addendum section to DONE progress files (top-of-file), with audit + template scripts to keep archived docs from going stale.
---

# Progress Addendum (post-DONE updates)

## Contract

Prereqs:

- Run inside the target git repo (any subdir is fine).
- `git` available on `PATH`.
- `python3` available on `PATH`.

Inputs:

- A progress file path under `docs/progress/**/*.md` (typically `docs/progress/archived/<YYYYMMDD>_<slug>.md`).
- Update date (`YYYY-MM-DD`; default: today) and the addendum content you will fill in.

Outputs:

- Progress file updated with a `## Addendum` section placed immediately after `Links:` (before `## Goal`).
- `Updated` date updated (only when adding an addendum entry).
- Audit script exits non-zero and prints errors to stderr when conventions are violated.

Exit codes:

- `0`: success
- non-zero: invalid args, missing file, malformed progress file, or audit failures

Failure modes:

- Progress file missing the canonical `Links:` section.
- Multiple `## Addendum` sections detected.
- File status is not `DONE` (unless `--allow-not-done` is set).
- `## Addendum` exists but is not the first `## ...` section after `Links:`.

## Principles (3a: append-only at the top)

- Goal: prevent DONE progress files from going stale without rewriting history.
- Canonical placement: `## Addendum` lives immediately after `Links:` and before the rest of the document (typically `## Goal`).
- Post-DONE edits should be limited to:
  - `## Addendum` (append-only notes)
  - the header table’s `Updated` date (to reflect the addendum entry)
- If the change is large, prefer creating a new progress file / PR and link it from the Addendum instead of editing the original `Goal / Acceptance Criteria / Scope / Steps`.

## Entry format (recommended)

```md
### YYYY-MM-DD

- Change: ...
- Reason: ...
- Impact: ...
- Links: ...
```

## Scripts

- Add a new entry template into a DONE progress file (and bump `Updated`):
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh --file docs/progress/archived/<file>.md`
- Add an entry and link to an existing follow-up progress file:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh --file docs/progress/archived/<file>.md --followup-progress docs/progress/<YYYYMMDD>_<slug>.md`
- Create a new follow-up progress file (skeleton) and link it from the Addendum entry:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh --file docs/progress/archived/<file>.md --followup-title "<short title>"`
- Ensure a DONE file has `## Addendum` (insert `- None` if missing; does not change `Updated`):
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh --file docs/progress/archived/<file>.md --ensure-only`
- Print a copy/paste entry template (no file edits):
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/progress_addendum.sh --print-entry`
- Audit progress files for Addendum placement/format:
  - `$CODEX_HOME/skills/workflows/pr/progress/progress-addendum/scripts/audit_progress_addendum.sh`
  - Optional stricter checks:
    - `.../audit_progress_addendum.sh --require-addendum --check-updated`
    - `.../audit_progress_addendum.sh --require-links`
    - `.../audit_progress_addendum.sh --require-progress-link`
