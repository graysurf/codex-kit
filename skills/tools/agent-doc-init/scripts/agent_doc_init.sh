#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $CODEX_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh [options]

Options:
  --dry-run                          Preview actions only (default).
  --apply                            Apply changes to disk.
  --force                            Overwrite baseline docs (requires --apply).
  --target <all|home|project>        Baseline target scope (default: all).
  --project-path <path>              Explicit PROJECT_PATH for agent-docs.
  --codex-home <path>                Explicit CODEX_HOME for agent-docs.
  --project-required <context:path[:notes]>
                                     Upsert one required project extension entry.
                                     Repeatable.
  -h, --help                         Show this help.

Notes:
  - Default behavior is non-destructive dry-run.
  - Baseline scaffolding uses --missing-only unless --force is explicitly set.
USAGE
}

die_usage() {
  echo "error: $1" >&2
  usage >&2
  exit 2
}

die_runtime() {
  echo "error: $1" >&2
  exit 1
}

validate_context() {
  case "$1" in
    startup|task-tools|project-dev|skill-dev) return 0 ;;
    *) return 1 ;;
  esac
}

parse_project_required() {
  local raw="$1"
  local context rest path notes

  if [[ "$raw" != *:* ]]; then
    die_usage "--project-required must be <context:path[:notes]>: $raw"
  fi

  context="${raw%%:*}"
  rest="${raw#*:}"
  if [[ "$rest" == *:* ]]; then
    path="${rest%%:*}"
    notes="${rest#*:}"
  else
    path="$rest"
    notes=""
  fi

  if [[ -z "$context" || -z "$path" ]]; then
    die_usage "--project-required must include non-empty context and path: $raw"
  fi
  if ! validate_context "$context"; then
    die_usage "unsupported context in --project-required: $context"
  fi

  printf '%s\n%s\n%s\n' "$context" "$path" "$notes"
}

extract_baseline_counts() {
  python3 -c 'import json,sys; p=json.load(sys.stdin); print("{} {}".format(int(p.get("missing_required",0)), int(p.get("missing_optional",0))))'
}

run_baseline_json() {
  local target="$1"
  shift
  agent-docs baseline --check --target "$target" --format json "$@"
}

dry_run="true"
apply="false"
force="false"
target="all"
project_path=""
codex_home=""
declare -a project_required_entries=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --dry-run)
      dry_run="true"
      apply="false"
      shift
      ;;
    --apply)
      apply="true"
      dry_run="false"
      shift
      ;;
    --force)
      force="true"
      shift
      ;;
    --target)
      if [[ $# -lt 2 ]]; then
        die_usage "--target requires a value"
      fi
      case "${2:-}" in
        all|home|project) target="${2:-}" ;;
        *) die_usage "--target must be one of: all|home|project" ;;
      esac
      shift 2
      ;;
    --project-path)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        die_usage "--project-path requires a value"
      fi
      project_path="${2:-}"
      shift 2
      ;;
    --codex-home)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        die_usage "--codex-home requires a value"
      fi
      codex_home="${2:-}"
      shift 2
      ;;
    --project-required)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        die_usage "--project-required requires a value"
      fi
      project_required_entries+=("${2:-}")
      shift 2
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

if [[ "$force" == "true" && "$apply" != "true" ]]; then
  die_usage "--force requires --apply"
fi

if ! command -v agent-docs >/dev/null 2>&1; then
  die_runtime "agent-docs is required but not found on PATH"
fi
if ! command -v python3 >/dev/null 2>&1; then
  die_runtime "python3 is required but not found on PATH"
fi

declare -a common_args=()
if [[ -n "$project_path" ]]; then
  common_args+=(--project-path "$project_path")
fi
if [[ -n "$codex_home" ]]; then
  common_args+=(--codex-home "$codex_home")
fi

effective_codex_home="${codex_home:-${CODEX_HOME:-$HOME/.codex}}"
effective_project_path="${project_path:-${PROJECT_PATH:-$PWD}}"

before_json="$(run_baseline_json "$target" "${common_args[@]}")"
read -r missing_before missing_optional_before <<<"$(printf '%s' "$before_json" | extract_baseline_counts)"

scaffold_action="skipped"
scaffold_missing_only="true"
if [[ "$force" == "true" ]]; then
  scaffold_missing_only="false"
fi

if (( missing_before > 0 )) || [[ "$force" == "true" ]]; then
  declare -a scaffold_args=()
  scaffold_args+=(scaffold-baseline --target "$target" --format text)
  scaffold_args+=("${common_args[@]}")
  if [[ "$force" == "true" ]]; then
    scaffold_args+=(--force)
  else
    scaffold_args+=(--missing-only)
  fi
  if [[ "$dry_run" == "true" ]]; then
    scaffold_args+=(--dry-run)
    scaffold_action="planned"
  else
    scaffold_action="applied"
  fi
  agent-docs "${scaffold_args[@]}" >/dev/null
fi

project_entries_requested="${#project_required_entries[@]}"
project_entries_applied=0
if (( project_entries_requested > 0 )); then
  for raw in "${project_required_entries[@]}"; do
    context=""
    path=""
    notes=""
    {
      IFS= read -r context
      IFS= read -r path
      IFS= read -r notes
    } < <(parse_project_required "$raw")
    if [[ "$dry_run" == "true" ]]; then
      printf 'project_entry_plan context=%s path=%s required=true when=always\n' "$context" "$path"
      continue
    fi

    declare -a add_args=()
    add_args+=(add --target project --context "$context" --scope project --path "$path" --required --when always)
    add_args+=("${common_args[@]}")
    if [[ -n "$notes" ]]; then
      add_args+=(--notes "$notes")
    fi
    agent-docs "${add_args[@]}" >/dev/null
    project_entries_applied=$((project_entries_applied + 1))
  done
fi

after_json="$(run_baseline_json "$target" "${common_args[@]}")"
read -r missing_after missing_optional_after <<<"$(printf '%s' "$after_json" | extract_baseline_counts)"

changed="false"
if [[ "$apply" == "true" ]]; then
  if [[ "$scaffold_action" == "applied" || "$project_entries_applied" -gt 0 ]]; then
    changed="true"
  fi
fi

mode="dry-run"
if [[ "$apply" == "true" ]]; then
  mode="apply"
fi

printf 'agent_doc_init mode=%s target=%s force=%s\n' "$mode" "$target" "$force"
printf 'agent_doc_init codex_home=%s\n' "$effective_codex_home"
printf 'agent_doc_init project_path=%s\n' "$effective_project_path"
printf 'baseline_before missing_required=%s missing_optional=%s\n' "$missing_before" "$missing_optional_before"
printf 'scaffold_action=%s missing_only=%s\n' "$scaffold_action" "$scaffold_missing_only"
printf 'project_entries requested=%s applied=%s\n' "$project_entries_requested" "$project_entries_applied"
printf 'baseline_after missing_required=%s missing_optional=%s\n' "$missing_after" "$missing_optional_after"
printf 'result changed=%s dry_run=%s apply=%s force=%s\n' "$changed" "$dry_run" "$apply" "$force"
