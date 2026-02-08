#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  macos-agent-ops.sh where
  macos-agent-ops.sh doctor [--ax-app <name>|--ax-bundle-id <id>] [--ax-timeout-ms <ms>]
  macos-agent-ops.sh input-source [--id <source-id>]
  macos-agent-ops.sh app-check (--app <name>|--bundle-id <id>) [--wait-ms <ms>] [--timeout-ms <ms>] [--poll-ms <ms>]
  macos-agent-ops.sh ax-check [--app <name>|--bundle-id <id>] [--role <AXRole>] [--title-contains <text>] [--max-depth <n>] [--limit <n>] [--timeout-ms <ms>]
  macos-agent-ops.sh scenario --file <scenario.json>
  macos-agent-ops.sh run -- <macos-agent args...>

Notes:
  - Requires Homebrew-installed macos-agent available on PATH.
  - Automatically switches input source via `macos-agent input-source switch` before doctor/app-check/ax-check/scenario/run.
  - Auto-switch target priority: MACOS_AGENT_OPS_INPUT_SOURCE_ID > MACOS_AGENT_REAL_E2E_INPUT_SOURCE > abc.
  - Set MACOS_AGENT_OPS_SKIP_INPUT_SOURCE_SWITCH=1 to bypass the auto-switch.
USAGE
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: macos-agent-ops requires macOS" >&2
    exit 1
  fi
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

is_abc_input_source_id() {
  local normalized
  normalized="$(to_lower "${1:-}")"
  case "$normalized" in
    com.apple.keylayout.abc|com.apple.keylayout.us|abc|us|u.s.|english)
      return 0
      ;;
  esac
  return 1
}

extract_current_input_source_id() {
  local payload="${1:-}"
  printf '%s' "$payload" \
    | tr -d '\n' \
    | sed -n 's/.*"current":"\([^"]*\)".*/\1/p'
}

default_input_source_target() {
  local explicit="${MACOS_AGENT_OPS_INPUT_SOURCE_ID:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return
  fi

  local legacy="${MACOS_AGENT_REAL_E2E_INPUT_SOURCE:-}"
  if [[ -n "$legacy" ]]; then
    printf '%s\n' "$legacy"
    return
  fi

  printf '%s\n' "abc"
}

input_source_matches_target() {
  local current_id="${1:-}"
  local target_id="${2:-}"
  local normalized_target
  normalized_target="$(to_lower "$target_id")"

  case "$normalized_target" in
    abc|us|u.s.|english|com.apple.keylayout.abc|com.apple.keylayout.us)
      is_abc_input_source_id "$current_id"
      return
      ;;
  esac

  [[ "$(to_lower "$current_id")" == "$normalized_target" ]]
}

ensure_target_input_source() {
  local bin="$1"
  local override_target="${2:-}"
  local skip_switch="${MACOS_AGENT_OPS_SKIP_INPUT_SOURCE_SWITCH:-0}"
  if [[ "$skip_switch" == "1" ]]; then
    return 0
  fi

  local target
  if [[ -n "$override_target" ]]; then
    target="$override_target"
  else
    target="$(default_input_source_target)"
  fi

  local switch_output=''
  if ! switch_output="$("$bin" --format json input-source switch --id "$target" 2>&1)"; then
    echo "error: failed to switch input source via macos-agent" >&2
    echo "target: $target" >&2
    echo "$switch_output" >&2
    echo "hint: ensure `im-select` is installed: brew install im-select" >&2
    echo "hint: set MACOS_AGENT_OPS_SKIP_INPUT_SOURCE_SWITCH=1 to bypass." >&2
    exit 1
  fi

  local current_output=''
  if ! current_output="$("$bin" --format json input-source current 2>&1)"; then
    echo "error: failed to query current input source via macos-agent" >&2
    echo "$current_output" >&2
    exit 1
  fi

  local current_id=''
  current_id="$(extract_current_input_source_id "$current_output")"
  if [[ -z "$current_id" ]]; then
    echo "error: unable to parse input-source.current output" >&2
    echo "$current_output" >&2
    exit 1
  fi

  if ! input_source_matches_target "$current_id" "$target"; then
    echo "error: input source mismatch after switch attempt" >&2
    echo "target: $target" >&2
    echo "current: $current_id" >&2
    echo "hint: keep ABC/US enabled in macOS Input Sources for reliable typing." >&2
    exit 1
  fi
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
  local bin="$1"
  shift || true
  local ax_app='Finder'
  local ax_bundle_id=''
  local ax_timeout_ms='5000'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ax-app)
        ax_app="${2:-}"
        shift 2
        ;;
      --ax-bundle-id)
        ax_bundle_id="${2:-}"
        shift 2
        ;;
      --ax-timeout-ms)
        ax_timeout_ms="${2:-}"
        shift 2
        ;;
      *)
        echo "error: unknown argument for doctor: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -n "$ax_app" && -n "$ax_bundle_id" ]]; then
    echo "error: doctor accepts only one of --ax-app or --ax-bundle-id" >&2
    exit 2
  fi

  command -v cliclick >/dev/null 2>&1 || {
    echo "error: cliclick not found on PATH" >&2
    exit 1
  }
  command -v osascript >/dev/null 2>&1 || {
    echo "error: osascript not found on PATH" >&2
    exit 1
  }
  command -v im-select >/dev/null 2>&1 || {
    echo "error: im-select not found on PATH" >&2
    echo "hint: install with Homebrew: brew install im-select" >&2
    exit 1
  }

  "$bin" --format json preflight --include-probes

  local ax_target_args=()
  if [[ -n "$ax_bundle_id" ]]; then
    ax_target_args=(--bundle-id "$ax_bundle_id")
  else
    ax_target_args=(--app "$ax_app")
  fi

  "$bin" \
    --format json \
    --timeout-ms "$ax_timeout_ms" \
    ax list \
    "${ax_target_args[@]}" \
    --role AXWindow \
    --max-depth 2 \
    --limit 5
}

