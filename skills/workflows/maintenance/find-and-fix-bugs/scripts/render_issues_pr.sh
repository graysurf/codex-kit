#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: render_issues_pr.sh [--issues|--pr]

--issues  Output the issues list template
--pr      Output the PR body template (includes issues table)
USAGE
}

case "${1:-}" in
  --issues)
    cat "${skill_dir}/references/ISSUES_TEMPLATE.md"
    ;;
  --pr)
    cat "${skill_dir}/references/PR_TEMPLATE.md"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown option: ${1}" >&2
    usage >&2
    exit 1
    ;;
esac
