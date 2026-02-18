#!/usr/bin/env bash
set -euo pipefail

codex_user="${CODEX_USER:-$(id -un)}"
home_dir="${HOME:-/home/${codex_user}}"

expand_home_path() {
  local path="${1:-}"
  if [[ "$path" == "~" ]]; then
    printf '%s\n' "$home_dir"
    return 0
  fi
  if [[ "$path" == "~/"* ]]; then
    printf '%s/%s\n' "${home_dir%/}" "${path#~/}"
    return 0
  fi
  printf '%s\n' "$path"
}

AGENT_HOME="$(expand_home_path "${AGENT_HOME:-${home_dir%/}/.agents}")"
codex_src="$(expand_home_path "${AGENT_KIT_DIR:-${home_dir%/}/.agents}")"
CODEX_HOME="$(expand_home_path "${CODEX_HOME:-${home_dir%/}/.codex}")"

export CODEX_HOME
export CODEX_AUTH_FILE="${CODEX_AUTH_FILE:-${CODEX_HOME%/}/auth.json}"

if [[ ! -d "${codex_src%/}/skills" || ! -d "${codex_src%/}/scripts" ]]; then
  echo "error: AGENT_KIT_DIR not found or missing skills/scripts: $codex_src" >&2
  exit 1
fi

if [[ -d "${AGENT_HOME%/}/skills" && -d "${AGENT_HOME%/}/scripts" ]]; then
  exec "$@"
fi

if [[ -d "$AGENT_HOME" ]]; then
  if [[ -n "$(ls -A "$AGENT_HOME" 2>/dev/null)" ]]; then
    echo "warn: AGENT_HOME is not empty but missing agent-kit; skipping seed" >&2
    exec "$@"
  fi
fi

if ! mkdir -p "$AGENT_HOME" 2>/dev/null; then
  if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p "$AGENT_HOME"
  else
    echo "error: unable to create AGENT_HOME: $AGENT_HOME" >&2
    exit 1
  fi
fi

if id "$codex_user" >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$codex_user:$codex_user" "$AGENT_HOME"
  else
    chown -R "$codex_user:$codex_user" "$AGENT_HOME"
  fi
fi

cp -a "${codex_src%/}/." "$AGENT_HOME/"

exec "$@"
