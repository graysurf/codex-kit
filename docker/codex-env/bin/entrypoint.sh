#!/usr/bin/env bash
set -euo pipefail

codex_user="${CODEX_USER:-codex}"
agents_home="${AGENTS_HOME:-/home/${codex_user}/.agents}"
codex_src="${CODEX_KIT_DIR:-/opt/codex-kit}"

export CODEX_AUTH_FILE="${CODEX_AUTH_FILE:-${agents_home%/}/auth.json}"

if [[ ! -d "${codex_src%/}/skills" || ! -d "${codex_src%/}/scripts" ]]; then
  echo "error: CODEX_KIT_DIR not found or missing skills/scripts: $codex_src" >&2
  exit 1
fi

if [[ -d "${agents_home%/}/skills" && -d "${agents_home%/}/scripts" ]]; then
  exec "$@"
fi

if [[ -d "$agents_home" ]]; then
  if [[ -n "$(ls -A "$agents_home" 2>/dev/null)" ]]; then
    echo "warn: AGENTS_HOME is not empty but missing codex-kit; skipping seed" >&2
    exec "$@"
  fi
fi

if ! mkdir -p "$agents_home" 2>/dev/null; then
  if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p "$agents_home"
  else
    echo "error: unable to create AGENTS_HOME: $agents_home" >&2
    exit 1
  fi
fi

if id "$codex_user" >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$codex_user:$codex_user" "$agents_home"
  else
    chown -R "$codex_user:$codex_user" "$agents_home"
  fi
fi

cp -a "${codex_src%/}/." "$agents_home/"

exec "$@"
