---
name: google-sheets-cell-edit
description:
  Use when a user wants to edit cells in Google Sheets through Computer Use/browser automation, especially when the task needs stable cell
  targeting, multiline values, exact partial-text hyperlinks inside one cell, and in-app validation.
---

# Google Sheets Cell Edit

## Contract

Prereqs:

- Browser automation access that can inspect app/browser state and target Google Sheets controls.
  Prefer accessibility-aware tooling over pixel-only clicking.
- A Google Sheets tab is already open and editable.
- The target spreadsheet, worksheet tab, and target cells are either known or can be discovered safely before editing.
- Validation must stay inside the sheet unless the user explicitly asks to open the linked destination.

Inputs:

- Spreadsheet context: browser/app, spreadsheet title, worksheet tab, and target cell references when available.
- Requested edits per cell: plain text, formula, multiline content, formatting constraints, and whether existing content should be preserved.
- Optional hyperlink mapping for a single cell: exact substring -> destination URL pairs.

Outputs:

- Requested Google Sheets cell edits applied in place.
- Compact verification of final cell text and hyperlink destinations.
- A short `Skill Improvement Suggestions` section when the run exposes reusable improvements to this skill.

Exit codes:

- `0`: success, or help output from the entrypoint script
- `1`: workflow or validation failure
- `2`: usage error or missing required inputs

Failure modes:

- Wrong worksheet tab or cell targeted because context was not established first.
- Rich-text hyperlink editing attaches to the wrong substring because the previous link bubble stayed active.
- Clipboard-based rich-text paste mutates cell content or mixes in adjacent text.
- Pixel-based dragging selects the wrong substring inside the cell.
- Sheet is read-only, stale, or concurrently edited by another collaborator.

## Scope

- This skill is about Google Sheets cell editing only.
- It does not decide report content, Jira issue selection, or business wording.
- Use sibling skills for broader Google Workspace tasks when they exist. This skill should remain focused on reliable cell-level editing mechanics.

## Scripts (only entrypoints)

- `$AGENT_HOME/skills/tools/computer-use/google-sheets-cell-edit/scripts/google-sheets-cell-edit.sh`

This entrypoint is help-only. The skill is instruction-first and does not own a standalone browser automation runtime.

## Workflow

1. Establish editing context.
   - Confirm the spreadsheet title, worksheet tab, and exact target cells before typing.
   - Inspect current browser/app state before interacting, and re-inspect after navigation or dialog changes.
   - Prefer labeled controls and the Google Sheets name box over raw pixel navigation.
2. Navigate to the target cell.
   - When the cell reference is known, jump with the name box such as `J7`.
   - Avoid relying on scroll position or remembered coordinates as the primary navigation method.
3. Write the plain cell content first.
   - Prefer the formula bar or explicit in-cell edit mode over ad hoc paste into the grid.
   - For multiline content, write literal line breaks so the cell baseline is correct before adding links.
   - If a single cell needs multiple independent links, settle the correct plain text baseline first.
4. Add partial rich-text hyperlinks when needed.
   - Do not use `HYPERLINK()` when one cell needs multiple clickable links.
   - Enter edit mode, select only the target substring, invoke `Cmd+K`, apply the URL, then close the link bubble before editing the next substring.
   - Between link edits, use `Escape` to dismiss stale link bubbles and reselect from a clean state.
5. Validate without leaving the sheet.
   - Confirm the final visible text and the formula-bar/accessibility value match the requested content.
   - Verify each hyperlink destination from the Google Sheets link bubble or accessibility `link Value`.
   - Do not open Jira, Docs, or other destinations during validation unless the user explicitly asks to navigate there.
6. Recover from common failures.
   - If clipboard-based rich-text paste corrupts content, undo immediately and return to manual substring selection.
   - If in-cell dragging is unstable, switch to text selection in the formula bar.
   - If a hyperlink lands on the wrong substring, restore the plain text baseline if necessary, then rebuild links one by one.
   - If neighboring text is accidentally mixed into the target cell, restore the target cell first and only then retry link edits.
7. Close with reusable improvements.
   - Follow the global Computer Use improvement rule in `AGENTS.md` for whether to emit `Skill Improvement Suggestions`.
   - When suggestions are specific to Google Sheets cell editing, keep them concrete:
     name the fragile step, the safer replacement, and the expected benefit.
