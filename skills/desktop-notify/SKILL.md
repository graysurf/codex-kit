---
name: desktop-notify
description: Send desktop notifications (macOS/Linux) with a project-title wrapper.
---

# Desktop Notify

## Contract

Prereqs:

- `bash` available on `PATH`.
- Notification backend:
  - macOS: `terminal-notifier`
  - Linux: `notify-send`

Inputs:

- Message string (required) and `--level info|success|warn|error`.
- Optional env: `CODEX_DESKTOP_NOTIFY=0` to disable; `PROJECT_PATH` for project title derivation.

Outputs:

- A desktop notification (best-effort); silent no-op when disabled or backend missing.

Exit codes:

- `0`: success or no-op
- non-zero: invalid usage or unexpected script/runtime failure

Failure modes:

- Backend not installed (script no-ops by default).
- Notifications disabled via `CODEX_DESKTOP_NOTIFY=0`.

Use this skill when you need to surface a short status update to the user via a desktop notification.

Prefer using the project wrapper (auto title) to avoid repeating title rules:

```bash
$CODEX_HOME/skills/desktop-notify/scripts/project-notify.sh "your short message" --level success
```

If you need a custom title, call the notifier directly:

```bash
$CODEX_HOME/skills/desktop-notify/scripts/desktop-notify.sh \
  --title "custom title" \
  --message "your short message" \
  --level info
```

## Behavior

- macOS: uses `terminal-notifier` when installed.
- Linux: uses `notify-send` (libnotify) when installed.
- Missing backend: silent no-op by default.

## Environment

- `CODEX_DESKTOP_NOTIFY=0`: disable notifications (default: enabled)
- `CODEX_DESKTOP_NOTIFY_HINTS=1`: print a one-line install hint when backend is missing (default: disabled)
- `PROJECT_PATH`: used by `skills/desktop-notify/scripts/project-notify.sh` to derive the project title (fallback: git root, then `$PWD`)

## Install hints

- macOS: `brew install terminal-notifier`
- Linux (Debian/Ubuntu): `sudo apt-get install libnotify-bin`
- Linux (Fedora): `sudo dnf install libnotify`
