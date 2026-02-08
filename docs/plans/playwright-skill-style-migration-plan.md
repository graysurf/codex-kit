# Plan: Playwright skill style migration

## Overview

This migration rewrites `skills/tools/browser/playwright` so it matches the repository’s current skill conventions: contract-first `SKILL.md`, minimal wrapper-centric behavior, and concise reference docs. The target design treats this skill as a thin shell wrapper around a single command invocation, not a broader Playwright framework. The migration also removes bundled license/notice files that are no longer needed for this wrapper-only implementation. The result should preserve functional behavior while reducing maintenance surface and style drift.

## Scope

- In scope:
  - Rewrite `skills/tools/browser/playwright/SKILL.md` to align with current tool-skill format and wording.
  - Simplify `skills/tools/browser/playwright/scripts/playwright_cli.sh` to a clear, minimal wrapper contract.
  - Rewrite `skills/tools/browser/playwright/references/cli.md` to match reference-doc style used by other tool skills.
  - Remove skill-local license/notice artifacts at:
    - `skills/tools/browser/playwright/references/LICENSE.txt`
    - `skills/tools/browser/playwright/references/NOTICE.txt`
  - Update/adjust tests under `skills/tools/browser/playwright/tests/` as needed to reflect the new minimal contract.
- Out of scope:
  - Adding new Playwright features or changing upstream CLI behavior.
  - Migrating this skill to Playwright MCP server behavior.
  - Refactoring other browser skills.
  - Changing icon assets (`assets/*.svg`, `assets/*.png`) or `assets/openai.yaml` unless strictly required by contract checks.

## Assumptions

1. The canonical runtime behavior remains `npx --yes --package @playwright/cli@latest playwright-cli ...`.
2. The skill remains a wrapper utility (no embedded workflow engine, no generated test specs).
3. Removing `references/LICENSE.txt` and `references/NOTICE.txt` is acceptable for this repository’s compliance posture once any dependent references are removed.
4. Existing governance checks (`validate_skill_contracts.sh`, `audit-skill-layout.sh`) are the source of truth for skill structure acceptance.

## Sprint 1: Baseline and target contract

**Goal**: lock down migration acceptance boundaries before rewriting files, so implementation remains minimal and consistent.

**Demo/Validation**:
- Command(s):
  - `rg -n "^## " skills/tools/browser/playwright/SKILL.md skills/tools/browser/playwright/references/cli.md`
  - `bash -n skills/tools/browser/playwright/scripts/playwright_cli.sh`
- Verify:
  - Current section map and wrapper behavior are captured and used as migration baseline.

### Task 1.1: Define style delta against canonical tool skills
- **Location**:
  - `skills/tools/browser/playwright/SKILL.md`
  - `skills/tools/browser/chrome-devtools-debug-companion/SKILL.md`
  - `skills/tools/media/screenshot/SKILL.md`
- **Description**: Compare the Playwright skill against representative “current style” tool skills and document concrete deltas to close: section ordering, contract density, entrypoint declaration, and references style. Translate these deltas into explicit edit objectives for Sprint 2 so implementation stays deterministic and minimal.
- **Dependencies**: none
- **Complexity**: 3
- **Acceptance criteria**:
  - Delta list explicitly covers contract structure, scripts entrypoint wording, and references section expectations.
  - Delta notes identify which existing Playwright sections will be removed, merged, or relocated.
- **Validation**:
  - `rg -n "^## (Contract|Scripts \(only entrypoints\)|References)" skills/tools/browser/playwright/SKILL.md skills/tools/browser/chrome-devtools-debug-companion/SKILL.md skills/tools/media/screenshot/SKILL.md`

