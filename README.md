# codex-kit

codex-kit tracks Codex CLI setup to keep workflows consistent across machines. It contains prompt presets, custom skills, and local tooling. Secrets and session data are
intentionally excluded via `.gitignore`.

## 🗂️ Project Structure

```text
.
├── .github/    # CI workflows (GitHub Actions)
├── prompts/    # prompt presets
├── skills/     # skills (tools/, workflows/, automation/, _projects/, .system/)
├── scripts/    # loader + helper scripts
├── docker/     # Docker images + env tooling
├── docs/       # docs, templates, progress logs
├── tests/      # pytest regression/smoke tests
└── AGENTS.md   # global agent rules (response/tooling)
```

## ⚙️ Setup

Install required tooling via the Homebrew tap:

```zsh
brew tap graysurf/tap
brew install nils-cli
```

Upgrade when needed:

```zsh
brew upgrade nils-cli
```

Set `CODEX_HOME` in `$HOME/.zshenv`:

```zsh
export CODEX_HOME="$HOME/.codex"
```

Optional: set `PROJECT_PATH` per project (e.g. in a repo’s `.envrc`) so tools can treat that repo as the active project context:

```zsh
export PROJECT_PATH="$PWD"
```

For new repositories with missing policy baseline docs, run the canonical bootstrap flow:

```zsh
$CODEX_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh --dry-run --project-path "$PROJECT_PATH"
$CODEX_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh --apply --project-path "$PROJECT_PATH"
agent-docs baseline --check --target all --strict --project-path "$PROJECT_PATH" --format text
```

See [docs/runbooks/agent-docs/new-project-bootstrap.md](./docs/runbooks/agent-docs/new-project-bootstrap.md) for the full sequence.

## 🐳 Docker environment

See [docker/codex-env/README.md](docker/codex-env/README.md) for the Ubuntu Docker environment, Docker Hub publish steps, and compose usage.

## 🧰 Prompts

### Common

| Prompt | Description | Usage |
| --- | --- | --- |
| [actionable-advice](./prompts/actionable-advice.md) | Answer a question with clarifying questions, multiple options, and a single recommendation | `/prompts:actionable-advice <question>` |
| [actionable-knowledge](./prompts/actionable-knowledge.md) | Answer a learning/knowledge question with multiple explanation paths and a single recommended path | `/prompts:actionable-knowledge <question>` |
| [parallel-first](./prompts/parallel-first.md) | Enable a parallel-first execution policy for this conversation thread (prefer delegate-parallel subagents when safe) | `/prompts:parallel-first` |

## 🛠️ Skills

### Skill management

See [skills/tools/skill-management/README.md](./skills/tools/skill-management/README.md) for how to create/validate/remove skills (including project-local `.codex/skills`) using canonical entrypoints.

Core skills are grouped under [skills/workflows/](skills/workflows), [skills/tools/](skills/tools), and [skills/automation/](skills/automation). Internal/meta skills live under `skills/.system/` (not listed below).

### Workflows

| Area | Skill | Description |
| --- | --- | --- |
| Conversation | [ask-questions-if-underspecified](./skills/workflows/conversation/ask-questions-if-underspecified/) | Clarify requirements with minimal must-have questions before starting work when a request is underspecified |
| Conversation | [delegate-parallel](./skills/workflows/coordination/delegate-parallel/) | Decompose a goal into parallelizable tasks and execute via parallel subagents, then validate |
| Planning | [create-plan](./skills/workflows/plan/create-plan/) | Create a comprehensive, phased implementation plan and save it under docs/plans/ |
| Planning | [create-plan-rigorous](./skills/workflows/plan/create-plan-rigorous/) | Create an extra-thorough implementation plan and get a subagent review |
| Planning | [execute-plan-parallel](./skills/workflows/plan/execute-plan-parallel/) | Execute a markdown plan by spawning parallel subagents for unblocked tasks, then validate |
| PR / Feature | [create-feature-pr](./skills/workflows/pr/feature/create-feature-pr/) | Create feature branches and open a PR with a standard template |
| PR / Feature | [close-feature-pr](./skills/workflows/pr/feature/close-feature-pr/) | Merge and close PRs after a quick PR hygiene review; delete the feature branch |
| PR / Progress | [create-progress-pr](./skills/workflows/pr/progress/create-progress-pr/) | Create a progress planning file under docs/progress/ and open a PR (no implementation yet) |
| PR / Progress | [handoff-progress-pr](./skills/workflows/pr/progress/handoff-progress-pr/) | Merge and close a progress planning PR; patch Progress link to base branch; kick off implementation PRs |
| PR / Progress | [worktree-stacked-feature-pr](./skills/workflows/pr/progress/worktree-stacked-feature-pr/) | Handoff a progress planning PR, then create multiple stacked feature PRs using git worktrees and parallel subagents (one PR per sprint/phase) |
| PR / Progress | [close-progress-pr](./skills/workflows/pr/progress/close-progress-pr/) | Finalize/archive a progress file for a PR, then merge and patch Progress links to base branch |
| PR / Progress | [progress-addendum](./skills/workflows/pr/progress/progress-addendum/) | Add an append-only Addendum section to DONE progress files (top-of-file), with audit + template scripts to keep archived docs from going stale. |

