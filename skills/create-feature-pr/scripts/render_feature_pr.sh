#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: render_feature_pr.sh [--pr|--output]

--pr      Output the PR body template
--output  Output the skill output template
USAGE
}

case "${1:-}" in
  --pr)
    cat "${skill_dir}/references/PR_TEMPLATE.md"
    ;;
  --output)
    cat "${skill_dir}/references/OUTPUT_TEMPLATE.md"
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
