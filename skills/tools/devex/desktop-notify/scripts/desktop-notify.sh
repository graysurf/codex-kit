#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "desktop-notify: $1" >&2
  exit 2
}

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$s"
}

to_lower() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

usage() {
  cat >&2 <<'EOF'
Usage:
  desktop-notify.sh --title <title> --message <message> [--level <info|success|warn|warning|error>]

Behavior:
  - macOS: uses terminal-notifier (if installed)
  - Linux: uses notify-send (libnotify) (if installed)
  - Missing backend: no-op (optional one-line install hint to stderr)

Environment:
  CODEX_DESKTOP_NOTIFY_ENABLED=false       Disable notifications (default: enabled)
  CODEX_DESKTOP_NOTIFY_HINTS_ENABLED=true  Print install hints when backend missing (default: disabled)

Install hints:
  - macOS: brew install terminal-notifier
  - Linux (Debian/Ubuntu): sudo apt-get install libnotify-bin
  - Linux (Fedora): sudo dnf install libnotify
EOF
}

normalize_level() {
  case "$1" in
    warning) printf "warn" ;;
    *) printf "%s" "$1" ;;
  esac
}

bool_from_env() {
  local raw="${1:-}"
  local name="${2:-}"
  local default="${3:-false}"

  raw="$(trim "$raw")"
  if [[ -z "$raw" ]]; then
    [[ "$default" == "true" ]]
    return $?
  fi

  local lowered
  lowered="$(to_lower "$raw")"
  case "$lowered" in
    true) return 0 ;;
    false) return 1 ;;
    *)
      echo "desktop-notify: warning: ${name} must be true|false (got: ${raw}); treating as false" >&2
      return 1
      ;;
  esac
}

notifications_enabled() {
  bool_from_env "${CODEX_DESKTOP_NOTIFY_ENABLED:-}" "CODEX_DESKTOP_NOTIFY_ENABLED" "true"
}

hints_enabled() {
  bool_from_env "${CODEX_DESKTOP_NOTIFY_HINTS_ENABLED:-}" "CODEX_DESKTOP_NOTIFY_HINTS_ENABLED" "false"
}

title=""
message=""
level="info"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --title)
      title="${2:-}"
      [[ -n "$title" ]] || die "Missing value for --title"
      shift 2
      ;;
    --message)
      message="${2:-}"
      [[ -n "$message" ]] || die "Missing value for --message"
      shift 2
      ;;
    --level)
      level="$(normalize_level "$(to_lower "$(trim "${2:-}")")")"
      [[ -n "$level" ]] || die "Missing value for --level"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: ${1}"
      ;;
  esac
done

[[ -n "$title" ]] || die "Missing --title"
[[ -n "$message" ]] || die "Missing --message"

case "$level" in
  info|success|warn|error)
    ;;
  *)
    die "Invalid --level: $level (expected info|success|warn|warning|error)"
    ;;
esac

if ! notifications_enabled; then
  exit 0
fi

os="$(uname -s 2>/dev/null || true)"

if [[ "$os" == "Darwin" ]]; then
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$title" -message "$message" >/dev/null 2>&1 || true
    exit 0
  fi

  if hints_enabled; then
    echo "desktop-notify: terminal-notifier not found (install: brew install terminal-notifier)" >&2
  fi
  exit 0
fi

if [[ "$os" == "Linux" ]]; then
  if command -v notify-send >/dev/null 2>&1; then
    urgency="normal"
    case "$level" in
      error)
        urgency="critical"
        ;;
      warn)
        urgency="normal"
        ;;
    esac

    notify-send -u "$urgency" "$title" "$message" >/dev/null 2>&1 || true
    exit 0
  fi

  if hints_enabled; then
    echo "desktop-notify: notify-send not found (install: libnotify; e.g. apt-get install libnotify-bin)" >&2
  fi
  exit 0
fi

exit 0
