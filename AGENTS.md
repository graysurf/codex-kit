# AGENTS.md

## Purpose & scope

- This file defines the global default behavior for Codex CLI: response style, quality bar, and the minimum set of tool-entry conventions.
- Scope: when Codex CLI can't find a more specific policy file in the current working directory, it falls back to this file.
- Override rule: if the current directory (or a closer subdirectory) contains a project/folder-specific `AGENTS.md` (or equivalent), the closest one wins; otherwise fall back to this file.
- Project-specific specs, workflows, available scripts/tools, and repo structure/index should follow the current project's `DEVELOPMENT`, `README`, `docs`, `prompts`, `skills`, etc. (when present).

## Quick navigation

- How do I run/build/test this project? -> read the current project's `DEVELOPMENT`, `README`, `docs/`.
- What workflows/templates already exist? -> check the current project's `prompts/`, `skills/`, or equivalent directories (when present).
- Which CLI tools should I use across projects? -> read `$CODEX_HOME/CLI_TOOLS.md` (when present).
- This file only covers global response behavior and minimal tool-entry conventions; avoid duplicating or conflicting with project docs.

## Global tooling (cross-project)

- `$CODEX_HOME/CLI_TOOLS.md` is the cross-project reference for which CLI tools to use for development, testing, and docs work (when the file exists in the current context).
- Default preference examples: `rg` over `grep -R`, `fd` over `find`, `jq`/`yq` over regex parsing of JSON/YAML.
- If a project defines a more specific toolchain/workflow, follow the project docs.
- If `$CODEX_HOME/CLI_TOOLS.md` is missing, use best-effort defaults and prefer project-specific docs when available.

## Technical info lookup workflow

- Default order (fast -> deep):
  1. Context7: quick, source-linked doc excerpts (best when official docs are already indexed and stable).
  2. Official web docs: read the upstream “source of truth” (release notes/specs/PEPs/RFCs) when Context7 is incomplete or you need full context.
  3. GitHub via `gh`: when docs lag behind or you need the latest changes; inspect files, tags, releases, and PRs.
  4. Local clone (ask first): when you need full-text search, cross-file analysis, `git log/blame`, or to run/build/test code. Ask the user for explicit consent before cloning, unless they already requested it.

- Decision heuristics:
  - Need a quick, traceable excerpt -> (1)
  - Need full narrative context (tables/changelogs/spec text) -> (2)
  - Need “latest on main” or unreleased behavior -> (3) or (4)
  - Need to validate by running code/tests -> (4)

- `gh` quick starts (examples):
  - Open repo in browser: `gh repo view OWNER/REPO --web`
  - View a raw file: `gh api -H "Accept: application/vnd.github.raw" /repos/OWNER/REPO/contents/PATH?ref=BRANCH_OR_TAG`
  - Shallow clone for analysis: `gh repo clone OWNER/REPO -- --depth 1`

## Core guidelines

- Semantic and logical consistency
  - Keep meaning, terminology, and numbers consistent within a turn and across turns; avoid drift.
  - If you need to correct something, explicitly call out what changed and why (e.g., cause and before/after).

- High signal density
  - Maximize useful information per token without sacrificing accuracy or readability; avoid filler and repetition.
  - Prefer structured output (bullets, tables, quantified statements).

- Reasoning mode
  - Default to an accelerated, high-level reasoning mode; if the reasoning space gets too large, flag it and propose narrowing.

- Working with files
  - For shell scripts, code, and config: before editing/commenting, read the full context relevant to the change (definitions, call sites, loading/dependencies). It's fine to jump directly to the target area first, then backfill surrounding context as needed.
  - If information is missing or uncertain: state assumptions and what needs verification, ask for the minimum additional files/snippets, then proceed. Avoid overconfident conclusions from partial context.
  - When generating artifacts (reports/outputs/temp files):
    - Project deliverables -> write them into the project directory following that project's conventions.
    - Debug/test artifacts that would normally go to `/tmp` (e.g. `lighthouse-performance.json`) -> write to `$CODEX_HOME/out/` instead, and reference that path in the reply.

- Completion notification (desktop)
  - If you finish the user's request in a turn (e.g. implemented/fixed/delivered something), and the user didn't explicitly opt out: send one desktop notification at the end of the turn (best-effort; silent no-op on failure).
  - Message: describe what was done in <= 10 words.
  - Command (cross-platform; pass only the message): `$CODEX_HOME/skills/tools/devex/desktop-notify/scripts/project-notify.sh "Up to 10 words" --level info|success|warn|error`

## Response template

> Goal: make outputs scannable, verifiable, and traceable, while consistently surfacing uncertainty.

### Global response rules

- Skill-first
  - If an enabled skill (e.g. `skills/*/SKILL.md`) defines output requirements or a mandatory format (including code-block requirements), follow it.
  - If a skill conflicts with this template, the skill wins. Otherwise, keep using this template.

- Response footer
  - Every reply must end with confidence and reasoning level using this exact format:
    - `—— [Confidence: High|Medium|Low] [Reasoning: Fact|Inference|Assumption|Generated]`

- Template

  ```md
  ## Overview

  - In 2-5 lines: state the problem, the conclusion, assumptions (if any), and what you'll do next (if anything).

  ## Steps / Recommendations

  1. Actionable steps (include CLI steps, checkpoints, and expected output when useful).
  2. If there are branches: If A -> do X; if B -> do Y.

  ## Risks / Uncertainty (when needed)

  - What is inferred vs assumed, and what missing info could change the conclusion.
  - How to validate (which file to check, which command to run, which log to read).

  ## Sources (when needed)

  - Cite filenames/paths or other traceable references.

  —— [Confidence: Medium] [Reasoning: Inference]
  ```

## Commit policy

- All commits must use `semantic-commit`
  - `$semantic-commit`: review-first, user-staged.
  - `$semantic-commit-autostage`: automation flow (allows `git add`).
- Do not run `git commit` directly.
- Before committing (and before reporting a task as complete), follow the current project's `DEVELOPMENT.md` (when present) to run the appropriate tests/checks and ensure they pass.
- If tests fail (or can't be run), explicitly say so and explain why (include the failing command and the key error).
