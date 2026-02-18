#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  screenshot.sh [--desktop] [--help] [--] <args...>

Thin wrapper around the `screen-record` CLI.

Behavior:
  - If you pass a mode flag (`--list-windows`, `--list-apps`, `--list-displays`, `--preflight`,
    `--request-permission`), this script forwards args to `screen-record` as-is.
  - If you pass `--desktop`, this script captures the main display via `screencapture` (macOS only).
  - Otherwise, this script defaults to screenshot mode (adds `--screenshot`).

Options:
  --desktop      Capture the main display (desktop) and exit.
  --help         Show this help text.

Examples:
  screenshot.sh --desktop --path "$AGENT_HOME/out/desktop.png"
  screenshot.sh --list-windows
  screenshot.sh --list-displays
  screenshot.sh --active-window --path "$AGENT_HOME/out/screenshot.png"
  screenshot.sh --portal --path "$AGENT_HOME/out/screenshot-portal.png"
  screenshot.sh --app "Terminal" --window-name "Docs" --path "$AGENT_HOME/out/terminal-docs.png"

For full flags, run:
  screen-record --help
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

desktop_mode=0
args=()
for arg in "$@"; do
  if [[ "$arg" == "--desktop" ]]; then
    desktop_mode=1
    continue
  fi
  args+=("$arg")
done
agent_home="${AGENT_HOME:-${AGENTS_HOME:-}}"

if [[ "$desktop_mode" == "1" ]]; then
  os="$(uname -s 2>/dev/null || true)"
  if [[ "$os" != "Darwin" && -z "${AGENTS_SCREEN_RECORD_TEST_MODE:-}" ]]; then
    echo "error: --desktop is only supported on macOS (uses screencapture)" >&2
    echo "hint: on Linux/Wayland, use screen-record --screenshot --portal" >&2
    exit 2
  fi

  if ! command -v screencapture >/dev/null 2>&1; then
    echo "error: screencapture is required (built-in on macOS)" >&2
    exit 1
  fi

  path=""
  dir=""
  image_format="png"
  unsupported=()

  i=0
  while [[ $i -lt ${#args[@]} ]]; do
    a="${args[$i]}"
    case "$a" in
      -h|--help)
        usage
        exit 0
        ;;
      --path)
        i=$((i + 1))
        if [[ $i -ge ${#args[@]} ]]; then
          echo "error: --path requires a value" >&2
          exit 2
        fi
        path="${args[$i]}"
        ;;
      --path=*)
        path="${a#--path=}"
        ;;
      --dir)
        i=$((i + 1))
        if [[ $i -ge ${#args[@]} ]]; then
          echo "error: --dir requires a value" >&2
          exit 2
        fi
        dir="${args[$i]}"
        ;;
      --dir=*)
        dir="${a#--dir=}"
        ;;
      --image-format)
        i=$((i + 1))
        if [[ $i -ge ${#args[@]} ]]; then
          echo "error: --image-format requires a value" >&2
          exit 2
        fi
        image_format="${args[$i]}"
        ;;
      --image-format=*)
        image_format="${a#--image-format=}"
        ;;
      *)
        unsupported+=("$a")
        ;;
    esac
    i=$((i + 1))
  done

  if [[ ${#unsupported[@]} -gt 0 ]]; then
    echo "error: unsupported args for --desktop: ${unsupported[*]}" >&2
    echo "hint: allowed: --path, --dir, --image-format" >&2
    exit 2
  fi

  image_format_lower="$(printf '%s' "$image_format" | tr '[:upper:]' '[:lower:]')"
  case "$image_format_lower" in
    png)
      sc_format="png"
      ext="png"
      ;;
    jpg|jpeg)
      sc_format="jpg"
      ext="jpg"
      ;;
    *)
      echo "error: --desktop only supports --image-format png|jpg" >&2
      exit 2
      ;;
  esac

  ts="$(date +%Y-%m-%d_%H-%M-%S)"
  if [[ -n "$path" && -d "$path" ]]; then
    dir="$path"
    path=""
  fi
  if [[ -z "$path" ]]; then
    if [[ -z "$dir" && -n "$agent_home" && -d "$agent_home" ]]; then
      dir="${agent_home}/out/screenshot"
    fi
    if [[ -z "$dir" ]]; then
      dir="."
    fi
    path="${dir%/}/desktop-${ts}.${ext}"
  fi

  case "$path" in
    *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP)
      base="${path%.*}"
      path="${base}.${ext}"
      ;;
    *)
      if [[ "$path" != *.* ]]; then
        path="${path}.${ext}"
      fi
      ;;
  esac

  mkdir -p "$(dirname "$path")" 2>/dev/null || true
  screencapture -x -m "-t${sc_format}" "$path"
  echo "$path"
  exit 0
fi

if ! command -v screen-record >/dev/null 2>&1; then
  cat <<'MSG' >&2
error: screen-record is required

Install:
  brew install nils-cli
MSG
  exit 1
fi

pass_through=0
for arg in "${args[@]}"; do
  case "$arg" in
    --list-windows|--list-apps|--list-displays|--preflight|--request-permission|-V|--version)
      pass_through=1
      break
      ;;
  esac
done

if [[ "$pass_through" == "1" ]]; then
  exec screen-record "${args[@]}"
fi

has_screenshot=0
has_selector=0
has_output=0
for arg in "${args[@]}"; do
  case "$arg" in
    --screenshot)
      has_screenshot=1
      ;;
    --window-id|--window-id=*|--app|--app=*|--active-window|--portal)
      has_selector=1
      ;;
    --path|--path=*|--dir|--dir=*)
      has_output=1
      ;;
  esac
done

final_args=()
if [[ "$has_screenshot" == "0" ]]; then
  final_args+=(--screenshot)
fi

if [[ "$has_selector" == "0" ]]; then
  final_args+=(--active-window)
fi

if [[ "$has_output" == "0" && -n "$agent_home" && -d "$agent_home" ]]; then
  out_dir="${agent_home}/out/screenshot"
  mkdir -p "$out_dir" 2>/dev/null || true
  final_args+=(--dir "$out_dir")
fi

final_args+=("${args[@]}")

exec screen-record "${final_args[@]}"
