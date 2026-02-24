## Summary
- Implements issue #116 in an isolated worktree.
- Adds the sprint2 single-task single-PR fixture file.

## Scope
- Adds `tests/issues/duck-loop/sprint2/single-pr/task.md` with required sprint metadata.
- Excludes unrelated codebase or fixture changes.

## Testing
- `test -f tests/issues/duck-loop/sprint2/single-pr/task.md` (pass)
- `rg -n 'mode: single-task-pr|sprint: 2' tests/issues/duck-loop/sprint2/single-pr/task.md` (pass)

## Issue
- #116
