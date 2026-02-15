---
name: semgrep-find-and-fix
description: Scan a repo using its checked-in Semgrep configuration (local rules only), triage findings, and either fix the most severe issues or open a report-style PR. Use when a repo already has Semgrep config and rules committed; stop if no Semgrep config is present.
---

# Semgrep Find and Fix

## Contract

Prereqs:

- Run inside the target git repo.
- The repo has Semgrep config and local rules checked in (required).
- `semgrep` available on `PATH`.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.

Inputs:

- Optional scope hints (paths, languages, or areas to focus).
- Optional stop conditions (for example, "report-only PR, no fixes").

Outputs:

- Semgrep scan results captured in a JSON file under `$AGENTS_HOME/out/semgrep/`.
- A PR that either:
  - fixes the selected high-impact finding(s), or
  - is report-only (adds a report file that documents the most serious findings and suggested fixes).
- After PR creation, return to the original branch/ref (leave the working branch intact for follow-ups).

Exit codes:

- N/A (multi-command workflow; failures surfaced from underlying commands).

Failure modes:

- Semgrep config is missing in the target repo (stop; do not scan).
- Semgrep scan fails (parse errors, unsupported files, missing deps); stop and report stderr.
- Findings are too noisy to triage; prefer config-layer suppression, or open a report PR and defer fixes.

## Guardrails

- Do not run `semgrep scan --autofix` unless the user explicitly asks (autofix can cause unintended edits).
- Avoid auto-fixing high-risk domains (auth/authorization, billing, migrations, deployment). If the top finding is in a high-risk area, prefer a report PR instead of code changes.
- Keep diffs small: fix one root cause (or a tightly related set) per run.

## Semgrep config requirements

This skill intentionally depends on project-provided Semgrep configuration and rules. Do not use Semgrep Registry entries or `--config auto`.

Resolve the Semgrep config entrypoint from tracked files in the repo root (deterministic order):

1. `.semgrep.yml`
2. `.semgrep.yaml`
3. `.semgrep/` (directory)
4. `semgrep.yml`
5. `semgrep.yaml`

If none exist, stop and report: "No Semgrep config found; add one of the supported entrypoints to enable this workflow."

## Workflow

1. Record the starting branch/ref so you can return after PR creation:
   - `start_ref="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)"`
2. Resolve the Semgrep config entrypoint (per rules above).
3. Run Semgrep and capture JSON to a file (avoid spamming stdout):
   - `out_dir="${AGENTS_HOME:-$(pwd)}/out/semgrep"`
   - `mkdir -p "$out_dir"`
   - `out_json="$out_dir/semgrep-$(basename "$(pwd)")-$(date +%Y%m%d-%H%M%S).json"`
   - `semgrep scan --config "$CONFIG" --json --metrics=off --disable-version-check . >"$out_json"`
4. Triage findings (LLM step):
   - Prefer the most severe and highest-confidence findings.
   - Group by `check_id` (rule id) and by affected area.
   - Pick a single fix target (or one closely related group) for this run.
   - If fixes are unsafe/unclear, choose a report-only PR instead.
5. Choose one output path:
   - Fix PR: implement the minimal fix; follow the repo’s testing/build docs to install required tooling/deps and run relevant lint/test/build checks. Ensure they pass before commit/open PR. If checks cannot be run, document why in the PR `## Testing` section.
   - Report-only PR: add a report file summarizing the most severe findings; open PR.
6. Noise controls (config-layer; use sparingly):
   - Prefer `.semgrepignore`, `paths` include/exclude, and rule disable lists over adding `nosem` to code.
   - Only change Semgrep config/ignore when the goal is noise reduction; keep it separate from functional fixes.
7. After PR creation: return to the original ref:
   - `git switch "$start_ref"`

## PR and report templates

- For PR body template, use `skills/automation/semgrep-find-and-fix/references/PR_TEMPLATE.md`.
- For report file template (report-only PR), use `skills/automation/semgrep-find-and-fix/references/REPORT_TEMPLATE.md`.

## Output and clarification rules

- If the Semgrep config entrypoint is ambiguous or missing, stop and ask rather than guessing.
- If creating a report-only PR, ensure the PR changes include the report file (a PR cannot be "report only" without committed changes).
- Always include the exact Semgrep command and config path in the PR body for reproducibility.