### Task 1.2: Freeze minimal wrapper behavior contract
- **Location**:
  - `skills/tools/browser/playwright/scripts/playwright_cli.sh`
  - `skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
- **Description**: Define and lock the wrapper’s intended behavior surface before edits: local help handling, `npx` precheck, session-env injection behavior, argument pass-through, and exit code semantics. Convert this into explicit test expectations so documentation and script edits remain consistent.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Behavior contract is captured in tests or assertions that fail on regressions.
  - No requirement implies functionality beyond forwarding to upstream `playwright-cli`.
- **Validation**:
  - `pytest -q skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`

## Sprint 2: Rewrite skill artifacts

**Goal**: implement the migration by rewriting the skill docs and wrapper to the agreed minimal, repo-consistent style.

**Demo/Validation**:
- Command(s):
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/browser/playwright/SKILL.md`
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/tools/browser/playwright`
- Verify:
  - Rewritten skill files pass contract and layout governance checks.

### Task 2.1: Rewrite SKILL.md to wrapper-first contract style
- **Location**:
  - `skills/tools/browser/playwright/SKILL.md`
- **Description**: Replace the current long-form SKILL content with concise, contract-first guidance matching other tool skills: precise prereqs, explicit single entrypoint, thin-scope statement, short usage section, and reference links. Remove narrative content that implies this skill owns workflows beyond wrapper invocation.
- **Dependencies**:
  - Task 1.2
- **Complexity**: 6
- **Acceptance criteria**:
  - `SKILL.md` keeps the required contract headings and follows repo section conventions.
  - The file clearly states the wrapper-only scope and avoids duplicated setup paths.
  - `Scripts (only entrypoints)` points only to `scripts/playwright_cli.sh`.
- **Validation**:
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/browser/playwright/SKILL.md`

### Task 2.2: Simplify wrapper implementation while preserving behavior
- **Location**:
  - `skills/tools/browser/playwright/scripts/playwright_cli.sh`
  - `skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
- **Description**: Refactor the wrapper script for clarity and consistency with repo shell style: keep strict mode, deterministic help text, robust `npx` check, and minimal session injection logic. Remove unnecessary branching or wording drift without changing the core forwarded command.
- **Dependencies**:
  - Task 1.2
- **Complexity**: 5
- **Acceptance criteria**:
  - Runtime command remains `npx --yes --package @playwright/cli@latest playwright-cli` plus forwarded args.
  - `--help` remains local and succeeds without requiring network calls.
  - Session env handling is deterministic when `PLAYWRIGHT_CLI_SESSION` is set/unset.
- **Validation**:
  - `bash -n skills/tools/browser/playwright/scripts/playwright_cli.sh`
  - `pytest -q skills/tools/browser/playwright/tests/test_tools_browser_playwright.py -k "help or entrypoints or contract or session"`
  - `tmpdir=$(mktemp -d) && (cd "$tmpdir" && PLAYWRIGHT_CLI_SESSION=ci "$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" --help >/dev/null) && rm -rf "$tmpdir"`
  - `mkdir -p "$CODEX_HOME/out" && env PATH="/nonexistent" /bin/bash "$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" open https://example.com >/dev/null 2>"$CODEX_HOME/out/playwright-missing-npx.err"; test $? -eq 1; rg -n "npx is required" "$CODEX_HOME/out/playwright-missing-npx.err"`

### Task 2.3: Rewrite CLI reference doc in standard style
- **Location**:
  - `skills/tools/browser/playwright/references/cli.md`
- **Description**: Rewrite the CLI reference into concise, scan-friendly sections used by other skills: setup preconditions, canonical wrapper invocation, grouped command examples, and short troubleshooting notes. Keep command samples focused on wrapper usage instead of global-install-first guidance.
- **Dependencies**:
  - Task 2.1
  - Task 2.2
- **Complexity**: 5
- **Acceptance criteria**:
  - Reference content is consistent with rewritten `SKILL.md` terminology and scope.
  - Commands primarily use the wrapper path/alias flow.
  - No stale wording conflicts with wrapper contract.
- **Validation**:
  - `rg -n "playwright-cli install|global install|wrapper" skills/tools/browser/playwright/references/cli.md skills/tools/browser/playwright/SKILL.md`

### Task 2.4: Remove license notice artifacts and clean references
- **Location**:
  - `skills/tools/browser/playwright/references/LICENSE.txt`
  - `skills/tools/browser/playwright/references/NOTICE.txt`
  - `skills/tools/browser/playwright/SKILL.md`
  - `skills/tools/browser/playwright/references/cli.md`
- **Description**: Delete the two license/notice files requested by the migration and remove any remaining references to them from Playwright skill docs. Ensure the resulting documentation does not imply these files still exist.
- **Dependencies**:
  - Task 2.1
  - Task 2.3
- **Complexity**: 2
- **Acceptance criteria**:
  - Both files are removed from the skill directory.
  - No links or text in the Playwright skill docs reference the removed files.
- **Validation**:
  - `test ! -f skills/tools/browser/playwright/references/LICENSE.txt`
  - `test ! -f skills/tools/browser/playwright/references/NOTICE.txt`
  - `rg -n "LICENSE\.txt|NOTICE\.txt" skills/tools/browser/playwright -S`

## Sprint 3: Verification and migration sign-off

