# codex-kit

codex-kit tracks my Codex CLI setup so I can keep a consistent workflow across machines.
It contains prompt presets, custom skills, and local tooling wrappers. Secrets and session data
are intentionally excluded via `.gitignore`.

## What This Repo Includes

- `config.toml` for default model and runtime settings.
- `prompts/` for prompt templates (OpenSpec workflows, frpsql, qbmysql).
- `skills/` for custom skills (currently `frpsql` and `qbmysql`).
- `tools/` as a relative symlink to private Zsh tool wrappers (frpsql/qbmysql).
- `.venv/` for local skill validation/packaging (optional).
- Local caches/logs/sessions are ignored by git.

## How I Use It

### Prompt presets

- `/prompts:frpsql <args>` to run Postgres queries via frpsql.
- `/prompts:qbmysql <args>` to run MySQL queries via qbmysql.
- `/prompts:openspec-apply|openspec-archive|openspec-proposal <id>` for OpenSpec workflows.

### Skill example

The `frpsql` skill provides a structured workflow for using frpsql safely and consistently
inside Codex sessions.

## 🗂️ Project Structure

```text
.
├── AGENTS.md
├── README.md
├── config.toml
├── prompts/
├── skills/
└── tools -> ../.config/zsh/.private/tools
```

## Notes

- `tools/` is a relative symlink; it assumes `~/.codex` lives under the home directory.
- Secret `.env` files live under `tools/**/.env` and are ignored by git.
