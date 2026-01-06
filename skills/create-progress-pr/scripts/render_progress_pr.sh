#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: render_progress_pr.sh [--pr|--progress-template|--glossary|--output] [--project]

--pr               Output the PR body template
--progress-template Output the progress file template (PROGRESS_TEMPLATE.md)
--glossary         Output the progress glossary (PROGRESS_GLOSSARY.md)
--output           Output the skill output template (chat response format)
--project          Use project templates from the current git repo instead of skill defaults

Notes:
  - When using --project, run inside the target git repo.
USAGE
}

mode=""
source="default"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --pr|--progress-template|--glossary|--output)
      if [[ -n "$mode" ]]; then
        echo "error: choose exactly one mode" >&2
        usage >&2
        exit 1
      fi
      mode="$1"
      shift
      ;;
    --project)
      source="project"
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

repo_root=""
if [[ "$source" == "project" ]]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: --project requires running inside a git work tree" >&2
    exit 1
  }
  repo_root="$(git rev-parse --show-toplevel)"
fi

render_project_pr_template() {
  local candidate=""

  if [[ -f "${repo_root}/.github/pull_request_template.md" ]]; then
    candidate="${repo_root}/.github/pull_request_template.md"
  elif [[ -f "${repo_root}/.github/PULL_REQUEST_TEMPLATE.md" ]]; then
    candidate="${repo_root}/.github/PULL_REQUEST_TEMPLATE.md"
  elif [[ -d "${repo_root}/.github/PULL_REQUEST_TEMPLATE" ]]; then
    local files
    files="$(ls -1 "${repo_root}/.github/PULL_REQUEST_TEMPLATE"/*.md 2>/dev/null || true)"
    if [[ -z "$files" ]]; then
      echo "error: no .md templates under .github/PULL_REQUEST_TEMPLATE/" >&2
      exit 1
    fi
    local count
    count="$(echo "$files" | wc -l | tr -d ' ')"
    if [[ "$count" != "1" ]]; then
      echo "error: multiple templates found under .github/PULL_REQUEST_TEMPLATE/; pick one explicitly:" >&2
      echo "$files" >&2
      exit 1
    fi
    candidate="$(echo "$files" | head -n 1)"
  fi

  if [[ -z "$candidate" ]]; then
    echo "error: cannot find a project PR template under .github/ (expected pull_request_template.md or PULL_REQUEST_TEMPLATE*.md)" >&2
    exit 1
  fi

  cat "$candidate"
}

case "$mode" in
  --pr)
    if [[ "$source" == "project" ]]; then
      render_project_pr_template
    else
      cat "${skill_dir}/references/PR_TEMPLATE.md"
    fi
    ;;
  --progress-template)
    if [[ "$source" == "project" ]]; then
      cat "${repo_root}/docs/templates/PROGRESS_TEMPLATE.md"
    else
      cat "${skill_dir}/references/PROGRESS_TEMPLATE.md"
    fi
    ;;
  --glossary)
    if [[ "$source" == "project" ]]; then
      cat "${repo_root}/docs/templates/PROGRESS_GLOSSARY.md"
    else
      cat "${skill_dir}/references/PROGRESS_GLOSSARY.md"
    fi
    ;;
  --output)
    cat "${skill_dir}/references/OUTPUT_TEMPLATE.md"
    ;;
  *)
    echo "error: unknown mode: $mode" >&2
    exit 1
    ;;
esac
