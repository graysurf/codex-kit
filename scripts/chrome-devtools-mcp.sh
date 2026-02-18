#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# chrome-devtools-mcp launcher
#
# Supported modes (set CHROME_DEVTOOLS_MODE in .env):
#   - clean   : ephemeral profile (same as --isolated=true)
#   - profile : persistent profile (--user-data-dir)
#   - connect : attach to an existing Chrome/Arc (--autoConnect | --browser-url)
#
# Supported browser: chrome
# Or provide a full executable path via CHROME_DEVTOOLS_BROWSER
# ------------------------------------------------------------------------------

# Default app paths
CHROME_APP_PATH_DEFAULT="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Default remote debugging ports (connect mode)
CHROME_REMOTE_DEBUG_PORT_DEFAULT="${CHROME_REMOTE_DEBUG_PORT_DEFAULT:-19222}"

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
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
      echo "warning: ${name} must be true|false (got: ${raw}); treating as false" >&2
      return 1
      ;;
  esac
}

expand_tilde() {
  local path="$1"
  if [[ $path == \~ || $path == \~/* ]]; then
    path="${path/#\~/$HOME}"
  fi
  if [[ $path == '$HOME' || $path == '$HOME/'* ]]; then
    path="$HOME${path:5}"
  fi
  if [[ $path == '${HOME}' || $path == '${HOME}/'* ]]; then
    path="$HOME${path:7}"
  fi
  printf '%s' "$path"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
AGENT_HOME="${AGENT_HOME:-${AGENTS_HOME:-$REPO_ROOT}}"
AGENT_HOME="$(expand_tilde "$AGENT_HOME")"
export AGENT_HOME
export AGENTS_HOME="${AGENTS_HOME:-$AGENT_HOME}"

USER_DATA_DIR_BASE="$(expand_tilde "${CHROME_DEVTOOLS_USER_DATA_BASE:-$AGENT_HOME/.cache/chrome-devtools-mcp}")"

die() { echo "error: $*" >&2; exit 1; }

preflight_browser_url() {
  local browser_url="$1"
  bool_from_env "${CHROME_DEVTOOLS_PREFLIGHT_ENABLED:-}" "CHROME_DEVTOOLS_PREFLIGHT_ENABLED" "false" || return 0
  bool_from_env "${CHROME_DEVTOOLS_DRY_RUN_ENABLED:-}" "CHROME_DEVTOOLS_DRY_RUN_ENABLED" "false" && return 0

  local timeout_sec="${CHROME_DEVTOOLS_PREFLIGHT_TIMEOUT_SEC:-2}"
  local version_url="${browser_url%/}/json/version"
  echo "preflight: GET $version_url (timeout ${timeout_sec}s)" >&2
  curl -fsS --max-time "$timeout_sec" "$version_url" >/dev/null \
    || die "preflight failed: cannot reach Chrome DevTools at $version_url (set CHROME_DEVTOOLS_PREFLIGHT_ENABLED=false to skip)"
}

resolve_user_data_dir() {
  local dir="${CHROME_DEVTOOLS_USER_DATA_DIR:-}"
  local base="${CHROME_DEVTOOLS_USER_DATA_BASE:-$USER_DATA_DIR_BASE}"
  [[ -n "$dir" ]] || die "CHROME_DEVTOOLS_USER_DATA_DIR is required when CHROME_DEVTOOLS_MODE=profile"
  dir="$(expand_tilde "$dir")"
  base="$(expand_tilde "$base")"
  # Prepend base path when a relative name is provided
  if [[ "$dir" != /* ]]; then
    dir="$base/$dir"
  fi
  printf '%s' "$dir"
}

resolve_browser_url() {
  if [[ -n "${CHROME_DEVTOOLS_BROWSER_URL:-}" ]]; then
    printf '%s' "$CHROME_DEVTOOLS_BROWSER_URL"
    return 0
  fi

  local port="${CHROME_DEVTOOLS_BROWSER_PORT:-}"
  if [[ -z "$port" ]]; then
    port="${CHROME_DEVTOOLS_CHROME_PORT:-$CHROME_REMOTE_DEBUG_PORT_DEFAULT}"
  fi
  printf 'http://127.0.0.1:%s' "$port"
}

# 1) Load .env (default: $AGENT_HOME/.env) into environment
ENV_FILE="$(expand_tilde "${ENV_FILE:-$AGENT_HOME/.env}")"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# 2) Defaults
MODE="${CHROME_DEVTOOLS_MODE:-clean}"  # clean|profile|connect

# Log setup (default to $AGENT_HOME/out)
# IMPORTANT: Do not redirect stdout; MCP uses stdout for the protocol.
LOG_DIR="$(expand_tilde "${CHROME_DEVTOOLS_LOG_DIR:-$AGENT_HOME/out}")"
LOG_SUBDIR="${CHROME_DEVTOOLS_LOG_SUBDIR:-chrome-devtools-mcp}"
if [[ -n "${CHROME_DEVTOOLS_LOG_FILE:-}" ]]; then
  LOG_FILE="$(expand_tilde "$CHROME_DEVTOOLS_LOG_FILE")"
else
  LOG_FILE="$LOG_DIR/$LOG_SUBDIR/$(date +%Y%m%d-%H%M%S).log"
fi
mkdir -p "$(dirname "$LOG_FILE")"
exec 2>>"$LOG_FILE"

# 3) Resolve browser executable
if [[ -n "${CHROME_DEVTOOLS_BROWSER:-}" ]]; then
  BROWSER_EXE="$(expand_tilde "$CHROME_DEVTOOLS_BROWSER")"
else
  BROWSER_EXE="$CHROME_APP_PATH_DEFAULT"
fi

# 4) Build command args (use array to preserve spaces safely)
cmd=(npx -y chrome-devtools-mcp@latest)

case "$MODE" in
  clean)
    cmd+=(--executable-path "$BROWSER_EXE" --isolated=true)
    ;;

  profile)
    USER_DATA_DIR_RESOLVED="$(resolve_user_data_dir)"
    cmd+=(--executable-path "$BROWSER_EXE" --user-data-dir "$USER_DATA_DIR_RESOLVED")
    ;;

  connect)
    # connect mode usually targets the profile you are currently using
    # Prefer autoConnect when remote debugging is enabled on your browser
    if bool_from_env "${CHROME_DEVTOOLS_AUTOCONNECT_ENABLED:-}" "CHROME_DEVTOOLS_AUTOCONNECT_ENABLED" "false"; then
      cmd+=(--autoConnect=true)
    else
      # Otherwise connect to a manually exposed remote debugging port
      BROWSER_URL="$(resolve_browser_url)"
      preflight_browser_url "$BROWSER_URL"
      cmd+=(--browser-url "$BROWSER_URL")
    fi
    ;;
  *)
    die "unknown CHROME_DEVTOOLS_MODE: $MODE (use clean|profile|connect)"
    ;;
esac

# 5) Optional: pass Chrome flags via --chrome-arg
# Use semicolon-separated list, e.g. CHROME_DEVTOOLS_CHROME_ARGS="--lang=zh-TW;--disable-features=..."
if [[ -n "${CHROME_DEVTOOLS_CHROME_ARGS:-}" ]]; then
  IFS=';' read -r -a chrome_args <<< "${CHROME_DEVTOOLS_CHROME_ARGS}"
  for a in "${chrome_args[@]}"; do
    [[ -n "${a// }" ]] || continue
    cmd+=(--chrome-arg "$a")
  done
fi

# 6) Optional: extra raw args for mcp (semicolon-separated, no spaces inside each token)
# e.g. CHROME_DEVTOOLS_EXTRA_ARGS="--log-level=debug;--some-flag"
if [[ -n "${CHROME_DEVTOOLS_EXTRA_ARGS:-}" ]]; then
  IFS=';' read -r -a extra_args <<< "${CHROME_DEVTOOLS_EXTRA_ARGS}"
  for a in "${extra_args[@]}"; do
    [[ -n "${a// }" ]] || continue
    cmd+=("$a")
  done
fi

# 7) Debug / dry-run
if bool_from_env "${CHROME_DEVTOOLS_DRY_RUN_ENABLED:-}" "CHROME_DEVTOOLS_DRY_RUN_ENABLED" "false"; then
  printf '%q ' "${cmd[@]}"; echo
  exit 0
fi

echo "log: $LOG_FILE" >&2
echo "chrome-devtools-mcp command:" >&2
printf '%q ' "${cmd[@]}" >&2; echo >&2
echo "env: CHROME_DEVTOOLS_MODE=${CHROME_DEVTOOLS_MODE:-} CHROME_DEVTOOLS_USER_DATA_DIR=${CHROME_DEVTOOLS_USER_DATA_DIR:-}" >&2

exec "${cmd[@]}"
