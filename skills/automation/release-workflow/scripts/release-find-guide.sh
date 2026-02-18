#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-find-guide: $1" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-find-guide.sh [--project-path <path>] [--search-root <path>] [--max-depth <n>]

Lookup order:
  1) When --project-path or $PROJECT_PATH is set:
     - <project>/docs/RELEASE_GUIDE.md
     - <project>/RELEASE_GUIDE.md
  2) Search for RELEASE_GUIDE.md under --search-root (default: pwd) with --max-depth (default: 3)

Exit:
  0 when a single guide is found (prints the path)
  1 when no guide is found
  2 on usage errors
  3 when multiple guides are found (prints all paths to stderr)
EOF
}

project_path="${PROJECT_PATH:-}"
search_root=""
max_depth="3"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --project-path)
      project_path="${2:-}"
      shift 2
      ;;
    --search-root)
      search_root="${2:-}"
      shift 2
      ;;
    --max-depth)
      max_depth="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: ${1:-}"
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_root="$(cd "${script_dir}/.." && pwd -P)"

AGENT_HOME="${AGENT_HOME:-${AGENTS_HOME:-}}"
if [[ -z "$AGENT_HOME" || ! -d "$AGENT_HOME" ]]; then
  AGENT_HOME="$(cd "${skill_root}/../../.." && pwd -P)"
fi
export AGENT_HOME
export AGENTS_HOME="${AGENTS_HOME:-$AGENT_HOME}"
project_resolve="${AGENT_HOME%/}/scripts/project-resolve"
[[ -x "$project_resolve" ]] || die "missing executable: $project_resolve"

if [[ -n "$project_path" ]]; then
  set +e
  project_match="$(
    "$project_resolve" \
      --repo "$project_path" \
      --prefer "docs/RELEASE_GUIDE.md" \
      --prefer "RELEASE_GUIDE.md" \
      --format path
  )"
  project_rc=$?
  set -e

  if [[ "$project_rc" -eq 0 ]]; then
    printf "%s\n" "$project_match"
    exit 0
  fi

  if [[ "$project_rc" -ne 1 ]]; then
    die "project-path lookup failed (exit=$project_rc)"
  fi
fi

if [[ -z "$search_root" ]]; then
  search_root="$(pwd -P)"
fi

if [[ ! -d "$search_root" ]]; then
  die "search root is not a directory: $search_root"
fi

if ! [[ "$max_depth" =~ ^[0-9]+$ ]]; then
  die "invalid --max-depth (expected integer): $max_depth"
fi

"$project_resolve" \
  --repo "$search_root" \
  --search-name "RELEASE_GUIDE.md" \
  --max-depth "$max_depth" \
  --format path
