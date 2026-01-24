# Skill Anatomy v2 (codex-kit)

This document defines the canonical directory/layout rules for `skills/` in codex-kit.

The goal is a structure that is:

- **Runnable**: instructions work from any working directory via `$CODEX_HOME/...`
- **Shareable**: related skills can share implementation safely
- **Enforceable**: audits + CI can prevent layout/path drift

Key rule: anything under `skills/**/scripts/**` is treated as an executable entrypoint (and is covered by script regression tests).

## Directory layout

### MUST: Each skill folder has one root `SKILL.md`

A “skill folder” is any directory under `skills/**/` that contains a `SKILL.md`.

Each skill folder MUST contain:

- `SKILL.md` (required)

Each skill folder MAY contain:

- `scripts/` (optional) — executable entrypoints only
- `references/` (optional) — documentation meant to be read/loaded as needed
- `assets/` (optional) — scaffolds/templates not meant to be loaded as context

No other tracked top-level entries are allowed under a skill folder.

Enforcement:

- `$CODEX_HOME/scripts/audit-skill-layout.sh`

### MUST: Template placement rules

In codex-kit, within a skill folder:

- Markdown templates meant to be copied/rendered into files MUST live under `assets/templates/`.
- Markdown templates meant to be read as writing skeletons MUST live under `references/`.
- Markdown files with `TEMPLATE` in the filename MUST live under `references/` or `assets/templates/`.

Repo-wide templates shared across many skills (not tied to a single skill folder) live under `docs/templates/`.

## Sharing (_libs_)

### MUST: Shared logic is non-executable and lives under `_libs/`

When multiple related skills need to share implementation code (shell/python helpers), use a group-level `_libs/` folder:

- `skills/automation/_libs/` (already exists)
- `skills/tools/_libs/` (planned/allowed)
- `skills/workflows/_libs/` (planned/allowed)
- `skills/_projects/_libs/` (planned/allowed)

Rules:

- `_libs/` MUST NOT contain a `scripts/` directory (script tests treat `skills/**/scripts/**` as entrypoints).
- Files under `_libs/` MUST NOT be executable (no shebang; no `chmod +x`).
- Entrypoints MUST live under a concrete skill’s `scripts/` (or a project/group `scripts/` only when it is intended to be invoked directly).

### SHOULD: Use language subfolders when it helps discovery

Suggested (create only what you use):

- `_libs/sh/*.sh`
- `_libs/zsh/*.zsh`
- `_libs/python/*.py`
- `_libs/md/*.md`

### MUST: `_projects` local-only files follow gitignore; `_libs` stays tracked

- Local-only secrets/config under `skills/_projects/` MUST use `.env` or `.env.*`
  filenames (gitignored by default).
- Shared helpers under `skills/_projects/_libs/` are tracked and must follow the
  `_libs` rules (non-executable; no `scripts/`).

## Scripts and entrypoints

### MUST: `scripts/` contains only entrypoints

If a file must be invoked directly, it belongs under a skill’s `scripts/` directory and MUST:

- Have a correct shebang (e.g. `#!/usr/bin/env bash` or `#!/usr/bin/env -S zsh -f`)
- Support `--help` and exit `0`
- Avoid side effects by default (tests run scripts in a hermetic-ish environment)

If code is meant to be sourced/imported, it MUST live under `_libs/` (or a non-`scripts/` folder) and MUST NOT be executable.

## Testing

### MUST: Keep executable tests centralized

codex-kit testing is repo-level:

- Pytest tests live under `tests/`
- Script regression discovers tracked entrypoints under:
  - `scripts/**`
  - `skills/**/scripts/**`
  - `commands/**`

Skill folders MUST NOT add a top-level `tests/` directory (it would require new discovery rules and layout audits).

### MAY: Skill-local fixtures

If a skill needs test fixtures, store them under:

- `assets/testdata/` (preferred for non-code fixtures)

## Path rules

### MUST: Command snippets use `$CODEX_HOME/...`

All shell command snippets in SKILL.md MUST be runnable from any current working directory by anchoring paths at `$CODEX_HOME`.

Good:

- `$CODEX_HOME/skills/tools/devex/desktop-notify/scripts/project-notify.sh "Done" --level success`

Bad:

- `skills/tools/devex/desktop-notify/scripts/project-notify.sh ...` (breaks when not run from repo root)
- `./scripts/foo.sh ...` (breaks when run from subdirs)

### MAY: Markdown links use repo-relative paths

For GitHub readability, markdown links MAY use repo-relative paths (e.g. `./skills/...`), but executable snippets MUST use `$CODEX_HOME/...`.

### MUST: `$CODEX_HOME` paths must exist and must not be duplicated

Any `$CODEX_HOME/...` path shown in inline code or code blocks MUST:

- Resolve to an existing path in the repo
- Not contain duplicated `$CODEX_HOME/...$CODEX_HOME/...` segments

Enforcement (planned):

- `$CODEX_HOME/scripts/audit-skill-paths.sh`

## Examples

### Tool skill

```
skills/tools/devex/desktop-notify/
├── SKILL.md
└── scripts/
    ├── desktop-notify.sh
    └── project-notify.sh
```

### Workflow skill

```
skills/workflows/plan/create-plan-rigorous/
└── SKILL.md
```

### Project wrapper skill (`_projects`)

```
skills/_projects/tun-group/
├── tun-psql.env
├── tun-mssql.env
├── scripts/
│   ├── tun-psql.zsh
│   └── tun-mssql.zsh
└── tun-psql/
    └── SKILL.md
```

## Adding a new skill

Checklist (copy/paste into a PR):

- [ ] Create the folder under the right namespace:
  - `skills/tools/<area>/<skill-name>/`
  - `skills/workflows/<area>/<skill-name>/`
  - `skills/automation/<skill-name>/`
  - `skills/_projects/<project>/<skill-name>/`

- [ ] Add `SKILL.md` with a valid `## Contract` section (required headings).

- [ ] Add optional resources (no other tracked top-level entries):
  - Executable entrypoints: `scripts/`
  - Docs to be read/loaded: `references/`
  - Scaffolds/templates: `assets/` (Markdown file templates under `assets/templates/`)

- [ ] Shared logic goes under a group `_libs/` folder (non-executable, no
  `scripts/` inside `_libs/`).

- [ ] Command snippets use `$CODEX_HOME/...` paths that exist, without duplicated
  `$CODEX_HOME` segments; `_projects` wrapper paths must point at
  `skills/_projects/<project>/scripts/*.zsh`.

- [ ] Local-only secrets/config in `_projects` use `.env` or `.env.*`
  (gitignored); shared helpers live in `skills/_projects/_libs/` (tracked).

- [ ] Run local validation (all commands exit `0`; no `error:` lines):
  - `$CODEX_HOME/scripts/validate_skill_contracts.sh`
  - `$CODEX_HOME/scripts/audit-skill-layout.sh`
  - `$CODEX_HOME/scripts/audit-skill-paths.sh` (catches `$CODEX_HOME` path
    mistakes + `_projects` wrapper path bugs)
  - `$CODEX_HOME/scripts/check.sh --lint`
  - `$CODEX_HOME/scripts/test.sh`