**Goal**: validate compatibility, catch style regressions, and produce a clean handoff for implementation PR review.

**Demo/Validation**:
- Command(s):
  - `pytest -q skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/browser/playwright/SKILL.md`
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/tools/browser/playwright`
- Verify:
  - Tests and governance checks pass with the migrated files and deleted notices.

### Task 3.1: Run focused regression checks for wrapper + docs contract
- **Location**:
  - `skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
  - `skills/tools/browser/playwright/SKILL.md`
  - `skills/tools/browser/playwright/scripts/playwright_cli.sh`
- **Description**: Execute the Playwright skill’s focused tests and contract validators to confirm no behavior regression and no contract-format drift after migration.
- **Dependencies**:
  - Task 2.4
- **Complexity**: 4
- **Acceptance criteria**:
  - Playwright skill tests pass.
  - Contract validator passes for `SKILL.md`.
  - Layout audit passes for the skill directory.
- **Validation**:
  - `pytest -q skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/browser/playwright/SKILL.md`
  - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/tools/browser/playwright`

### Task 3.2: Execute wrapper smoke checks in a temp workspace
- **Location**:
  - `skills/tools/browser/playwright/scripts/playwright_cli.sh`
- **Description**: Run smoke checks in an isolated temporary directory to verify local help, missing-`npx` error path (if simulatable), and argument forwarding behavior are still correct after refactor.
- **Dependencies**:
  - Task 2.2
- **Complexity**: 3
- **Acceptance criteria**:
  - `--help` path exits cleanly and prints wrapper usage.
  - Wrapper forwards sample arguments to upstream command without local parsing regressions.
- **Validation**:
  - `tmpdir=$(mktemp -d) && (set -o pipefail; cd "$tmpdir" && "$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" --help >/dev/null) && rm -rf "$tmpdir"`

### Task 3.3: Final consistency pass and reviewer checklist
- **Location**:
  - `skills/tools/browser/playwright/SKILL.md`
  - `skills/tools/browser/playwright/references/cli.md`
  - `skills/tools/browser/playwright/scripts/playwright_cli.sh`
  - `skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
- **Description**: Do a final consistency sweep so terminology, command examples, and behavior guarantees are aligned across doc/script/test. Produce a reviewer checklist summarizing what changed and what was intentionally not changed.
- **Dependencies**:
  - Task 3.1
  - Task 3.2
- **Complexity**: 3
- **Acceptance criteria**:
  - No conflicting wording between SKILL docs and wrapper behavior.
  - Reviewer can verify migration intent from checklist without reading historical context.
- **Validation**:
  - `rg -n "PLAYWRIGHT_CLI_SESSION|npx --yes --package @playwright/cli@latest playwright-cli|wrapper" skills/tools/browser/playwright/SKILL.md skills/tools/browser/playwright/references/cli.md skills/tools/browser/playwright/scripts/playwright_cli.sh`

## Testing Strategy

- Unit:
  - Keep/adjust `skills/tools/browser/playwright/tests/test_tools_browser_playwright.py` for wrapper help, entrypoint existence, and contract checks.
- Integration:
  - Run skill-governance validators against the migrated skill directory.
- Manual:
  - Run wrapper help and one non-destructive command invocation path to confirm argument forwarding semantics.

## Risks & gotchas

- Upstream `@playwright/cli@latest` output can change over time; tests should assert stable wrapper-level behavior, not brittle upstream text.
- Over-editing documentation can accidentally reintroduce non-wrapper scope; scope boundaries must remain explicit.
- Removing license/notice files can be a compliance concern if copied third-party content remains; migration should ensure content is now wrapper-authored and not derivative.
- Wrapper refactors can break quoting/argument pass-through if array handling is altered incorrectly.

## Rollback plan

1. Restore previous Playwright skill files (including deleted notice files) from git history if any regression appears:
   - `skills/tools/browser/playwright/SKILL.md`
   - `skills/tools/browser/playwright/scripts/playwright_cli.sh`
   - `skills/tools/browser/playwright/references/cli.md`
   - `skills/tools/browser/playwright/references/LICENSE.txt`
   - `skills/tools/browser/playwright/references/NOTICE.txt`
2. Re-run focused checks:
   - `pytest -q skills/tools/browser/playwright/tests/test_tools_browser_playwright.py`
   - `bash $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/browser/playwright/SKILL.md`
3. Re-open a follow-up migration with narrower scope (docs-only or wrapper-only) if full migration is unstable.
