#!/usr/bin/env -S zsh -f
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: staged_context.sh

Print staged change context for commit message generation.

Prefers:
  git-tools commit context --stdout --no-color
USAGE
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "error: unknown argument: $1" >&2
  usage >&2
  exit 1
fi

if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: must run inside a git work tree" >&2
  exit 1
fi

if command git diff --cached --quiet -- >/dev/null 2>&1; then
  echo "error: no staged changes (stage files with git add first)" >&2
  exit 2
fi

export GIT_PAGER=cat
export PAGER=cat

resolve_codex_command() {
  local name="${1:-}"
  [[ -n "$name" ]] || return 1

  if [[ -z "${CODEX_HOME:-}" ]]; then
    local script_dir repo_root
    script_dir="${${(%):-%x}:A:h}"
    repo_root="$(cd "${script_dir}/../../../../.." && pwd -P)"
    export CODEX_HOME="$repo_root"
  fi

  local commands_dir="${CODEX_COMMANDS_PATH:-${CODEX_HOME%/}/commands}"
  local candidate="${commands_dir%/}/${name}"
  [[ -x "$candidate" ]] || return 1

  print -r -- "$candidate"
}

git_tools="$(resolve_codex_command git-tools 2>/dev/null || true)"
if [[ -z "$git_tools" ]]; then
  echo "warning: git-tools not found; printing fallback staged diff only" >&2
  command git diff --staged --no-color
  exit 0
fi

if ! "$git_tools" commit context --stdout --no-color; then
  echo "warning: git-tools commit context failed; printing fallback staged diff only" >&2
  command git diff --staged --no-color
fi