run_input_source() {
  local bin="$1"
  shift || true
  local source_id=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)
        source_id="${2:-}"
        shift 2
        ;;
      *)
        echo "error: unknown argument for input-source: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -n "$source_id" ]]; then
    ensure_target_input_source "$bin" "$source_id"
  else
    ensure_target_input_source "$bin"
  fi

  "$bin" --format json input-source current
}

run_app_check() {
  local bin="$1"
  shift || true
  local app=''
  local bundle_id=''
  local wait_ms="1800"
  local timeout_ms="12000"
  local poll_ms="60"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app)
        app="${2:-}"
        shift 2
        ;;
      --bundle-id)
        bundle_id="${2:-}"
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

  if [[ -n "$app" && -n "$bundle_id" ]]; then
    echo "error: app-check accepts only one of --app or --bundle-id" >&2
    exit 2
  fi
  if [[ -z "$app" && -z "$bundle_id" ]]; then
    echo "error: app-check requires --app or --bundle-id" >&2
    exit 2
  fi

  local selector_args=()
  if [[ -n "$bundle_id" ]]; then
    selector_args=(--bundle-id "$bundle_id")
    osascript -e "tell application id \"$bundle_id\" to launch" >/dev/null
  else
    selector_args=(--app "$app")
    osascript -e "tell application \"$app\" to launch" >/dev/null
  fi

  "$bin" --format json --timeout-ms "$timeout_ms" window activate "${selector_args[@]}" --wait-ms "$wait_ms" --reopen-on-fail
  "$bin" --format json wait app-active "${selector_args[@]}" --timeout-ms "$timeout_ms" --poll-ms "$poll_ms"
}

run_ax_check() {
  local bin="$1"
  shift || true
  local app='Finder'
  local bundle_id=''
  local role='AXWindow'
  local title_contains=''
  local max_depth='4'
  local limit='40'
  local timeout_ms='6000'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app)
        app="${2:-}"
        shift 2
        ;;
      --bundle-id)
        bundle_id="${2:-}"
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      --title-contains)
        title_contains="${2:-}"
        shift 2
        ;;
      --max-depth)
        max_depth="${2:-}"
        shift 2
        ;;
      --limit)
        limit="${2:-}"
        shift 2
        ;;
      --timeout-ms)
        timeout_ms="${2:-}"
        shift 2
        ;;
      *)
        echo "error: unknown argument for ax-check: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -n "$app" && -n "$bundle_id" ]]; then
    echo "error: ax-check accepts only one of --app or --bundle-id" >&2
    exit 2
  fi

  local target_args=()
  if [[ -n "$bundle_id" ]]; then
    target_args=(--bundle-id "$bundle_id")
  else
    target_args=(--app "$app")
  fi

  local args=(
    --format json
    --timeout-ms "$timeout_ms"
    ax list
    "${target_args[@]}"
    --role "$role"
    --max-depth "$max_depth"
    --limit "$limit"
  )
  if [[ -n "$title_contains" ]]; then
    args+=(--title-contains "$title_contains")
  fi

  "$bin" "${args[@]}"
}

run_scenario() {
  local bin="$1"
  shift || true
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

  "$bin" --format json scenario run --file "$scenario_file"
}

run_passthrough() {
  local bin="$1"
  shift || true
  if [[ "$1" != "--" ]]; then
    echo "error: run requires '--' before macos-agent args" >&2
    exit 2
  fi
  shift
  if [[ $# -eq 0 ]]; then
    echo "error: run requires at least one macos-agent argument" >&2
    exit 2
  fi

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
      local bin
      bin="$(resolve_bin)"
      ensure_target_input_source "$bin"
      run_doctor "$bin" "$@"
      ;;
    input-source)
      local bin
      bin="$(resolve_bin)"
      run_input_source "$bin" "$@"
      ;;
    app-check)
      local bin
      bin="$(resolve_bin)"
      ensure_target_input_source "$bin"
      run_app_check "$bin" "$@"
      ;;
    ax-check)
      local bin
      bin="$(resolve_bin)"
      ensure_target_input_source "$bin"
      run_ax_check "$bin" "$@"
      ;;
    scenario)
      local bin
      bin="$(resolve_bin)"
      ensure_target_input_source "$bin"
      run_scenario "$bin" "$@"
      ;;
    run)
      local bin
      bin="$(resolve_bin)"
      ensure_target_input_source "$bin"
      run_passthrough "$bin" "$@"
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