### Tools

| Area | Skill | Description |
| --- | --- | --- |
| Agent Docs | [agent-doc-init](./skills/tools/agent-doc-init/) | Initialize missing baseline docs safely (dry-run first), then upsert optional project extension entries |
| App Ops | [macos-agent-ops](./skills/tools/macos-agent-ops/) | Run repeatable macOS app checks/scenarios with `macos-agent` |
| Browser | [chrome-devtools-debug-companion](./skills/tools/browser/chrome-devtools-debug-companion/) | Diagnose browser-level issues via chrome-devtools MCP with evidence-driven root-cause analysis |
| Browser | [playwright](./skills/tools/browser/playwright/) | Automate a real browser via Playwright CLI using the wrapper script |
| Skill Management | [skill-governance](./skills/tools/skill-management/skill-governance/) | Audit skill layout and validate SKILL.md contracts |
| Skill Management | [create-skill](./skills/tools/skill-management/create-skill/) | Scaffold a new skill directory that passes skill-governance audit and contract validation |
| Skill Management | [create-project-skill](./skills/tools/skill-management/create-project-skill/) | Scaffold a project-local skill under `<project>/.codex/skills/` with contract/layout validation |
| Skill Management | [remove-skill](./skills/tools/skill-management/remove-skill/) | Remove a tracked skill directory and purge non-archived repo references (breaking change) |
| DevEx | [semantic-commit](./skills/tools/devex/semantic-commit/) | Commit staged changes using Semantic Commit format |
| DevEx | [open-changed-files-review](./skills/tools/devex/open-changed-files-review/) | Open files edited by Codex in VSCode after making changes (silent no-op when unavailable) |
| DevEx | [desktop-notify](./skills/tools/devex/desktop-notify/) | Send desktop notifications via terminal-notifier (macOS) or notify-send (Linux) |
| Media | [image-processing](./skills/tools/media/image-processing/) | Process images (convert/resize/crop/optimize) via ImageMagick |
| Media | [screen-record](./skills/tools/media/screen-record/) | Record a single window or full display to a video file via the screen-record CLI (macOS 12+ and Linux) |
| Media | [screenshot](./skills/tools/media/screenshot/) | Capture screenshots via screen-record on macOS and Linux, with optional macOS desktop capture via screencapture |
| SQL | [sql-postgres](./skills/tools/sql/sql-postgres/) | Run PostgreSQL queries via psql using a prefix + env file convention |
| SQL | [sql-mysql](./skills/tools/sql/sql-mysql/) | Run MySQL queries via mysql client using a prefix + env file convention |
| SQL | [sql-mssql](./skills/tools/sql/sql-mssql/) | Run SQL Server queries via sqlcmd using a prefix + env file convention |
| Testing | [api-test-runner](./skills/tools/testing/api-test-runner/) | Run CI-friendly API test suites (REST + GraphQL) from a single manifest; emits JSON (+ optional JUnit) results |
| Testing | [graphql-api-testing](./skills/tools/testing/graphql-api-testing/) | Test GraphQL APIs with repeatable, file-based operations/variables and generate API test reports |
| Testing | [rest-api-testing](./skills/tools/testing/rest-api-testing/) | Test REST APIs with repeatable, file-based requests and generate API test reports |

### Automation

| Area | Skill | Description |
| --- | --- | --- |
| CI | [gh-fix-ci](./skills/automation/gh-fix-ci/) | Automatically fix failing GitHub Actions checks, semantic-commit-autostage + push, and retry until green |
| DevEx | [semantic-commit-autostage](./skills/automation/semantic-commit-autostage/) | Autostage (git add) and commit changes using Semantic Commit format for fully automated workflows |
| Maintenance | [fix-bug-pr](./skills/automation/fix-bug-pr/) | Find bug-type PRs with unresolved bug items, fix and push updates, comment, and keep PR body status synced |
| Maintenance | [find-and-fix-bugs](./skills/automation/find-and-fix-bugs/) | Find, triage, and fix bugs; open a PR with a standard template |
| Maintenance | [semgrep-find-and-fix](./skills/automation/semgrep-find-and-fix/) | Scan a repo using its local Semgrep config, triage findings, and open a fix PR or report-only PR |
| Release | [release-workflow](./skills/automation/release-workflow/) | Execute project release workflows by following a repo release guide (with a bundled fallback) |

## 🪪 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is licensed under the MIT License. See [LICENSE](LICENSE).
