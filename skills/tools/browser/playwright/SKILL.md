---
name: playwright
description: Automate a real browser via Playwright CLI using the wrapper script.
---

# Playwright CLI

## Contract

Prereqs:

- `bash` available on `PATH`.
- `npx` available on `PATH` (provided by Node.js/npm).
- Network access on first package fetch for `@playwright/cli@latest`.
- Optional: Playwright browser binaries installed for browser-dependent commands.

Inputs:

- CLI subcommand and args forwarded to Playwright CLI.
- Optional env: `PLAYWRIGHT_CLI_SESSION` (injected only when `--session` is not already provided).
- Required env for non-help commands: `PLAYWRIGHT_MCP_OUTPUT_DIR`, and it must point to `out/playwright/` (optionally with a subdirectory, for example `out/playwright/run-001`).

Outputs:

- Stdout/stderr from upstream `playwright-cli`.
- Upstream artifacts must be written under `out/playwright/` via `PLAYWRIGHT_MCP_OUTPUT_DIR`.
- Do not use the default `.playwright-cli/` artifact location.

Exit codes:

- `0`: success
- `1`: wrapper runtime failure (for example, missing `npx`)
- non-zero: forwarded failure from upstream `playwright-cli`

Failure modes:

- `npx` missing from `PATH`.
- Network blocked during first-time package download.
- Browser binary missing for commands that require a browser.
- Invalid/unsupported subcommand or flags (reported by upstream CLI).

## Scope

- Thin wrapper only: runtime command is `npx --yes --package @playwright/cli@latest playwright-cli ...`.
- This skill does not own Playwright test architecture, repo E2E design, or Playwright MCP server behavior.

## Scripts (only entrypoints)

- `scripts/playwright_cli.sh`

## Usage

```bash
export AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"
export PLAYWRIGHT_MCP_OUTPUT_DIR="out/playwright/default"
"$AGENTS_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" --help
"$AGENTS_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" open https://playwright.dev --headed
"$AGENTS_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" snapshot
```

## Guardrails

- Before non-help commands, verify `npx` exists: `command -v npx >/dev/null 2>&1`.
- Prefer the wrapper entrypoint instead of global `playwright-cli` installation.
- Run `snapshot` before using element refs and re-snapshot after navigation or major DOM changes.
- Always set `PLAYWRIGHT_MCP_OUTPUT_DIR` to a path under `out/playwright/` before non-help commands.
- Never store Playwright artifacts in `.playwright-cli/`.

## References

- `references/cli.md`
- `references/workflows.md`
