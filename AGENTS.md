# AGENTS.md

## Purpose & scope

- Repository-level policy for this repository.
- Start from the global defaults in `~/.codex/AGENTS.md`, then add only the stricter rules this repository needs.
- Keep this file limited to durable repository policy. Put long-form procedures in canonical docs loaded through `agent-docs`.
- Override rule: a closer `AGENTS.md` may replace these defaults for a subdirectory.

## Operating defaults

- Default to execution over prolonged planning.
  Move directly to inspection, implementation, and verification unless the user
  asks for planning or a real decision point blocks progress.
- Ask only the minimum clarification needed when objective, done criteria,
  scope, constraints, environment, or safety/reversibility are materially
  unclear.
- When assumptions are needed and the risk is acceptable, state them briefly and proceed.
- Before editing code, scripts, or config, inspect the target plus the relevant
  definitions, call sites, or loading paths needed to avoid partial-context
  changes.
- For external, unstable, or time-sensitive claims, prefer authoritative sources and cite the evidence used.
- Keep answers concise, high-signal, and easy to verify. Use structure when useful, but do not force a fixed response template.
- Default user-facing language is Traditional Chinese unless the user explicitly requests another language.
- Keep precision-critical technical terms and proper nouns in English when that is clearer.

## `agent-docs` policy

- In this repository, `agent-docs` is mandatory before implementation work.
- Always pin home-scope resolution to this toolchain root by passing
  `--docs-home "$AGENT_HOME"` (nils-cli ≥ 0.8.0 no longer reads `AGENT_HOME`;
  the equivalent env var is `AGENT_DOCS_HOME`).
- Minimum preflight:
  - Session start or new task: `agent-docs --docs-home "$AGENT_HOME" resolve --context startup --strict --format checklist`
  - Before write actions: `agent-docs --docs-home "$AGENT_HOME" resolve --context project-dev --strict --format checklist`
  - Technical research or external verification: `agent-docs --docs-home "$AGENT_HOME" resolve --context task-tools --strict --format checklist`
  - Skill lifecycle work: `agent-docs --docs-home "$AGENT_HOME" resolve --context skill-dev --strict --format checklist`
- If a required strict resolve fails, stop write actions, run
  `agent-docs --docs-home "$AGENT_HOME" baseline --check --target all --strict --format text`, and report
  the missing docs or degraded mode explicitly.
- Canonical dispatch contract: `$AGENT_HOME/docs/runbooks/agent-docs/context-dispatch-matrix.md`

## Files and artifacts

- Follow repository conventions for deliverables and generated files.
- Put temporary debug or test artifacts under `$AGENT_HOME/out/` instead of `/tmp` when practical, and mention that path in the reply.
- Do not create files only to mirror response text unless the task specifically calls for an artifact.

## Canonical references

- Development, build, test, and commit-time validation:
  - `DEVELOPMENT.md`
- Tool-selection and research workflow:
  - `$AGENT_HOME/CLI_TOOLS.md`
  - `$AGENT_HOME/RESEARCH_WORKFLOW.md`
- Startup, dispatch, and bootstrap runbooks:
  - `$AGENT_HOME/docs/runbooks/agent-docs/`

## Validation and commits

- Prefer project-defined validation commands.
  In this repository, use `DEVELOPMENT.md` as the canonical source for
  required checks.
- Before reporting completion, run the relevant checks or state clearly why they could not be run.
- Commits in this repository must use `semantic-commit` or
  `semantic-commit-autostage`; do not run `git commit` directly.
