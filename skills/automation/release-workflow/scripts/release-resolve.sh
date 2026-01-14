#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-resolve: $1" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-resolve.sh [--repo <path>] [--max-depth <n>] [--format json|env]

Purpose:
  Resolve the release guide and template to use for a target repo, deterministically.

Behavior:
  - Prefer repo-provided guide/template when present.
  - Otherwise fall back to the defaults bundled in this skill.

Exit:
  0: resolved successfully
  2: usage error
  3: multiple repo guides found (prints matches to stderr)
EOF
}

repo="${PROJECT_PATH:-.}"
max_depth="3"
format="json"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --max-depth)
      max_depth="${2:-}"
      shift 2
      ;;
    --format)
      format="${2:-}"
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

[[ -n "$repo" ]] || repo="."
[[ -d "$repo" ]] || die "repo not found: $repo"
repo_abs="$(cd "$repo" && pwd -P)"

if ! [[ "$max_depth" =~ ^[0-9]+$ ]]; then
  die "invalid --max-depth (expected integer): $max_depth"
fi

case "$format" in
  json|env) ;;
  *) die "invalid --format (expected json|env): $format" ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_root="$(cd "${script_dir}/.." && pwd -P)"

default_guide="${skill_root}/RELEASE_GUIDE.md"
default_template="${skill_root}/template/RELEASE_TEMPLATE.md"

[[ -f "$default_guide" ]] || die "default guide missing: $default_guide"
[[ -f "$default_template" ]] || die "default template missing: $default_template"

codex_home="${CODEX_HOME:-}"
if [[ -z "$codex_home" || ! -d "$codex_home" ]]; then
  codex_home="$(cd "${skill_root}/../../.." && pwd -P)"
fi
commands_dir="${CODEX_COMMANDS_PATH:-${codex_home%/}/commands}"
project_resolve="${commands_dir%/}/project-resolve"
[[ -x "$project_resolve" ]] || die "missing executable: $project_resolve"

set +e
guide_env="$(
  "$project_resolve" \
    --repo "$repo_abs" \
    --prefer "docs/RELEASE_GUIDE.md" \
    --prefer "RELEASE_GUIDE.md" \
    --search-name "RELEASE_GUIDE.md" \
    --max-depth "$max_depth" \
    --fallback "$default_guide" \
    --format env \
    --prefix "GUIDE_"
)"
guide_rc=$?
set -e

if [[ "$guide_rc" -eq 3 ]]; then
  exit 3
fi
if [[ "$guide_rc" -ne 0 ]]; then
  die "guide resolution failed (exit=$guide_rc)"
fi

eval "$guide_env"
guide_path="${GUIDE_PATH:-}"
guide_source="${GUIDE_SOURCE:-repo}"
[[ -n "$guide_path" ]] || die "guide resolution returned empty path"
[[ "$guide_source" == "fallback" ]] && guide_source="default"

set +e
template_env="$(
  "$project_resolve" \
    --repo "$repo_abs" \
    --prefer "docs/templates/RELEASE_TEMPLATE.md" \
    --fallback "$default_template" \
    --format env \
    --prefix "TEMPLATE_"
)"
template_rc=$?
set -e

if [[ "$template_rc" -eq 3 ]]; then
  exit 3
fi
if [[ "$template_rc" -ne 0 ]]; then
  die "template resolution failed (exit=$template_rc)"
fi

eval "$template_env"
template_path="${TEMPLATE_PATH:-}"
template_source="${TEMPLATE_SOURCE:-repo}"
[[ -n "$template_path" ]] || die "template resolution returned empty path"
[[ "$template_source" == "fallback" ]] && template_source="default"

if [[ "$format" == "env" ]]; then
  printf "REPO_PATH=%q\n" "$repo_abs"
  printf "RELEASE_GUIDE_PATH=%q\n" "$guide_path"
  printf "RELEASE_GUIDE_SOURCE=%q\n" "$guide_source"
  printf "RELEASE_TEMPLATE_PATH=%q\n" "$template_path"
  printf "RELEASE_TEMPLATE_SOURCE=%q\n" "$template_source"
  exit 0
fi

escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf "%s" "$s"
}

printf '{'
printf '"repo":"%s",' "$(escape_json "$repo_abs")"
printf '"guide":{"path":"%s","source":"%s"},' "$(escape_json "$guide_path")" "$(escape_json "$guide_source")"
printf '"template":{"path":"%s","source":"%s"}' "$(escape_json "$template_path")" "$(escape_json "$template_source")"
printf '}\n'
