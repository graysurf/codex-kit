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
└── tools -> ../zsh/.private/tools          # private Zsh tool wrappers
```

## 🧑‍💻 How I Use It

### Prompt presets

| Prompt | Description | Usage |
| --- | --- | --- |
| frpsql | Run frpsql with args or SQL | `/prompts:frpsql <args>` |
| qbmysql | Run qbmysql with args or SQL | `/prompts:qbmysql <args>` |
| openspec-apply | Implement an approved OpenSpec change | `/prompts:openspec-apply <id>` |
| openspec-archive | Archive an OpenSpec change and update specs | `/prompts:openspec-archive <id>` |
| openspec-proposal | Scaffold a new OpenSpec change | `/prompts:openspec-proposal <request>` |

### Skills

| Skill | Description |
| --- | --- |
| commit-message | Generate Semantic Commit messages from staged changes |
| find-and-fix-bugs | Find, triage, and fix bugs; open a PR with gh |
| release-workflow | Execute project release workflows by following RELEASE_GUIDE.md |
| fr-api-doc-playbook | Test FinanceReport GraphQL APIs and draft docs |
| frpsql | Run PostgreSQL queries via the frpsql wrapper |
| qbmysql | Run MySQL queries via the qbmysql wrapper |

## 📜 Notes

- This repo lives at `~/.config/codex-kit`; `~/.codex` is a symlink here and is the configured Codex home.
- Secret `.env` files live under `tools/**/.env` and are ignored by git.
