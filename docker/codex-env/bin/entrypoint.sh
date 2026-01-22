#!/usr/bin/env bash
set -euo pipefail

codex_user="${CODEX_USER:-codex}"
codex_home="${CODEX_HOME:-/home/${codex_user}/.codex}"
codex_src="${CODEX_KIT_DIR:-/opt/codex-kit}"

export CODEX_AUTH_FILE="${CODEX_AUTH_FILE:-${codex_home%/}/auth.json}"

if [[ ! -d "${codex_src%/}/commands" ]]; then
  echo "error: CODEX_KIT_DIR not found or missing commands: $codex_src" >&2
  exit 1
fi

if [[ -d "${codex_home%/}/commands" && -d "${codex_home%/}/skills" ]]; then
  exec "$@"
fi

if [[ -d "$codex_home" ]]; then
  if [[ -n "$(ls -A "$codex_home" 2>/dev/null)" ]]; then
    echo "warn: CODEX_HOME is not empty but missing codex-kit; skipping seed" >&2
    exec "$@"
  fi
fi

if ! mkdir -p "$codex_home" 2>/dev/null; then
  if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p "$codex_home"
  else
    echo "error: unable to create CODEX_HOME: $codex_home" >&2
    exit 1
  fi
fi

if id "$codex_user" >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$codex_user:$codex_user" "$codex_home"
  else
    chown -R "$codex_user:$codex_user" "$codex_home"
  fi
fi

cp -a "${codex_src%/}/." "$codex_home/"

exec "$@"
