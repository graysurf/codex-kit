# skills/

This directory contains Codex CLI skills tracked by this repo. A "skill" is a self-contained set of runnable instructions plus any scripts, helpers, tests, and references needed to keep it reliable.

## Tracked skill categories

Tracked skills live under:

- `skills/workflows/`
- `skills/tools/`
- `skills/automation/`

Non-tracked directories are best-effort only:

- `skills/_projects/`
- `skills/.system/`

## Skill directory anatomy (v2)

A tracked skill directory contains only the following top-level entries:

| Entry | Required | Purpose |
| --- | --- | --- |
| `SKILL.md` | Yes | Contract, usage, and workflow documentation |
| `scripts/` | Optional | Executable entrypoints only |
| `lib/` | Optional | Non-entrypoint code (imported/shared helpers) |
| `tests/` | Yes | Per-skill tests (minimum smoke coverage) |
| `references/` | Optional | Longer docs, guides, specs |
| `assets/` | Optional | Templates, fixtures, scaffolds |

Notes:

- `scripts/` must only contain entrypoints; shared code belongs in `lib/` or `_shared/`.
- `tests/` is required for tracked skills (smoke tests are acceptable).

## Shared directories (not skills)

Shared directories hold reusable code/assets and are **not** skills:

- Global: `skills/_shared/`
- Category/area: `skills/<category>/<area>/_shared/`

Allowed subtrees (examples):

- `lib/`
- `references/`
- `assets/`
- `python/` (language-specific helpers)

Forbidden:

- `SKILL.md`
- `scripts/`
- `tests/`

## Path rules for SKILL.md

- Executable entrypoints must use absolute `$CODEX_HOME/...` paths.
- Repo-relative links are allowed for non-executable references.

Example:

```bash
$CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh
```

## Naming conventions

- Skill directories use kebab-case (e.g., `create-feature-pr`).
- `_shared` is reserved for shared, non-skill content only.
- Avoid uppercase or spaces in directory names.

## Golden path examples

New skill:

```text
skills/tools/devex/example-skill/
  SKILL.md
  scripts/
  lib/
  tests/
  references/
  assets/
```

Shared reuse (category-level):

```text
skills/workflows/plan/_shared/
  lib/
  references/
  assets/
```
