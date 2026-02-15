# SKILL.md Format v1

This repo treats each `skills/**/SKILL.md` as both human documentation and a machine-validated contract.

The **Contract** is the stable interface. Other sections (Setup/Workflow/References) exist to make the contract executable and easy to follow, without changing the interface.

## Required file structure

Order (strict):

1. YAML front matter (required)
2. `# <Title>` (required)
3. Preamble (optional; max **2 non-empty lines**)
4. `## Contract` (required; must be the **first H2**)
5. Any other sections (optional)

### Preamble rules

Preamble is the content between the first H1 (`# ...`) and `## Contract`.

- Allowed: up to 2 **non-empty** lines of plain text (short orientation).
- Disallowed before `## Contract`:
  - Any headings (`##`, `###`, …)
  - Long lists, policies, or examples (move them to a post-Contract section)

Rationale: keep the contract easy to locate and make contract checks deterministic.

## Contract

The Contract defines the skill’s stable interface and must be complete enough to use the skill correctly **without reading the rest of the file**.

Inside `## Contract`, these headings are required, in exact order (validated by tooling):

1. `Prereqs:`
2. `Inputs:`
3. `Outputs:`
4. `Exit codes:`
5. `Failure modes:`

### What belongs only in Contract (single source of truth)

Put these here and treat them as canonical:

- Hard requirements (tools, environment, repo state) → **Prereqs**
- Required inputs and supported knobs/flags at the interface boundary → **Inputs**
- Guaranteed artifacts, side effects, and user-visible outcomes → **Outputs**
- Script exit code meanings (when applicable) → **Exit codes**
- Common/expected failures that affect correctness and how to diagnose them → **Failure modes**

### Contract vs Setup (avoid duplication)

`## Setup` is optional. When present, it exists to help satisfy and verify the Contract.

Rules:

- **Setup must not introduce new hard prerequisites.** If it’s required, it must be in `Prereqs`.
- Avoid verbatim duplication of the `Prereqs` list. Prefer:
  - a short reference (“See Contract → Prereqs”), then
  - concrete install/verification commands per prerequisite.
- It is okay to repeat a prereq *name* as an anchor for steps, but keep the canonical requirement statement in Contract.

Practical pattern:

- Contract: `- \`gh\` available on PATH`
- Setup: how to install `gh`, plus a `gh auth status` verification command

## Recommended section names (post-Contract)

These names are recommended when the meaning matches; they are not all required:

- `## Setup` — how to satisfy/verify prereqs (no new requirements)
- `## Scripts (only entrypoints)` — canonical runnable entrypoints (prefer `$AGENTS_HOME/...` absolute paths)
- `## Workflow` — step-by-step execution instructions and decision points
- `## References` — longer guides/specs/templates

For content that is neither Setup nor Workflow (for example, assistant-only “policy”, default preferences, or response templates), add a clear post-Contract H2 such as:

- `## Guidance`
- `## Policies`
- `## Output and clarification rules`

## Minimal skeleton (example)

```md
---
name: example-skill
description: One sentence describing what this skill does.
---

# Example Skill

Short preamble (optional; max 2 lines).

## Contract

Prereqs:

- ...

Inputs:

- ...

Outputs:

- ...

Exit codes:

- `0`: success
- `1`: failure

Failure modes:

- ...

## Scripts (only entrypoints)

- `$AGENTS_HOME/skills/.../scripts/example-skill.sh`

## Workflow

1) ...
```

## Tooling

- Contract validation:
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Skill layout audit:
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
