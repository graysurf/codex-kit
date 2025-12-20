---
name: find-and-fix-bugs
description: Find, triage, and fix bugs with or without user input. Autonomously scan codebases, produce an issues list, implement a fix, create a fix branch, commit via committer, and open a PR with gh.
---

# Find and Fix Bugs

## Trigger

Use this skill when the user asks to find or fix bugs, or when no concrete issue is provided and you are asked to proactively discover issues.

## Intake rules

- If the user provides a bug report: ensure reproduction steps, expected vs actual, and environment. Ask only for missing details.
- If the user provides no input: do not ask; proceed autonomously.

## Discovery

- Scope scanning to tracked files only (ignore untracked files).
- Use `rg` to scan for bug-prone patterns (TODO, FIXME, BUG, HACK, XXX, panic, unwrap, throw, catch, console.error, assert).
- Exclude generated, vendor, or codegen directories when present (node_modules, dist, build, vendor, .git, gen, generated, codegen).
- Keep scan rules general; do not add repo-specific patterns.
- Do not rely on grep results alone; use LLM analysis to confirm plausibility and impact.
- Produce an issues list in English using `references/ISSUES_TEMPLATE.md`.
- Use the ID format `PR-<number>-BUG-###` (example: `PR-128-BUG-001`). If the PR number is not known yet, use `PR-<number>` as a placeholder and update after PR creation.

## Selection

- If user input exists, fix that issue.
- If autonomous, fix the single most severe or highest-confidence issue.
- Only fix multiple issues when they share the same root cause and the diff remains small.
- Severity levels are fixed: critical, high, medium, low.

## Severity rubric

- critical: security exploit, auth bypass, data loss/corruption, or production outage
- high: frequent crash, major feature broken, or incorrect core outputs
- medium: incorrect behavior with workaround, edge cases, or performance regression
- low: minor bug, UX issue, or noisy logs without functional impact

## Fix workflow

1. Create a new branch: `fix/<severity>-<slug>` using the fixed severity levels.
2. Implement the fix with minimal scope; avoid refactors.
3. Add or update tests when possible; run relevant tests if available.
4. Update the issues list with status.

## Commit

- Use the `committer` skill to generate a Semantic Commit message.
- Prefer a single commit unless there is a clear reason to split.

## PR

- Use `gh pr create` and write the body in English using `references/PR_TEMPLATE.md`.
- Set the PR title to the primary issue or a short summary of the fix. Do not reuse the commit subject. Capitalize the first word.
- Replace the first H1 line in `references/PR_TEMPLATE.md` with the same PR title.
- The PR must include:
  - Issues found (including those not fixed)
  - Fix approach
  - Testing results or "not run"
- Include the issues list in the PR body.
- Use `scripts/render_issues_pr.sh --pr` (or `--issues`) to generate templates quickly.

## Output

- Use `references/OUTPUT_TEMPLATE.md` as the response format.
- The response must include, in order:
  1. Issues list
  2. `git-scope` output
  3. PR link
