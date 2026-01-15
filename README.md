# codex-kit

codex-kit tracks Codex CLI setup to keep workflows consistent across machines. It contains prompt presets, custom skills, and local tooling wrappers. Secrets and session data
are intentionally excluded via `.gitignore`.

## 🗂️ Project Structure

```text
.
├── .github/    # CI workflows (GitHub Actions)
├── prompts/    # prompt presets
├── skills/     # skills (tools/, workflows/, automation/, _projects/, .system/)
├── scripts/    # loader + helper scripts
├── docs/       # docs, templates, progress logs
├── tests/      # pytest regression/smoke tests
└── AGENTS.md   # global agent rules (response/tooling)
```

## ⚙️ Setup

Set `CODEX_HOME` in `~/.zshenv`:

```zsh
export CODEX_HOME="$HOME/.codex"
```

Optional: set `PROJECT_PATH` per project (e.g. in a repo’s `.envrc`) so tools can treat that repo as the active project context:

```zsh
export PROJECT_PATH="$PWD"
```

## ✅ Tests

Run the repo pytest suite:

```bash
scripts/test.sh
```

Artifacts are written under `out/tests/` (gitignored):

- `out/tests/script-regression/summary.json`: per-script `--help` regression harness results
- `out/tests/script-smoke/summary.json`: deeper smoke-case results (from `tests/script_specs/**.json`)
- `out/tests/script-coverage/summary.md`: functional coverage report (what ran + smoke spec coverage)

## 🧰 Prompts

### Common

| Prompt | Description | Usage |
| --- | --- | --- |
| [actionable-advice](./prompts/actionable-advice.md) | Answer a question with clarifying questions, multiple options, and a single recommendation | `/prompts:actionable-advice <question>` |
| [actionable-knowledge](./prompts/actionable-knowledge.md) | Answer a learning/knowledge question with multiple explanation paths and a single recommended path | `/prompts:actionable-knowledge <question>` |

## 🛠️ Skills

All tracked skills must include a minimal `## Contract` section (5 required headings) enforced by `scripts/validate_skill_contracts.sh` and CI.

Core skills are grouped under `skills/workflows/`, `skills/tools/`, and `skills/automation/`. Project-specific skills live under `skills/_projects/`. Internal/meta skills live under `skills/.system/` (not listed below).

### Workflows

| Area | Skill | Description |
| --- | --- | --- |
| Conversation | [ask-questions-if-underspecified](./skills/workflows/conversation/ask-questions-if-underspecified/) | Clarify requirements with minimal must-have questions before starting work when a request is underspecified |
| PR / Feature | [create-feature-pr](./skills/workflows/pr/feature/create-feature-pr/) | Create feature branches and open a PR with a standard template |
| PR / Feature | [close-feature-pr](./skills/workflows/pr/feature/close-feature-pr/) | Merge and close PRs after a quick PR hygiene review; delete the feature branch |
| PR / Progress | [create-progress-pr](./skills/workflows/pr/progress/create-progress-pr/) | Create a progress planning file under docs/progress/ and open a PR (no implementation yet) |
| PR / Progress | [handoff-progress-pr](./skills/workflows/pr/progress/handoff-progress-pr/) | Merge and close a progress planning PR; patch Progress link to base branch; kick off implementation PRs |
| PR / Progress | [close-progress-pr](./skills/workflows/pr/progress/close-progress-pr/) | Finalize/archive a progress file for a PR, then merge and patch Progress links to base branch |
| PR / Progress | [progress-addendum](./skills/workflows/pr/progress/progress-addendum/) | Add an append-only Addendum section to DONE progress files (top-of-file), with audit + template scripts to keep archived docs from going stale. |

### Tools

| Area | Skill | Description |
| --- | --- | --- |
| Browser | [chrome-devtools-site-search](./skills/tools/browser/chrome-devtools-site-search/) | Browse a site via the chrome-devtools MCP server, summarize results, and open matching pages |
| DevEx | [semantic-commit](./skills/tools/devex/semantic-commit/) | Commit staged changes using Semantic Commit format |
| DevEx | [open-changed-files-review](./skills/tools/devex/open-changed-files-review/) | Open files edited by Codex in VSCode after making changes (silent no-op when unavailable) |
| DevEx | [desktop-notify](./skills/tools/devex/desktop-notify/) | Send desktop notifications via terminal-notifier (macOS) or notify-send (Linux) |
| Testing | [api-test-runner](./skills/tools/testing/api-test-runner/) | Run CI-friendly API test suites (REST + GraphQL) from a single manifest; emits JSON (+ optional JUnit) results |
| Testing | [graphql-api-testing](./skills/tools/testing/graphql-api-testing/) | Test GraphQL APIs with repeatable, file-based operations/variables and generate API test reports |
| Testing | [rest-api-testing](./skills/tools/testing/rest-api-testing/) | Test REST APIs with repeatable, file-based requests and generate API test reports |

### Automation

| Area | Skill | Description |
| --- | --- | --- |
| DevEx | [semantic-commit-autostage](./skills/automation/semantic-commit-autostage/) | Autostage (git add) and commit changes using Semantic Commit format for fully automated workflows |
| Maintenance | [find-and-fix-bugs](./skills/automation/find-and-fix-bugs/) | Find, triage, and fix bugs; open a PR with a standard template |
| Maintenance | [semgrep-find-and-fix](./skills/automation/semgrep-find-and-fix/) | Scan a repo using its local Semgrep config, triage findings, and open a fix PR or report-only PR |
| Release | [release-workflow](./skills/automation/release-workflow/) | Execute project release workflows by following RELEASE_GUIDE.md |

### Project-specific

| Skill | Description |
| --- | --- |
| [fr-psql](./skills/_projects/finance-report/fr-psql/) | Run PostgreSQL queries via the fr-psql wrapper |
| [mb-mssql](./skills/_projects/megabank/mb-mssql/) | Run SQL Server queries via the mb-mssql wrapper |
| [qb-mysql](./skills/_projects/qburger/qb-mysql/) | Run MySQL queries via the qb-mysql wrapper |
| [tun-mssql](./skills/_projects/tun-group/tun-mssql/) | Run SQL Server queries via the tun-mssql wrapper |
| [tun-psql](./skills/_projects/tun-group/tun-psql/) | Run PostgreSQL queries via the tun-psql wrapper |

## Semgrep

- Local rules: `.semgrep.yaml`
- Curated open-source configs (Semgrep Registry): `scripts/semgrep-scan.sh`
  - `recommended`: `p/ci`, `p/python`, `p/github-actions`
  - `security`: adds `p/security-audit`, `p/secrets`, `p/supply-chain`, `p/command-injection`

## 🪪 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is licensed under the MIT License. See [LICENSE](LICENSE).
