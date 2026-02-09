# Screen Record guide

This skill uses the `screen-record` CLI (from `nils-cli`) to capture windows/displays on macOS and Linux.
It supports both recording and screenshot mode.

## Quick decision tree

- Need to pick a target window deterministically:
  - Run `screen-record --list-windows`
  - Choose a `window_id` and capture with `--window-id <id>`
- Want "whatever I'm looking at right now":
  - Use `--active-window`
- Want "the Terminal window" (may be ambiguous):
  - Start with `--app Terminal`
  - If ambiguous, refine with `--window-name` or use a specific `--window-id`
- Need full desktop/non-window capture:
  - Run `screen-record --list-displays`
  - Use `--display-id <id>` (or `--display` for the main display, recording mode only)
- Wayland-only Linux session (no `DISPLAY`):
  - Use interactive `--portal` for recording/screenshot flows

## Preflight / permission workflow

- macOS:
  - Check status: `screen-record --preflight`
  - Best-effort request: `screen-record --request-permission`
- Linux:
  - `screen-record --preflight` validates runtime prerequisites (`ffmpeg`, X11/portal availability)
  - `screen-record --request-permission` behaves like preflight

If capture fails with a permission error on macOS, the fix is typically:

1. macOS System Settings -> Privacy & Security -> Screen Recording
2. Enable the terminal/app running the command
3. Restart the terminal/app and retry

## Mode rules (important)

- Exactly one mode must be selected:
  - `--list-windows`, `--list-apps`, `--list-displays`, `--preflight`, `--request-permission`,
    `--screenshot`, or recording (default).
- Recording mode requires:
  - exactly one selector: `--portal`, `--window-id`, `--active-window`, `--app`, `--display`,
    or `--display-id`
  - `--duration <seconds>`
  - `--path <file>`
- Screenshot mode (`--screenshot`) requires:
  - exactly one selector: `--portal`, `--window-id`, `--active-window`, or `--app`
  - optional output flags: `--path`, `--dir`, `--image-format`
  - optional diff-aware flags: `--if-changed`, `--if-changed-baseline`, `--if-changed-threshold`
- `--display` / `--display-id` are invalid with `--screenshot`.
- `--metadata-out` / `--diagnostics-out` are recording-only flags.
- `--window-name` is only valid with `--app`.
- `--portal` is interactive and currently supports `--audio off` only.
- `--audio both` requires `.mov`.

## Output contract (what to parse)

- Capture success (recording/screenshot): stdout is only the resolved output file path + newline.
- List success: stdout is only TSV rows + newline (no header).
- Preflight/request success: stdout is empty; user messaging goes to stderr.
- Errors: stdout is empty; stderr contains user-facing errors.

## Examples

List windows:

```bash
screen-record --list-windows
```

List apps:

```bash
screen-record --list-apps
```

List displays:

```bash
screen-record --list-displays
```

Record the active window (no audio):

```bash
screen-record --active-window --duration 5 --audio off --path "$CODEX_HOME/out/screen-record/active-5s.mov"
```

Record the main display:

```bash
screen-record --display --duration 5 --audio off --path "$CODEX_HOME/out/screen-record/display-5s.mov"
```

Record by app name (system audio):

```bash
screen-record --app Terminal --duration 3 --audio system --path "$CODEX_HOME/out/screen-record/terminal-3s.mov"
```

Record with metadata + diagnostics artifacts:

```bash
screen-record --app Terminal --duration 3 --audio off --path "$CODEX_HOME/out/screen-record/terminal-3s.mov" \
  --metadata-out "$CODEX_HOME/out/screen-record/terminal-3s.metadata.json" \
  --diagnostics-out "$CODEX_HOME/out/screen-record/terminal-3s.diagnostics.json"
```

If `--app` is ambiguous, pick an id and retry:

```bash
screen-record --window-id 4811 --duration 5 --audio off --path "$CODEX_HOME/out/screen-record/window-4811.mov"
```

Wayland-only Linux interactive capture:

```bash
screen-record --portal --duration 5 --audio off --path "$CODEX_HOME/out/screen-record/portal-5s.mov"
```

Screenshot active window:

```bash
screen-record --screenshot --active-window --path "$CODEX_HOME/out/screen-record/active.png"
```

Screenshot via app + window title:

```bash
screen-record --screenshot --app Terminal --window-name Inbox --path "$CODEX_HOME/out/screen-record/terminal-inbox.jpg"
```

Screenshot via portal picker (Wayland):

```bash
screen-record --screenshot --portal --path "$CODEX_HOME/out/screen-record/portal.png"
```

Skip screenshot publish when unchanged:

```bash
screen-record --screenshot --active-window --path "$CODEX_HOME/out/screen-record/active.png" \
  --if-changed --if-changed-threshold 2
```
