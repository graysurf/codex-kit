---
name: screen-record
description: Capture recordings or screenshots for a window/display via the screen-record CLI (macOS 12+ and Linux).
---

# Screen Record

Translate a user’s natural-language request into a safe invocation of the `screen-record` CLI.

## Contract

Prereqs:

- `screen-record` available on `PATH` (install via `brew install nils-cli`).
- macOS 12+ for native capture (ScreenCaptureKit + AVFoundation).
- Linux (X11/Xorg or XWayland) for deterministic selectors/listing; `ffmpeg` required on `PATH`.
- Linux Wayland-only sessions can use `--portal` (requires xdg-desktop-portal + backend + PipeWire).
- Screen Recording permission granted on macOS (use `screen-record --preflight` / `--request-permission`).

Inputs:

- Natural-language user intent (assistant translates into a command).
- Exactly one mode:
  - Discovery: `--list-windows`, `--list-apps`, or `--list-displays`, or
  - Permissions: `--preflight` or `--request-permission`, or
  - Screenshot mode: `--screenshot`, or
  - Recording mode (default when no other mode flag is present).
- Recording selectors (exactly one):
  - `--portal`, or
  - `--window-id <id>`, or
  - `--active-window`, or
  - `--app <name>` (optional `--window-name <name>` with `--app`), or
  - `--display`, or
  - `--display-id <id>`.
- Screenshot selectors (exactly one):
  - `--portal`, or
  - `--window-id <id>`, or
  - `--active-window`, or
  - `--app <name>` (optional `--window-name <name>` with `--app`).
- Recording args:
  - `--duration <seconds>` (required for recording)
  - `--path <file>` (required for recording)
  - optional: `--audio off|system|mic|both`, `--format mov|mp4`
  - optional diagnostics: `--metadata-out <path>`, `--diagnostics-out <path>`
- Screenshot args:
  - optional: `--path <file>` or `--dir <dir>`, `--image-format png|jpg|webp`
  - optional diff-aware publish: `--if-changed`, `--if-changed-baseline <path>`, `--if-changed-threshold <0..64>`

Outputs:

- Capture success (recording/screenshot): stdout prints only the resolved output file path (one line).
- List success: stdout prints only UTF-8 TSV rows (no header), one per line.
- Preflight/request success: stdout is empty; any user messaging goes to stderr.
- Errors: stdout is empty; stderr contains user-facing errors (no stack traces).

Exit codes:

- `0`: success
- `1`: runtime failure
- `2`: usage error (invalid flags/ambiguous selection/invalid format)

Failure modes:

- `screen-record` missing on `PATH`.
- Linux X11 selectors/list modes used without `DISPLAY` (Wayland-only session) and without `--portal`.
- Linux runtime missing required dependencies (for example: `ffmpeg`, portal backend, or `pactl` for audio capture).
- Screen Recording permission missing/denied.
- Ambiguous `--app` / `--window-name` selection (exit `2` with candidates on stderr).
- Invalid flag combinations (e.g., `--window-name` without `--app`, `--audio both` with `.mp4`,
  `--format`/`--image-format` conflicts with `--path` extension, `--portal` with non-`off` audio,
  display selectors in screenshot mode, or recording-only flags used with `--screenshot`).
- `--metadata-out` / `--diagnostics-out` used outside recording mode.
- `--if-changed-baseline` path does not exist.

## Guidance

### Preferences (optional; honor when provided)

- Selector: `--active-window` for “capture what I’m looking at”; otherwise prefer `--window-id` for deterministic selection.
- For desktop/non-window capture, prefer `--display` (or `--display-id` for deterministic target).
- Output path: prefer writing under `"$CODEX_HOME/out/screen-record/"` with a timestamped filename.
- Recording container: default `.mov`; use `.mp4` only when compatible with requested audio.
- Screenshot format: default `.png`; use `.jpg`/`.webp` only when explicitly requested.
- Audio: default `off`; use `system`/`mic`/`both` only when explicitly requested (recording only).
- Diagnostics files (`--metadata-out`, `--diagnostics-out`): only add when user asks for machine-readable artifacts.

### Policies (must-follow per request)

1) If underspecified: ask must-have questions first
   - Use: `skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`
   - Ask 1–5 “Need to know” questions with explicit defaults (mode, selector, duration for recording, audio, output path/format, portal usage on Wayland).
   - Do not run commands until the user answers or explicitly approves assumptions.

2) Single entrypoint (do not bypass)
   - Only run: `screen-record` (from `PATH`; install via `brew install nils-cli`).
   - Do not call other screen recording tools unless debugging `screen-record` itself.

3) Mode/flag gates (exactly one)
   - Exactly one mode: `--list-windows` / `--list-apps` / `--list-displays` / `--preflight` / `--request-permission` / `--screenshot` / recording.
   - Recording requires:
     - exactly one selector: `--portal` / `--window-id` / `--active-window` / `--app` / `--display` / `--display-id`
     - `--duration <seconds>` and `--path <file>`
   - Screenshot requires:
     - exactly one selector: `--portal` / `--window-id` / `--active-window` / `--app`
     - display selectors (`--display`, `--display-id`) are invalid
     - recording-only flags (`--duration`, `--audio`, `--format`, `--metadata-out`, `--diagnostics-out`) are invalid
   - `--metadata-out` / `--diagnostics-out` are valid only in recording mode.
   - `--if-changed`, `--if-changed-baseline`, `--if-changed-threshold` are valid only with `--screenshot`.
   - `--window-name` is only valid with `--app`.
   - `--portal` is interactive; in recording mode it currently supports `--audio off` only.
   - `--audio both` requires `.mov` (or `--format mov`).

4) Completion response (fixed)
   - After a successful run, respond using:
     - `skills/tools/media/screen-record/references/ASSISTANT_RESPONSE_TEMPLATE.md`
   - Include clickable output path(s) and a one-sentence “next prompt” that repeats the same capture task with concrete flags/paths.

## References

- Full guide: `skills/tools/media/screen-record/references/SCREEN_RECORD_GUIDE.md`
- Completion template: `skills/tools/media/screen-record/references/ASSISTANT_RESPONSE_TEMPLATE.md`
