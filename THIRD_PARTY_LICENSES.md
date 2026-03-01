# Third-Party Licenses

Last updated: 2026-03-01

## Scope

This file lists third-party components directly referenced by this repository for local development and runtime tooling.

Included:

- Python dependencies declared in `requirements-dev.txt`.
- NPM packages invoked via `npx --package ...` in repo scripts.
- Homebrew formula `nils-cli`, which provides required CLI commands used by repo workflows.
- Required system tools explicitly invoked by required repo checks (for example `shellcheck` in `scripts/lint.sh`).

Not included:

- Full transitive dependency trees (not fully pinned in this repository).
- Optional OS-level tools documented for convenience only (for example `jq`).
- Baseline host-environment runtimes/utilities not installed by this repository (for example `zsh`, `git`, `node`).

## Third-Party Components

| Component | Ecosystem | Declared spec in repo | Resolved version (local) | License | Upstream |
| --- | --- | --- | --- | --- | --- |
| `pytest` | PyPI | `pytest>=7.0` | `9.0.2` | `MIT` | [pytest-dev/pytest](https://github.com/pytest-dev/pytest) |
| `semgrep` | PyPI | `semgrep==1.148.0` | `1.148.0` | `LGPL-2.1-or-later` | [returntocorp/semgrep](https://github.com/returntocorp/semgrep) |
| `mypy` | PyPI | `mypy>=1.0` | `1.19.1` | `MIT` | [python/mypy](https://github.com/python/mypy) |
| `ruff` | PyPI | `ruff>=0.1.0` | `0.15.1` | `MIT` | [astral-sh/ruff](https://github.com/astral-sh/ruff) |
| `pyright` (Python wrapper) | PyPI | `pyright>=1.1.0` | `1.1.408` | `MIT` | [RobertCraigie/pyright-python](https://github.com/RobertCraigie/pyright-python) |
| `@playwright/cli` | npm | `@playwright/cli@latest` | `0.1.1` | `Apache-2.0` | [microsoft/playwright-cli](https://github.com/microsoft/playwright-cli) |
| `agent-browser` | npm | `agent-browser@latest` | `0.15.1` | `Apache-2.0` | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) |
| `markdownlint-cli2` | npm | `markdownlint-cli2@0.21.0` | `0.21.0` | `MIT` | [DavidAnson/markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) |
| `shellcheck` | Homebrew / apt | `brew install shellcheck` (macOS) / `apt-get install -y shellcheck` (Ubuntu) | `0.11.0` | `GPL-3.0-or-later` | [koalaman/shellcheck](https://github.com/koalaman/shellcheck) |
| `nils-cli` | Homebrew formula | `brew install nils-cli` | `0.6.0` | `MIT OR Apache-2.0` | [graysurf/nils-cli](https://github.com/graysurf/nils-cli) |

## Declaration Sources

- Python specs: `requirements-dev.txt`
- Playwright CLI wrapper: `skills/tools/browser/playwright/scripts/playwright_cli.sh`
- Agent Browser CLI wrapper: `skills/tools/browser/agent-browser/scripts/agent-browser.sh`
- Markdown lint runner: `scripts/ci/markdownlint-audit.sh`
- Shell lint dependency: `scripts/lint.sh` and `DEVELOPMENT.md`
- `nils-cli` installation references:
  - `DEVELOPMENT.md`
  - `Dockerfile`

## Notes

- `@latest` npm specs are intentionally floating; the "Resolved version (local)" column reflects the versions observed on 2026-03-01.
- For complete license terms, see each upstream project repository and/or distributed package metadata.
