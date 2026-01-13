#!/usr/bin/env -S zsh -f
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: staged_context.sh

Print staged change context for commit message generation.

Prefers:
  git-tools commit context --stdout --no-color

This script will attempt to load Codex git tools by sourcing:
  $CODEX_HOME/scripts/codex-tools.sh
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

load_codex_tools() {
  if [[ -z "${CODEX_HOME:-}" ]]; then
    local script_dir repo_root
    script_dir="${${(%):-%x}:A:h}"
    repo_root="$(cd "${script_dir}/../../.." && pwd -P)"
    export CODEX_HOME="$repo_root"
  fi

  local loader="${CODEX_HOME%/}/scripts/codex-tools.sh"
  if [[ ! -f "$loader" ]]; then
    echo "error: codex tools loader not found: $loader" >&2
    echo "hint: set CODEX_HOME to your codex-kit path (repo root) or reinstall codex-kit" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$loader"
}

load_codex_tools

if ! git-tools commit context --stdout --no-color; then
  echo "warning: git-tools commit context failed; printing fallback staged diff only" >&2
  command git diff --staged --no-color
fi
