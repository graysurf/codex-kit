#!/usr/bin/env -S zsh -f
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: staged_context.sh

Print staged change context for commit message generation.

Prefers:
  git-tools commit context --stdout --no-color

This script will attempt to load Codex git tools by sourcing:
  $CODEX_TOOLS_PATH/_codex-tools.zsh
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

codex_tools="$CODEX_TOOLS_PATH/_codex-tools.zsh"
if [[ -f "$codex_tools" ]]; then
  source "$codex_tools" >/dev/null 2>&1 || {
    echo "warning: failed to source ${codex_tools}; falling back to raw git diff output" >&2
  }
fi

if command -v git-tools >/dev/null 2>&1; then
  git-tools commit context --stdout --no-color
  exit 0
fi

echo "warning: git-tools not available; printing fallback staged diff only" >&2
command git diff --staged --no-color

