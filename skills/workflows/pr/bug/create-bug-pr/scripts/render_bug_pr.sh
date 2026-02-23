#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${AGENT_HOME:-$(cd "${script_dir}/../../../../../.." && pwd)}"
shared_refs_dir="${repo_root}/skills/automation/find-and-fix-bugs/references"

usage() {
  cat <<'USAGE'
Usage: render_bug_pr.sh [--pr|--output]

--pr                 Output the PR body template
--output             Output the skill output template
USAGE
}

mode=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --pr|--output)
      if [[ -n "$mode" ]]; then
        echo "error: choose exactly one mode" >&2
        usage >&2
        exit 1
      fi
      mode="$1"
      shift
      ;;
    -h|--help)
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

if [[ -z "$mode" ]]; then
  usage >&2
  exit 1
fi

render_pr_template() {
  local template=''
  template="$(cat "${shared_refs_dir}/PR_TEMPLATE.md")"
  printf '%s\n' "${template//'{{OPTIONAL_SECTIONS}}'/}"
}

case "$mode" in
  --pr)
    render_pr_template
    ;;
  --output)
    cat "${shared_refs_dir}/ASSISTANT_RESPONSE_TEMPLATE.md"
    ;;
  *)
    echo "error: unknown mode: $mode" >&2
    exit 1
    ;;
esac
