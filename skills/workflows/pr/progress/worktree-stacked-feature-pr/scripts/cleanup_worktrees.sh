#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  cleanup_worktrees.sh --prefix <string>

Removes git worktrees whose path contains the given prefix substring, then runs:
  git worktree prune

Example:
  cleanup_worktrees.sh --prefix ".worktrees/TunGroup/feat__notifications-"

Safety:
  - This is a blunt tool. Prefer `git worktree remove <path>` for single removals.
USAGE
}

prefix=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    -h|--help|"")
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${prefix}" ]]; then
  echo "error: --prefix is required" >&2
  usage >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required" >&2
  exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: must run inside a git work tree" >&2
  exit 1
}

echo "Scanning worktrees..."
mapfile -t paths < <(git worktree list --porcelain | awk '/^worktree /{print $2}')

for path in "${paths[@]}"; do
  if [[ "$path" == *"$prefix"* ]]; then
    echo "Removing worktree: $path"
    git worktree remove "$path"
  fi
done

git worktree prune
echo "Done."

