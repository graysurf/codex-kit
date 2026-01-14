#!/usr/bin/env -S zsh -f

# codex-tools loader (optional convenience)
#
# This is a convenience helper for interactive shells; skills should call
# `commands/*` directly and must not require sourcing this file.
#
# Usage:
#   source "$CODEX_HOME/scripts/codex-tools.sh"
#
# Contract:
# - Hard-fails with actionable errors when required tools are unavailable.
# - Sets/exports CODEX_HOME (if missing) and ensures repo-local tools are on PATH.

if [[ -n "${_codex_tools_loader_loaded-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
typeset -gr _codex_tools_loader_loaded=1

_codex_tools_die() {
  emulate -L zsh
  setopt err_return no_unset

  local message="${1-}"
  if [[ -z "$message" ]]; then
    message="unknown error"
  fi

  print -u2 -r -- "error: ${message}"
  return 1 2>/dev/null || exit 1
}

_codex_tools_note() {
  emulate -L zsh
  setopt err_return no_unset
  print -u2 -r -- "$*"
}

if [[ -z "${ZSH_VERSION:-}" ]]; then
  _codex_tools_die "must be sourced in zsh (try: zsh -lc 'source <path>/scripts/codex-tools.sh')"
fi

# Resolve CODEX_HOME from this file location if missing.
if [[ -z "${CODEX_HOME:-}" ]]; then
  export CODEX_HOME="${${(%):-%x}:A:h:h}"
fi

if [[ -z "${CODEX_HOME:-}" || ! -d "${CODEX_HOME:-}" ]]; then
  _codex_tools_die "CODEX_HOME is not set or invalid; set CODEX_HOME to your codex-kit path (e.g. export CODEX_HOME=\"$HOME/.config/codex-kit\")"
fi

export CODEX_HOME

typeset -g _codex_env_file="${CODEX_HOME%/}/scripts/env.zsh"
if [[ -f "$_codex_env_file" ]]; then
  # shellcheck disable=SC1090
  source "$_codex_env_file" || _codex_tools_die "failed to source ${_codex_env_file}"
fi

if [[ -z "${CODEX_COMMANDS_PATH:-}" ]]; then
  export CODEX_COMMANDS_PATH="${CODEX_HOME%/}/commands"
fi

if [[ ! -d "${CODEX_COMMANDS_PATH:-}" ]]; then
  _codex_tools_die "commands dir not found: ${CODEX_COMMANDS_PATH:-<unset>} (set CODEX_COMMANDS_PATH or reinstall codex-kit)"
fi

if [[ ":${PATH}:" != *":${CODEX_COMMANDS_PATH}:"* ]]; then
  export PATH="${CODEX_COMMANDS_PATH}:${PATH}"
fi

for tool in git-tools git-scope; do
  if [[ ! -x "${CODEX_COMMANDS_PATH%/}/${tool}" ]]; then
    _codex_tools_die "required tool missing: ${tool} (expected: ${CODEX_COMMANDS_PATH%/}/${tool})"
  fi
done

if ! command -v git >/dev/null 2>&1; then
  _codex_tools_die "required tool missing: git"
fi
