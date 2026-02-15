---
name: screenshot
description: Capture screenshots via screen-record on macOS and Linux, with optional macOS desktop capture via screencapture.
---

# Screenshot

Capture screenshots through `screen-record` (macOS/Linux) and optional desktop capture via `screencapture` on macOS.

## Contract

Prereqs:

- `screen-record` available on `PATH` (install via `brew install nils-cli`).
- macOS: Screen Recording permission granted (use `screen-record --preflight` / `--request-permission`).
- Linux: follow `screen-record` runtime prerequisites (X11 selectors or Wayland `--portal`, plus required dependencies).
- `screencapture` (built-in on macOS) only when using `--desktop`.
- `bash` for `scripts/screenshot.sh` (wrapper).

Inputs:

- `scripts/screenshot.sh` is a wrapper around `screen-record`; `--desktop` uses `screencapture`.
- Mode selection:
  - Default: screenshot mode (wrapper adds `--screenshot` unless a pass-through mode is present).
  - Desktop helper: `--desktop` captures the main display via `screencapture` (macOS only).
  - Discovery: `--list-windows` / `--list-apps` / `--list-displays`.
  - Permissions: `--preflight` / `--request-permission`.
  - Version: `--version` / `-V` pass through to `screen-record`.
- Screenshot selectors (choose one):
  - `--portal`, or
  - `--window-id <id>`, or
  - `--active-window`, or
  - `--app <name>` (optional `--window-name <name>` with `--app`).
- Screenshot output args:
  - `--path <file>` (recommended), or
  - `--dir <dir>` (used when `--path` is omitted), plus optional `--image-format png|jpg|webp`.

Outputs:

- Screenshot success: stdout prints only the resolved output image path (one line).
- List success: stdout prints only UTF-8 TSV rows (no header), one per line.
- Preflight/request success: stdout is empty; any user messaging goes to stderr.
- Errors: stdout is empty; stderr contains user-facing errors (no stack traces).

Exit codes:

- `0`: success
- `1`: runtime failure or missing dependency
- `2`: usage error (invalid flags/ambiguous selection/unsupported platform)

Failure modes:

- `screen-record` missing on `PATH`.
- Screen Recording permission missing/denied (macOS).
- Linux X11 selectors/list modes used without `DISPLAY` (use `--portal` on Wayland-only sessions).
- `screen-record` runtime dependencies missing (for example: portal backend on Wayland-only sessions).
- Ambiguous `--app` / `--window-name` selection (no single match).
- Invalid flag combinations.
- `--desktop` used on non-macOS.
- `--desktop` only supports `--image-format png|jpg`.

## Scripts (only entrypoints)

- `$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh`

## Usage

- Screenshot (active window) to `$AGENTS_HOME/out/` (recommended):

```bash
$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh --active-window --path "$AGENTS_HOME/out/screenshot.png"
```

- Screenshot via portal picker (Linux Wayland):

```bash
$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh --portal --path "$AGENTS_HOME/out/screenshot-portal.png"
```

- Screenshot the desktop (main display helper, macOS only):

```bash
$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh --desktop --path "$AGENTS_HOME/out/desktop.png"
```

- List windows to find a `--window-id`:

```bash
$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh --list-windows
```

- List displays (pass-through to `screen-record`):

```bash
$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh --list-displays
```

- Screenshot by app/window title:

```bash
$AGENTS_HOME/skills/tools/media/screenshot/scripts/screenshot.sh --app "Terminal" --window-name "Docs" --path "$AGENTS_HOME/out/terminal-docs.png"
```

- Permission preflight / request (if blocked):

```bash
screen-record --preflight
screen-record --request-permission
```

## Notes

- Prefer writing under `"$AGENTS_HOME/out/"` so outputs are easy to attach/inspect.
- For non-window video capture, use `screen-record --display` / `--display-id` (recording mode).
