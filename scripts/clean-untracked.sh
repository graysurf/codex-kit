#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/clean-untracked.sh [--dry-run] [--apply] [--keep <pattern>...]

Clean untracked/ignored files in this git repo, with an exception list.

Modes:
  --dry-run  Preview only (default)
  --apply    Actually delete files

Options:
  --keep <pattern>  Add one more exception pattern (git clean -e syntax)
  -h, --help        Show help

Examples:
  scripts/clean-untracked.sh
  scripts/clean-untracked.sh --apply
  scripts/clean-untracked.sh --keep '.cache/'
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if ! command -v git >/dev/null 2>&1; then
  echo "error: git not found" >&2
  exit 1
fi
if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repository: $repo_root" >&2
  exit 1
fi

apply=0

# Edit this array for your always-kept files/folders.
exceptions=(
  ".venv/"
  "AGENTS*"
  "auth.json"
  "config.toml"
)

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --dry-run)
      apply=0
      shift
      ;;
    --apply)
      apply=1
      shift
      ;;
    --keep)
      if [[ $# -lt 2 ]]; then
        echo "error: --keep requires a pattern" >&2
        exit 2
      fi
      exceptions+=("${2}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mode_flag='-ndx'
mode_name='dry-run'
if [[ "$apply" -eq 1 ]]; then
  mode_flag='-fdx'
  mode_name='apply'
fi

echo "repo: $repo_root" >&2
echo "mode: $mode_name" >&2
echo "exceptions:" >&2
for pattern in "${exceptions[@]}"; do
  echo "  - $pattern" >&2
done

cmd=(git -C "$repo_root" clean "$mode_flag")
for pattern in "${exceptions[@]}"; do
  cmd+=(-e "$pattern")
done

"${cmd[@]}"

if [[ "$apply" -eq 0 ]]; then
  echo "" >&2
  echo "preview only. run with --apply to delete files." >&2
fi
