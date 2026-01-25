#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scaffold_plan.sh --slug <kebab-case> [--title <title>] [--force]
  scaffold_plan.sh --file <path> [--title <title>] [--force]

Purpose:
  Create a new plan markdown file from the shared plan template.

Options:
  --slug <slug>   Base slug (kebab-case). Writes to docs/plans/<slug>-plan.md.
                 If <slug> already ends with "-plan", writes to docs/plans/<slug>.md.
  --file <path>   Explicit output path (must end with "-plan.md")
  --title <text>  Replace the plan title line ("# Plan: ...")
  --force         Overwrite if the output file already exists
  -h, --help      Show help

Exit:
  0: plan file created
  1: runtime error
  2: usage error
USAGE
}

die_usage() {
  echo "scaffold_plan: $1" >&2
  usage
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_root="$(cd "${script_dir}/.." && pwd -P)"
codex_home="${CODEX_HOME:-}"
if [[ -z "$codex_home" || ! -d "$codex_home" ]]; then
  codex_home="$(cd "${skill_root}/../../../.." && pwd -P)"
fi
export CODEX_HOME="$codex_home"
repo_root="$codex_home"
cd "$repo_root"

template_path="${repo_root}/skills/workflows/plan/_shared/assets/plan-template.md"
if [[ ! -f "$template_path" ]]; then
  echo "scaffold_plan: error: missing plan template: ${template_path}" >&2
  exit 1
fi

slug=""
out_file=""
title=""
force="0"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --slug)
      slug="${2:-}"
      [[ -n "$slug" ]] || die_usage "missing value for --slug"
      shift 2
      ;;
    --file)
      out_file="${2:-}"
      [[ -n "$out_file" ]] || die_usage "missing value for --file"
      shift 2
      ;;
    --title)
      title="${2:-}"
      [[ -n "$title" ]] || die_usage "missing value for --title"
      shift 2
      ;;
    --force)
      force="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown argument: ${1:-}"
      ;;
  esac
done

if [[ -n "$slug" && -n "$out_file" ]]; then
  die_usage "use either --slug or --file (not both)"
fi

if [[ -z "$slug" && -z "$out_file" ]]; then
  die_usage "missing required --slug or --file"
fi

if [[ -n "$slug" ]]; then
  if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*(-plan)?$ ]]; then
    die_usage "--slug must be kebab-case (lowercase letters, digits, hyphens)"
  fi

  if [[ "$slug" == *-plan ]]; then
    out_file="docs/plans/${slug}.md"
  else
    out_file="docs/plans/${slug}-plan.md"
  fi
fi

if [[ "$out_file" != /* ]]; then
  out_file="${repo_root}/${out_file}"
fi

if [[ "$out_file" != *-plan.md ]]; then
  die_usage "--file must end with -plan.md"
fi

if [[ -e "$out_file" && "$force" != "1" ]]; then
  echo "scaffold_plan: error: output already exists: ${out_file}" >&2
  exit 1
fi

mkdir -p "$(dirname "$out_file")"

if [[ -n "$title" ]]; then
  {
    IFS= read -r _first || true
    printf '# Plan: %s\n' "$title"
    cat
  } <"$template_path" >"$out_file"
else
  cp "$template_path" "$out_file"
fi

echo "created: ${out_file#"$repo_root"/}"
