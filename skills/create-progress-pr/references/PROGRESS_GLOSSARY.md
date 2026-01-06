# Progress Glossary (Progress Files)

Purpose: Standardize the structure and terminology used in `docs/progress/**/*.md` so progress files
remain consistent across features and contributors.

References:

- Template: `docs/templates/PROGRESS_TEMPLATE.md`
- Rules (naming, archiving, index): `docs/progress/README.md`

## Language Policy

- All headings, labels, and narrative content: English.
- Paths / commands / identifiers: keep as-is and format as code (e.g. `output/...`, `ruff check .`).

## Terms

| Term | Definition | Notes |
| --- | --- | --- |
| Goal | The desired outcome state of the work. | Focus on outcomes; typically 2–5 bullets. |
| Acceptance Criteria | Objective criteria used to consider the work “done”. | Must be verifiable; use `TBD` when unknown. |
| Scope | What is included and excluded. | Use `In-scope` / `Out-of-scope` to define boundaries. |
| I/O Contract | The agreed inputs, outputs, and intermediate artifacts (paths, naming, DB schema/table, etc.). | Key to reproducibility and traceability. |
| Step | A checkable phase of work (ideally ordered). | Use `Step 0..N`; titles should be short phrases. |
| Work Items | Individually checkable tasks within a Step. | Prefer binary/observable items; avoid over-fragmentation. |
| Artifacts | Concrete outputs produced/modified in a Step (files, migrations, tables/columns, logs, links). | Prefer precise paths/identifiers. |
| Exit Criteria | Objective conditions that allow a Step to be considered complete. | Include commands/queries + expected results + evidence locations. |
| Evidence | Traceable verification evidence (logs, reports, SQL output, screenshots, links, etc.). | Prefer embedding under Exit Criteria; break out only when needed. |
| Rationale | Why this approach/decision was chosen (trade-offs). | Avoid subjective phrasing; list alternatives when helpful. |
| Risks / Uncertainties | Known risks, unknowns, and mitigation/validation plans. | When uncertain, state the gap and how to resolve it. |

## Step Format (Canonical)

```md
- [ ] Step N: <short title>
  - Work Items:
    - [ ] A checkable work item (English)
  - Artifacts:
    - `path/or/identifier`
  - Exit Criteria:
    - [ ] After doing X, run `command/query` and observe Y; evidence at `path/to/log`.
```
