#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-scaffold-entry: $1" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-scaffold-entry.sh --version <vX.Y.Z> [--date <YYYY-MM-DD>] [--template <path>] [--output <path>]

Template resolution:
  1) --template (when provided)
  2) ./docs/templates/RELEASE_TEMPLATE.md (when present)
  3) $CODEX_HOME/skills/automation/release-workflow/template/RELEASE_TEMPLATE.md

Output:
  - Writes to --output (default: stdout).
EOF
}

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

if [[ -z "$date_str" ]]; then
  date_str="$(date +%Y-%m-%d 2>/dev/null || true)"
fi
[[ -n "$date_str" ]] || die "unable to determine --date"

if [[ -z "$template" ]]; then
  if [[ -f "docs/templates/RELEASE_TEMPLATE.md" ]]; then
    template="docs/templates/RELEASE_TEMPLATE.md"
  elif [[ -n "${CODEX_HOME:-}" ]]; then
    template="${CODEX_HOME%/}/skills/automation/release-workflow/template/RELEASE_TEMPLATE.md"
  fi
fi

[[ -n "$template" ]] || die "missing template (provide --template or set CODEX_HOME)"
[[ -f "$template" ]] || die "template not found: $template"

rendered="$(sed -e "s/vX\\.Y\\.Z/${version}/g" -e "s/YYYY-MM-DD/${date_str}/g" "$template")"

if [[ -n "$output" ]]; then
  mkdir -p -- "$(dirname "$output")"
  printf "%s\n" "$rendered" >"$output"
  echo "$output"
else
  printf "%s\n" "$rendered"
fi

