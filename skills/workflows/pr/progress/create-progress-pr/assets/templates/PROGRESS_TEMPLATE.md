# [[feature]]: [[short title]]

| Status | Created | Updated |
| --- | --- | --- |
| [[DRAFT\|IN PROGRESS\|DONE]] | [[YYYY-MM-DD]] | [[YYYY-MM-DD]] |

Links:

- PR: [[[repository/pull/number](url) or TBD]]
- Docs: [[url or path or TBD or None]]
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- [[goal 1]]
- [[goal 2]]

## Acceptance Criteria

- [[acceptance criteria 1]]
- [[acceptance criteria 2]]

## Scope

- In-scope:
  - [[item]]
- Out-of-scope:
  - [[item]]

## I/O Contract

### Input

- [[input path]]

### Output

- [[output path]]

### Intermediate Artifacts

- [[artifact path]]

## Design / Decisions

### Rationale

- [[tradeoff / why]]

### Risks / Uncertainties

- [[risk]]
- [[mitigation]]

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, close-progress-pr will auto-wrap the item text with Markdown strikethrough (use `- [ ] ~~like this~~`).

- [ ] Step 0: [[Alignment / prerequisites]]
  - Work Items:
    - [ ] [[work item]]
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - [[notes / dataset / commands]]
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned: [[notes]]
    - [ ] Data flow and I/O contract are defined (including DB schema/table, if applicable): [[notes]]
    - [ ] Risks, rollback plan, and migration/backfill strategy are defined: [[notes]]
    - [ ] Minimal reproducible verification data and commands are defined: [[command + dataset]]
- [ ] Step 1: [[Minimum viable output (MVP)]]
  - Work Items:
    - [ ] [[work item]]
  - Artifacts:
    - [[artifact paths]]
    - [[docs path]]
  - Exit Criteria:
    - [ ] At least one happy path runs end-to-end (CLI/script/API): [[command]]
    - [ ] Primary outputs are verifiable (files/DB/progress docs): [[artifact paths]]
    - [ ] Usage docs skeleton exists (TL;DR + common commands + I/O contract): [[docs path]]
- [ ] Step 2: [[Expansion / integration]]
  - Work Items:
    - [ ] [[work item]]
  - Artifacts:
    - [[sql/scripts]]
    - [[notes]]
  - Exit Criteria:
    - [ ] Common branches are covered (e.g. overwrite/skip/rerun/error handling): [[cases]]
    - [ ] Compatible with existing pipelines and naming conventions (no dataflow breakage): [[notes]]
    - [ ] Required migrations / backfill scripts and documentation exist: [[sql/scripts + notes]]
- [ ] Step 3: [[Validation / testing]]
  - Work Items:
    - [ ] [[work item]]
  - Artifacts:
    - [[test results]]
    - [[logs / evidence]]
  - Exit Criteria:
    - [ ] Validation and test commands executed with results recorded: [[commands + results]]
    - [ ] Run with real data or representative samples (including failure + rerun after fix): [[basenames + log paths]]
    - [ ] Traceable evidence exists (logs, reports, SQL outputs, screenshots, etc.): [[evidence]]
- [ ] Step 4: [[Release / wrap-up]]
  - Work Items:
    - [ ] [[work item]]
  - Artifacts:
    - [[version / changelog / release notes / links]]
  - Exit Criteria:
    - [ ] Versioning and changes recorded: [[version]], [[CHANGELOG]], [[release notes]] (new content at the top)
    - [ ] Release actions completed: [[tag/release/deploy steps]], [[release link]]
    - [ ] Documentation completed and entry points updated (README / docs index links): [[links]]
    - [ ] Cleanup completed (close issues, remove temporary flags/files, set status to DONE): [[notes]]

## Modules

- [[module]]: [[responsibility]]
