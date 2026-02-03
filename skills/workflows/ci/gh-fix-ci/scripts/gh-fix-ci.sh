#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  gh-fix-ci.sh [--repo <path>] [--pr <number|url>] [--ref <branch|sha>] [--branch <name>] [--commit <sha>]
               [--limit <n>] [--max-lines <n>] [--context <n>] [--json]

Runs the bundled inspect_ci_checks.py to fetch failing PR or branch checks and log snippets.

Examples:
  gh-fix-ci.sh --pr 123
  gh-fix-ci.sh --repo . --pr https://github.com/org/repo/pull/123 --json
  gh-fix-ci.sh --ref main
  gh-fix-ci.sh --commit 1a2b3c4d

Notes:
  Requires gh authentication. Run `gh auth status` first.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$script_dir/inspect_ci_checks.py" "$@"
