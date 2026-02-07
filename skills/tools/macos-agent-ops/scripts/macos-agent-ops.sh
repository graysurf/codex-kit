#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  macos-agent-ops.sh where
  macos-agent-ops.sh doctor
  macos-agent-ops.sh app-check --app <name> [--wait-ms <ms>] [--timeout-ms <ms>] [--poll-ms <ms>]
  macos-agent-ops.sh scenario --file <scenario.json>
  macos-agent-ops.sh run -- <macos-agent args...>

Notes:
  - Requires Homebrew-installed macos-agent available on PATH.
  - Automatically switches input source to US/ABC before doctor/app-check/scenario/run.
  - Set MACOS_AGENT_OPS_SKIP_INPUT_SOURCE_SWITCH=1 to bypass the auto-switch.
USAGE
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: macos-agent-ops requires macOS" >&2
    exit 1
  fi
}

read_input_menu_desc() {
  osascript -e 'tell application "System Events" to tell process "TextInputMenuAgent" to get description of menu bar item 1 of menu bar 2' 2>/dev/null || true
}

read_current_layout_id() {
  defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID 2>/dev/null || true
}

is_us_abc_menu_desc() {
  local menu_desc="${1:-}"
  case "$menu_desc" in
    "ABC"|"US"|"U.S."|"U.S")
      return 0
      ;;
  esac
  return 1
}

ensure_us_abc_input_source() {
  local skip_switch="${MACOS_AGENT_OPS_SKIP_INPUT_SOURCE_SWITCH:-0}"
  if [[ "$skip_switch" == "1" ]]; then
    return 0
  fi

  local menu_desc=''
  local current_layout=''
  menu_desc="$(read_input_menu_desc)"
  current_layout="$(read_current_layout_id)"

  if is_us_abc_menu_desc "$menu_desc"; then
    return 0
  fi
  # If the input menu reports a non-US source, trust it and switch.
  if [[ -z "$menu_desc" ]] && [[ "$current_layout" == "com.apple.keylayout.ABC" || "$current_layout" == "com.apple.keylayout.US" ]]; then
    return 0
  fi

  if ! osascript <<'APPLESCRIPT' >/dev/null 2>&1
tell application "System Events"
  tell process "TextInputMenuAgent"
    if (count of menu bars) < 2 then error "TextInputMenuAgent menu bar 2 unavailable"
    click menu bar item 1 of menu bar 2
    delay 0.15
    try
      click menu item "ABC" of menu 1 of menu bar item 1 of menu bar 2
    on error
      click menu bar item 1 of menu bar 2
      error "menu item ABC not found"
    end try
  end tell
end tell
APPLESCRIPT
  then
    echo "error: failed to switch input source to US/ABC" >&2
    echo "hint: ensure Accessibility is granted and ABC input source is enabled." >&2
    echo "hint: set MACOS_AGENT_OPS_SKIP_INPUT_SOURCE_SWITCH=1 to bypass." >&2
    exit 1
  fi

  menu_desc="$(read_input_menu_desc)"
  current_layout="$(read_current_layout_id)"

  if is_us_abc_menu_desc "$menu_desc"; then
    return 0
  fi
  # Fallback only when menu probing is unavailable.
  if [[ -z "$menu_desc" ]] && [[ "$current_layout" == "com.apple.keylayout.ABC" || "$current_layout" == "com.apple.keylayout.US" ]]; then
    return 0
  fi

  echo "error: input source is not US/ABC after switch attempt" >&2
  echo "current: menu='$menu_desc' layout='$current_layout'" >&2
  echo "hint: switch to ABC manually from the input menu, then retry." >&2
  exit 1
}

resolve_bin() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "error: Homebrew is required to run macos-agent-ops" >&2
    echo "hint: install Homebrew, then run: brew install macos-agent" >&2
    exit 1
  fi

  local brew_prefix=''
  local brew_bin=''
  brew_bin="$(command -v macos-agent || true)"
  if [[ -z "$brew_bin" ]]; then
    echo "error: macos-agent not found on PATH" >&2
    echo "hint: install with Homebrew: brew install macos-agent" >&2
    exit 1
  fi

  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  if [[ -z "$brew_prefix" ]]; then
    echo "error: unable to determine Homebrew prefix" >&2
    exit 1
  fi

  if [[ "$brew_bin" != "$brew_prefix/bin/macos-agent" ]]; then
    echo "error: macos-agent must use Homebrew binary: $brew_prefix/bin/macos-agent" >&2
    echo "found: $brew_bin" >&2
    exit 1
  fi

  printf '%s\n' "$brew_bin"
}

run_doctor() {
  local bin
  bin="$(resolve_bin)"
  command -v cliclick >/dev/null 2>&1 || {
    echo "error: cliclick not found on PATH" >&2
    exit 1
  }
  "$bin" --format json preflight --include-probes
}

run_app_check() {
  local app=''
  local wait_ms="1800"
  local timeout_ms="12000"
  local poll_ms="60"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app)
        app="${2:-}"
        shift 2
        ;;
      --wait-ms)
        wait_ms="${2:-}"
        shift 2
        ;;
      --timeout-ms)
        timeout_ms="${2:-}"
        shift 2
        ;;
      --poll-ms)
        poll_ms="${2:-}"
        shift 2
        ;;
      *)
        echo "error: unknown argument for app-check: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$app" ]]; then
    echo "error: --app is required" >&2
    exit 2
  fi

  local bin
  bin="$(resolve_bin)"

  osascript -e "tell application \"$app\" to launch" >/dev/null
  "$bin" --format json --timeout-ms "$timeout_ms" window activate --app "$app" --wait-ms "$wait_ms"
  "$bin" --format json wait app-active --app "$app" --timeout-ms "$timeout_ms" --poll-ms "$poll_ms"
}

run_scenario() {
  local scenario_file=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        scenario_file="${2:-}"
        shift 2
        ;;
      *)
        echo "error: unknown argument for scenario: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$scenario_file" ]]; then
    echo "error: --file is required" >&2
    exit 2
  fi
  if [[ ! -f "$scenario_file" ]]; then
    echo "error: scenario file not found: $scenario_file" >&2
    exit 1
  fi

  local bin
  bin="$(resolve_bin)"
  "$bin" --format json scenario run --file "$scenario_file"
}

run_passthrough() {
  if [[ "$1" != "--" ]]; then
    echo "error: run requires '--' before macos-agent args" >&2
    exit 2
  fi
  shift
  if [[ $# -eq 0 ]]; then
    echo "error: run requires at least one macos-agent argument" >&2
    exit 2
  fi

  local bin
  bin="$(resolve_bin)"
  "$bin" "$@"
}

main() {
  require_macos

  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage >&2
    exit 2
  fi
  shift || true

  case "$cmd" in
    where)
      resolve_bin
      ;;
    doctor)
      ensure_us_abc_input_source
      run_doctor
      ;;
    app-check)
      ensure_us_abc_input_source
      run_app_check "$@"
      ;;
    scenario)
      ensure_us_abc_input_source
      run_scenario "$@"
      ;;
    run)
      ensure_us_abc_input_source
      run_passthrough "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "error: unknown command: $cmd" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
