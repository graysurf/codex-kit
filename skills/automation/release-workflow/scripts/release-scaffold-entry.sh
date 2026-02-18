#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-scaffold-entry: $1" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-scaffold-entry.sh --version <vX.Y.Z> [--repo <path>] [--date <YYYY-MM-DD>] [--template <path>] [--output <path>]

Template resolution:
  1) --template (when provided)
  2) <repo>/docs/templates/RELEASE_TEMPLATE.md (when present; repo defaults to .)
  3) bundled default template (this skill)

Output:
  - Writes to --output (default: stdout).
EOF
}

repo="."
version=""
date_str=""
template=""
output=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --date)
      date_str="${2:-}"
      shift 2
      ;;
    --template)
      template="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
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

[[ -n "$version" ]] || die "missing --version (expected vX.Y.Z)"
[[ -n "$repo" ]] || repo="."
[[ -d "$repo" ]] || die "repo not found: $repo"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_root="$(cd "${script_dir}/.." && pwd -P)"
default_template="${skill_root}/assets/templates/RELEASE_TEMPLATE.md"

[[ -f "$default_template" ]] || die "default template missing: $default_template"

if [[ -z "$date_str" ]]; then
  date_str="$(date +%Y-%m-%d 2>/dev/null || true)"
fi
[[ -n "$date_str" ]] || die "unable to determine --date"

if [[ -z "$template" ]]; then
  AGENT_HOME="${AGENT_HOME:-${AGENTS_HOME:-}}"
  if [[ -z "$AGENT_HOME" || ! -d "$AGENT_HOME" ]]; then
    AGENT_HOME="$(cd "${skill_root}/../../.." && pwd -P)"
  fi
  export AGENT_HOME
  export AGENTS_HOME="${AGENTS_HOME:-$AGENT_HOME}"
  project_resolve="${AGENT_HOME%/}/scripts/project-resolve"
  [[ -x "$project_resolve" ]] || die "missing executable: $project_resolve"

  template="$(
    "$project_resolve" \
      --repo "$repo" \
      --prefer "docs/templates/RELEASE_TEMPLATE.md" \
      --fallback "$default_template" \
      --format path
  )"
fi

[[ -n "$template" ]] || die "missing template (provide --template)"
[[ -f "$template" ]] || die "template not found: $template"

rendered="$(sed -e "s/vX\\.Y\\.Z/${version}/g" -e "s/YYYY-MM-DD/${date_str}/g" "$template")"

if [[ -n "$output" ]]; then
  mkdir -p -- "$(dirname "$output")"
  printf "%s\n" "$rendered" >"$output"
  echo "$output"
else
  printf "%s\n" "$rendered"
fi
