#!/usr/bin/env bash
set -euo pipefail

codex_home="${CODEX_HOME:-/home/dev/.codex}"
codex_src="${CODEX_KIT_DIR:-/opt/codex-kit}"

if [[ ! -d "${codex_src%/}/commands" ]]; then
  echo "error: CODEX_KIT_DIR not found or missing commands: $codex_src" >&2
  exit 1
fi

if [[ -d "${codex_home%/}/commands" && -d "${codex_home%/}/skills" ]]; then
  exec "$@"
fi

if [[ -d "$codex_home" ]]; then
  if [[ -n "$(ls -A "$codex_home")" ]]; then
    echo "warn: CODEX_HOME is not empty but missing codex-kit; skipping seed" >&2
    exec "$@"
  fi
fi

mkdir -p "$codex_home"
cp -a "${codex_src%/}/." "$codex_home/"

if id dev >/dev/null 2>&1; then
  chown -R dev:dev "$codex_home"
fi

exec "$@"
