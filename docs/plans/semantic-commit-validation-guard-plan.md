# Plan: Semantic commit validation guard

## Overview

Add a strict commit-message validator to `commit_with_message.sh` so both `semantic-commit` and
`semantic-commit-autostage` hard-fail when the message does not follow the repo’s Semantic Commit
format. Validation will cover the header syntax and body bullet formatting rules, with clear errors
before running `git commit`. Update tests and skill docs to reflect the new behavior and ensure
internal callers remain compliant.

## Scope

- In scope:
  - Add commit message validation in `skills/tools/devex/semantic-commit/scripts/commit_with_message.sh`.
  - Update skill docs to mention hard-fail validation rules and failure modes.
  - Add/extend tests to cover valid and invalid commit messages.
  - Audit internal callers of `commit_with_message.sh` and align their messages if needed.
- Out of scope:
  - Rewriting `staged_context.sh` or commit message generation logic.
  - Interactive prompting or auto-fixing invalid messages.
  - Enforcing a fixed allowlist of commit types beyond structural validation.

## Assumptions

1. A valid header matches `type(scope): subject` where `type` is lowercase and may include digits or
   hyphens, `scope` is optional, and `subject` is non-empty.
2. If a body exists, there must be a blank line after the header and every non-empty body line must
   start with `- ` followed by an uppercase letter (no blank lines between bullets).
3. Length guidance in the skill docs (<= 100 characters per line) should be enforced for header and
   body lines.

## Sprint 1: Implement validation in commit_with_message.sh

**Goal**: Fail fast on invalid semantic commit messages before `git commit` executes.

**Demo/Validation**:
- Command(s):
  - `python3 -m pytest -q tests/test_script_smoke_semantic_commit.py`
- Verify:
  - Valid messages still commit successfully.
  - Invalid messages exit non-zero with actionable errors.

### Task 1.1: Add a commit message validator
- **Location**:
  - `skills/tools/devex/semantic-commit/scripts/commit_with_message.sh`
- **Description**: Parse the prepared commit message file and validate: header format, optional
  blank line, bullet-only body lines, capitalization after `- `, and line-length limits. Emit a
  single error message that points to the first violation and exit with code 1 before `git commit`.
  Keep the validator pure shell (no new external deps) and reuse for stdin/--message/--message-file.
- **Dependencies**: none
- **Complexity**: 5
- **Acceptance criteria**:
  - Invalid header format is rejected with a clear error.
  - Body without a blank line after the header is rejected.
  - Body lines not starting with `- ` or not capitalized are rejected.
  - Header/body lines over 100 characters are rejected.
- **Validation**:
  - `zsh -f skills/tools/devex/semantic-commit/scripts/commit_with_message.sh --help`

### Task 1.2: Add negative test coverage for invalid messages
- **Location**:
  - `tests/test_script_smoke_semantic_commit.py`
- **Description**: Add fixtures that exercise invalid commit messages (bad header, missing blank
  line, non-bullet body lines, lowercase after `- `, overlong line). Assert non-zero exit and error
  text. Keep the existing positive fixture unchanged.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Tests fail before the validator change and pass after it.
  - Failure cases assert exit codes and stderr content without depending on full output.
- **Validation**:
  - `python3 -m pytest -q tests/test_script_smoke_semantic_commit.py`

### Task 1.3: Document validation behavior in skill docs
- **Location**:
  - `skills/tools/devex/semantic-commit/SKILL.md`
  - `skills/automation/semantic-commit-autostage/SKILL.md`
- **Description**: Update failure modes / workflow notes to state that commit messages are
  validated for header and body bullet format and will hard-fail on invalid input.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 2
- **Acceptance criteria**:
  - Docs clearly describe the enforced format and hard-fail behavior.
- **Validation**:
  - `rg -n "validation|invalid" skills/tools/devex/semantic-commit/SKILL.md`

## Sprint 2: Audit internal callers and verify integration

**Goal**: Ensure internal scripts that call `commit_with_message.sh` remain compliant.

**Demo/Validation**:
- Command(s):
  - `rg -n "commit_with_message.sh" -S skills/`
  - `python3 -m pytest -q tests/test_script_smoke_semantic_commit.py`
- Verify:
  - All internal call sites pass a valid header/body format.

### Task 2.1: Audit internal call sites for message format
- **Location**:
  - `skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh`
  - `skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh`
- **Description**: Verify that any `--message` usage matches the validated format. Adjust message
  strings if necessary (ensure lowercase type, colon-space, and optional body formatting).
- **Dependencies**:
  - Task 1.1
- **Complexity**: 3
- **Acceptance criteria**:
  - All internal usages pass validation under the new rules.
- **Validation**:
  - `rg -n "--message" -n skills/workflows/pr/progress -S`

## Testing Strategy

- Unit: `tests/test_script_smoke_semantic_commit.py` (valid + invalid cases).
- Integration: run `commit_with_message.sh` in a temp git repo via the fixture test.
- E2E/manual: run a local `semantic-commit` flow with a valid and invalid message.

## Risks & gotchas

- Stricter validation may reject previously accepted commit messages used by internal automation.
- Header regex might be too permissive or too strict for edge cases (e.g., `!` for breaking changes).
- Enforcing line length could block legitimate messages if users exceed 100 characters.

## Rollback plan

- Revert the validator additions in `commit_with_message.sh` and remove failing tests if the
  enforcement blocks critical workflows.
