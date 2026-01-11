# codex-kit

codex-kit tracks Codex CLI setup to keep workflows consistent across machines. It contains prompt presets, custom skills, and local tooling wrappers. Secrets and session data
are intentionally excluded via `.gitignore`.

## 🗂️ Project Structure

```text
.
├── AGENTS.md
├── README.md
├── config.toml                             # default model and runtime settings
├── scripts/                                # helpers (incl. codex-tools loader)
├── prompts/                                # prompt templates
├── skills/                                 # custom skills
├── docs/                                   # docs and progress tracking
└── setup/                                  # request templates / fixtures
```

## 🧰 Prompts

### Common

| Prompt | Description | Usage |
| --- | --- | --- |
| actionable-advice | Answer a question with clarifying questions, multiple options, and a single recommendation | `/prompts:actionable-advice <question>` |
| actionable-knowledge | Answer a learning/knowledge question with multiple explanation paths and a single recommended path | `/prompts:actionable-knowledge <question>` |
| openspec-apply | Implement an approved OpenSpec change | `/prompts:openspec-apply <id>` |
| openspec-archive | Archive an OpenSpec change and update specs | `/prompts:openspec-archive <id>` |
| openspec-proposal | Scaffold a new OpenSpec change | `/prompts:openspec-proposal <request>` |

## 🛠️ Skills

All tracked skills must include a minimal `## Contract` section (5 required headings) enforced by `scripts/validate_skill_contracts.sh` and CI.

### Common

| Skill | Description |
| --- | --- |
| chrome-devtools-site-search | Browse a site via the chrome-devtools MCP server, summarize results, and open matching pages |
| commit-message | Generate Semantic Commit messages from staged changes |
| create-feature-pr | Create feature branches and open a PR with a standard template |
| close-feature-pr | Merge and close PRs after a quick PR hygiene review; delete the feature branch |
| create-progress-pr | Create a progress planning file under docs/progress/ and open a PR (no implementation yet) |
| close-progress-pr | Finalize/archive a progress file for a PR, then merge and patch Progress links to base branch |
| find-and-fix-bugs | Find, triage, and fix bugs; open a PR with a standard template |
| open-changed-files-review | Open files edited by Codex in VSCode after making changes (silent no-op when unavailable) |
| desktop-notify | Send desktop notifications via terminal-notifier (macOS) or notify-send (Linux) |
| api-test-runner | Run CI-friendly API test suites (REST + GraphQL) from a single manifest; emits JSON (+ optional JUnit) results |
| graphql-api-testing | Test GraphQL APIs with repeatable, file-based operations/variables and generate API test reports |
| rest-api-testing | Test REST APIs with repeatable, file-based requests and generate API test reports |
| release-workflow | Execute project release workflows by following RELEASE_GUIDE.md |

### Project-specific

| Skill | Description |
| --- | --- |
| fr-psql | Run PostgreSQL queries via the fr-psql wrapper |
| mb-mssql | Run SQL Server queries via the mb-mssql wrapper |
| qb-mysql | Run MySQL queries via the qb-mysql wrapper |
| tun-mssql | Run SQL Server queries via the tun-mssql wrapper |
| tun-psql | Run PostgreSQL queries via the tun-psql wrapper |

## 📜 Notes

- This repo lives at `~/.config/codex-kit`; `$CODEX_HOME` is a symlink here and is the configured Codex home.
- Tools loader (single source of truth): `source $CODEX_HOME/scripts/codex-tools.sh`.
- Desktop notifications: use `skills/desktop-notify/scripts/project-notify.sh` (project title) or `skills/desktop-notify/scripts/desktop-notify.sh` (custom title).
