# Playwright CLI Reference

## Setup Preconditions

- `bash` and `npx` are required for non-help commands.
- First package fetch needs network access (`@playwright/cli@latest`).
- Browser-dependent commands require Playwright browser binaries.
- Optional: set `PLAYWRIGHT_MCP_OUTPUT_DIR` when artifact output path must be deterministic.

## Canonical Wrapper Invocation

Use the canonical wrapper entrypoint:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
"$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" --help
"$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh" open https://example.com --headed
```

Or set a reusable alias:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/tools/browser/playwright/scripts/playwright_cli.sh"
alias pwcli="$PWCLI"
pwcli --help
```

Wrapper runtime for non-help commands:

```bash
npx --yes --package @playwright/cli@latest playwright-cli ...
```

## Core Commands

Bootstrap:

```bash
pwcli install-browser
pwcli install-skills
pwcli config --help
```

Page + element interaction:

```bash
pwcli open https://example.com
pwcli snapshot
pwcli click e3
pwcli fill e5 "user@example.com"
pwcli press Enter
pwcli eval "document.title"
pwcli screenshot
```

Navigation + tabs:

```bash
pwcli go-back
pwcli reload
pwcli tab-list
pwcli tab-new https://example.com/docs
pwcli tab-select 1
```

Diagnostics + artifacts:

```bash
pwcli console warning
pwcli network
pwcli tracing-start
pwcli tracing-stop
pwcli pdf
```

## Session Behavior

- `--session` / `--session=<name>` is passed through unchanged.
- If `--session` is omitted and `PLAYWRIGHT_CLI_SESSION` is set, the wrapper injects `--session "$PLAYWRIGHT_CLI_SESSION"` before forwarding args.
- `--help` / `-h` is handled locally by the wrapper (no `npx`, Node, or network needed).

## Troubleshooting

- `Error: npx is required but not found on PATH.`:
  install Node.js/npm and ensure `npx` is on `PATH`.
- First-run fetch fails:
  allow access to npm registry and retry.
- Browser launch commands fail:
  run `pwcli install-browser`.
- Element refs become stale:
  run `pwcli snapshot` again after navigation or major DOM changes.
