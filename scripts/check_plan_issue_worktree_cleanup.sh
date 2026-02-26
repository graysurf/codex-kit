#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/check_plan_issue_worktree_cleanup.sh [<runtime-root-or-worktrees-path>]

Checks for leftover issue worktree directories under:
  $AGENT_HOME/out/plan-issue-delivery/graysurf-agent-kit/issue-123/worktrees

Input handling:
  - If the input ends with /worktrees, it is used directly.
  - Otherwise, /worktrees is appended to the input path.
  - If omitted, the default path above is used.

Exit codes:
  0 = no leftovers detected
  1 = leftover worktree directories detected
  2 = invalid usage or invalid path type
USAGE
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  echo "error: expected at most one argument" >&2
  usage >&2
  exit 2
fi

default_worktrees_root="${AGENT_HOME:-$(pwd)}/out/plan-issue-delivery/graysurf-agent-kit/issue-123/worktrees"
input_root="${1:-$default_worktrees_root}"
worktrees_root="$input_root"
if [[ "$input_root" != */worktrees ]]; then
  worktrees_root="${input_root%/}/worktrees"
fi

if [[ ! -e "$worktrees_root" ]]; then
  echo "cleanup-check: pass (worktrees path not found): $worktrees_root"
  exit 0
fi

if [[ ! -d "$worktrees_root" ]]; then
  echo "error: path exists but is not a directory: $worktrees_root" >&2
  exit 2
fi

leftovers=()
while IFS= read -r leftover; do
  leftovers+=("$leftover")
done < <(find "$worktrees_root" -mindepth 2 -maxdepth 2 -type d | sort)

if [[ ${#leftovers[@]} -gt 0 ]]; then
  echo "cleanup-check: fail (leftover worktree directories detected)" >&2
  for leftover in "${leftovers[@]}"; do
    echo "  - $leftover" >&2
  done
  exit 1
fi

echo "cleanup-check: pass (no leftover worktree directories): $worktrees_root"

