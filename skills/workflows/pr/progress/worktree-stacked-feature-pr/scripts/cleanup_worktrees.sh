#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  cleanup_worktrees.sh --prefix <string> [--dry-run] [--yes]

Removes git worktrees whose path contains the given prefix substring, then runs:
  git worktree prune

Example:
  cleanup_worktrees.sh --prefix ".worktrees/TunGroup/feat__notifications-"

Safety:
  - This is a blunt tool. Prefer `git worktree remove <path>` for single removals.
  - By default this script runs in dry-run mode; pass --yes to actually remove worktrees.
USAGE
}

prefix=""
dry_run="1"
yes="0"
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run="1"
      shift
      ;;
    --yes)
      yes="1"
      dry_run="0"
      shift
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
paths=()
while IFS= read -r line; do
  [[ "$line" == worktree\ * ]] || continue
  worktree_path="${line#worktree }"
  [[ -n "$worktree_path" ]] || continue
  paths+=("$worktree_path")
done < <(git worktree list --porcelain)

matches=0
removed=0
for path in "${paths[@]}"; do
  if [[ "$path" == *"$prefix"* ]]; then
    matches=$((matches + 1))
    if [[ "$dry_run" == "1" ]]; then
      echo "(dry-run) Would remove worktree: $path"
      continue
    fi
    echo "Removing worktree: $path"
    git worktree remove "$path"
    removed=$((removed + 1))
  fi
done

if [[ "$dry_run" == "1" ]]; then
  echo "Dry run complete. Matches: $matches"
  echo "hint: re-run with --yes to remove matching worktrees."
  exit 0
fi

git worktree prune
echo "Done. Removed: $removed (matches: $matches)"
