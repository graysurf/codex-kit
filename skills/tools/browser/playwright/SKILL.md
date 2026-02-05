---
name: playwright
description: Automate a real browser via Playwright CLI using the wrapper script.
---

# Playwright CLI

## Contract

Prereqs:

- `bash` on PATH
- `npx` on PATH (Node.js/npm)
- Network access on first run to download `@playwright/cli`
- Optional: Playwright browsers installed (`install-browser`)

Inputs:

- CLI subcommand + args forwarded to Playwright CLI
- Optional env: `PLAYWRIGHT_CLI_SESSION` for named sessions

Outputs:

- Browser automation actions
- Artifacts in `PLAYWRIGHT_MCP_OUTPUT_DIR` if set; otherwise `.playwright-cli/` in the workspace root (Playwright CLI default)

Exit codes:

- `0`: success
- `1`: CLI/runtime failure
- `2`: usage error

Failure modes:

- `npx` missing or Node.js too old (< 18)
- Network blocked (cannot download `@playwright/cli`)
- Browser missing (run `install-browser`)

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh`

## Scope

- This skill is for Playwright CLI (the token-efficient CLI with SKILLS), not the Playwright MCP server.
- Keep it CLI-first; do not pivot to `@playwright/test` unless the user explicitly requests test files.

## Prerequisite check (required)

Before proposing commands, check whether `npx` is available (the wrapper depends on it):

```bash
command -v npx >/dev/null 2>&1
```

If it is not available, pause and ask the user to install Node.js/npm (which provides `npx`). Provide these steps verbatim:

```bash
# Verify Node/npm are installed
node --version
npm --version

# If missing (or Node < 18), install/upgrade Node.js/npm, then:
npm install -g @playwright/cli@latest
playwright-cli --help
playwright-cli install-skills
playwright-cli install-browser
```

Once `npx` is present, proceed with the wrapper script. A global install of `playwright-cli` is optional.

## Skill path (set once)

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh"
```

User-scoped skills install under `$CODEX_HOME/skills` (default: `~/.codex/skills`).

## Artifact location (required in this repo)

To avoid `.playwright-cli/`, set the output directory explicitly:

```bash
export PLAYWRIGHT_MCP_OUTPUT_DIR="$PWD/out/playwright/<label>"
mkdir -p "$PLAYWRIGHT_MCP_OUTPUT_DIR"
```

## First-time setup (once per machine)

Use the wrapper to install skills and browsers:

```bash
"$PWCLI" install-skills
"$PWCLI" install-browser
```

## Quick start

Use the wrapper script:

```bash
"$PWCLI" open https://playwright.dev --headed
"$PWCLI" snapshot
"$PWCLI" click e15
"$PWCLI" type "Playwright"
"$PWCLI" press Enter
"$PWCLI" screenshot
```

If the user prefers a global install, this is also valid:

```bash
npm install -g @playwright/cli@latest
playwright-cli --help
playwright-cli install-skills
playwright-cli install-browser
```

## Core workflow

1. Open the page.
2. Snapshot to get stable element refs.
3. Interact using refs from the latest snapshot.
4. Re-snapshot after navigation or significant DOM changes.
5. Capture artifacts (screenshot, pdf, traces) when useful.

Minimal loop:

```bash
"$PWCLI" open https://example.com
"$PWCLI" snapshot
"$PWCLI" click e3
"$PWCLI" snapshot
```

## When to snapshot again

Snapshot again after:

- navigation
- clicking elements that change the UI substantially
- opening/closing modals or menus
- tab switches

Refs can go stale. When a command fails due to a missing ref, snapshot again.

## Recommended patterns

### Form fill and submit

```bash
"$PWCLI" open https://example.com/form
"$PWCLI" snapshot
"$PWCLI" fill e1 "user@example.com"
"$PWCLI" fill e2 "password123"
"$PWCLI" click e3
"$PWCLI" snapshot
```

### Debug a UI flow with traces

```bash
"$PWCLI" open https://example.com --headed
"$PWCLI" tracing-start
# ...interactions...
"$PWCLI" tracing-stop
```

### Multi-tab work

```bash
"$PWCLI" tab-new https://example.com
"$PWCLI" tab-list
"$PWCLI" tab-select 0
"$PWCLI" snapshot
```

## Wrapper script

The wrapper script uses `npx --package @playwright/cli@latest playwright-cli` so the CLI can run without a global install:

```bash
"$PWCLI" --help
```

Prefer the wrapper unless the repository already standardizes on a global install.

## Known issues

- Playwright CLI 0.0.63: after creating a named session, subsequent commands with `--session` may fail with "The session is already configured." Workarounds: use the default session (no `--session`) or delete/recreate the session (`session-delete <name>` then `--session <name> open ...`).

## References

Open only what you need:

- CLI command reference: `references/cli.md`
- Practical workflows and troubleshooting: `references/workflows.md`

## Guardrails

- Always snapshot before referencing element ids like `e12`.
- Re-snapshot when refs seem stale.
- Prefer explicit commands over `eval` and `run-code` unless needed.
- When you do not have a fresh snapshot, use placeholder refs like `eX` and say why; do not bypass refs with `run-code`.
- Use `--headed` when a visual check will help.
- When capturing artifacts in this repo, set `PLAYWRIGHT_MCP_OUTPUT_DIR=out/playwright/<label>` so outputs never go to `.playwright-cli/`.
- Default to CLI commands and workflows, not Playwright test specs.
