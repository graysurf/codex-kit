# codex-kit

codex-kit tracks my Codex CLI setup so I can keep a consistent workflow across machines.
It contains prompt presets, custom skills, and local tooling wrappers. Secrets and session data
are intentionally excluded via `.gitignore`.

## 🗂️ Project Structure

```text
.
├── AGENTS.md
├── README.md
├── config.toml                             # default model and runtime settings
├── prompts/                                # prompt templates
├── skills/                                 # custom skills
└── tools -> ../.config/zsh/.private/tools  # private Zsh tool wrappers
```

## 🧑‍💻 How I Use It

### Prompt presets

- `/prompts:frpsql <args>` to run Postgres queries via frpsql.
- `/prompts:openspec-apply|openspec-archive|openspec-proposal <id>` for OpenSpec workflows.

### Skill example

- The `committer` skill provides a structured workflow for generating Semantic Commit messages
inside Codex sessions.

## 📜 Notes

- `tools/` is a relative symlink; it assumes `~/.codex` lives under the home directory.
- Secret `.env` files live under `tools/**/.env` and are ignored by git.
