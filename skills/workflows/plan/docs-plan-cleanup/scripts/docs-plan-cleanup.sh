#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  docs-plan-cleanup.sh [options]

Options:
  --project-path <path>       Target project path (default: $PROJECT_PATH when set, otherwise current directory)
  --keep-plan <path|name>     Preserve a plan/source doc or nested plan folder (repeatable)
  --keep-plans-file <path>    File with keep-plan entries (one per line, '#' comments allowed)
  --execute                   Apply deletions (default: dry-run)
  --delete-important          Also delete stale docs/specs/** and docs/runbooks/**
  --delete-empty-dirs         Remove empty directories under docs/ after deletion
  -h, --help                  Show this help

Behavior:
  1) Targets all markdown files under docs/plans/**.
  2) Deletes all plans/source docs except those explicitly preserved.
     When a kept file is inside docs/plans/<slug>/, preserve that whole bundle.
  3) Finds related docs under docs/**/*.md (excluding docs/plans/**):
     - auto-delete if they only reference removed plans,
     - keep them when they are referenced by other non-plan markdown files,
     - mark docs/specs/** and docs/runbooks/** as "important to rehome".
  4) Reports markdown files outside docs/ that still reference removed plans.
  5) Emits a stable report template with sections:
     - [plan_md_to_clean]
     - [plan_related_md_to_clean]
     - [plan_related_md_kept_referenced_elsewhere]

Exit codes:
  0  success
  1  runtime failure
  2  usage error / invalid keep-plan input
USAGE
}

usage_error() {
  echo "error: $*" >&2
  usage >&2
  exit 2
}

die() {
  echo "error: $*" >&2
  exit 1
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

normalize_relpath() {
  local p="$1"
  while [[ "$p" == ./* ]]; do
    p="${p#./}"
  done
  p="${p%/}"
  printf '%s' "$p"
}

trim_spaces() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_important_doc() {
  local rel="$1"
  [[ "$rel" == docs/specs/* || "$rel" == docs/runbooks/* ]]
}

is_retained_heuristic_record() {
  local rel="$1"
  [[ "$rel" == docs/runbooks/heuristic-system/error-inbox/* || "$rel" == docs/runbooks/heuristic-system/operation-records/* ]]
}

extract_plan_refs() {
  local abs_file="$1"
  rg -o -N "docs/plans/[A-Za-z0-9._/-]+\\.md" "$abs_file" 2>/dev/null | LC_ALL=C sort -u || true
}

list_markdown_referrers() {
  local target_rel="$1"
  rg -l -N -F --glob '*.md' --glob '!docs/plans/**' "$target_rel" . 2>/dev/null \
    | sed 's#^\./##' \
    | awk -v self="$target_rel" '$0 != self' \
    | LC_ALL=C sort -u || true
}

join_with() {
  local delimiter="$1"
  shift
  local out=''
  local item
  for item in "$@"; do
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="${out}${delimiter}${item}"
    fi
  done
  printf '%s' "$out"
}

resolve_keep_entry() {
  local raw="$1"
  local normalized candidate plan base stem plan_dir plan_name
  local -a matches
  matches=()

  if [[ -z "$raw" ]]; then
    echo "error: keep-plan entry cannot be empty" >&2
    return 1
  fi

  if [[ "$raw" == /* ]]; then
    case "$raw" in
      "$repo_root"/*)
        normalized="${raw#"$repo_root"/}"
        ;;
      *)
        echo "error: keep-plan is outside repo root: $raw" >&2
        return 1
        ;;
    esac
  else
    normalized="$raw"
  fi

  normalized="$(normalize_relpath "$normalized")"
  if array_contains "$normalized" "${plan_files[@]}"; then
    printf '%s\n' "$normalized"
    return 0
  fi

  candidate="$normalized"
  if [[ "$candidate" != docs/plans/* ]]; then
    candidate="docs/plans/$candidate"
  fi
  candidate="$(normalize_relpath "$candidate")"

  if array_contains "$candidate" "${plan_files[@]}"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ "$candidate" != *.md ]] && array_contains "${candidate}.md" "${plan_files[@]}"; then
    printf '%s\n' "${candidate}.md"
    return 0
  fi

  if [[ "$normalized" != docs/plans/* && "$normalized" != */* ]]; then
    if array_contains "docs/plans/${normalized}/${normalized}-plan.md" "${plan_files[@]}"; then
      printf '%s\n' "docs/plans/${normalized}/${normalized}-plan.md"
      return 0
    fi
    if [[ "$normalized" == *-plan ]] && [[ "$normalized" != *.md ]]; then
      plan_name="$normalized"
      plan_dir="${plan_name%-plan}"
      if array_contains "docs/plans/${plan_dir}/${plan_name}.md" "${plan_files[@]}"; then
        printf '%s\n' "docs/plans/${plan_dir}/${plan_name}.md"
        return 0
      fi
    fi
  fi

  for plan in "${plan_files[@]}"; do
    base="$(basename "$plan")"
    stem="${base%.md}"
    plan_dir="$(dirname "$plan")"
    if [[ "$normalized" == "$base" || "$normalized" == "$stem" || "$normalized" == "${plan_dir#docs/plans/}" || "$candidate" == "$base" || "$candidate" == "$stem" ]]; then
      matches+=( "$plan" )
    fi
  done

  if [[ ${#matches[@]} -eq 1 ]]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi
  if [[ ${#matches[@]} -gt 1 ]]; then
    echo "error: keep-plan is ambiguous: $raw" >&2
    echo "hint: use a repo-relative docs/plans path" >&2
    return 1
  fi

  echo "error: keep-plan not found: $raw" >&2
  return 1
}

bundle_dir_for_plan_file() {
  local rel="$1"
  local dir
  dir="$(dirname "$rel")"
  if [[ "$dir" == docs/plans/* && "$dir" != docs/plans ]]; then
    printf '%s\n' "$dir"
  fi
}

print_list() {
  local section="$1"
  shift
  local -a values
  values=( "$@" )
  local item

  echo "[$section]"
  echo "count: ${#values[@]}"
  if [[ ${#values[@]} -eq 0 ]]; then
    echo "- none"
    echo
    return
  fi

  for item in "${values[@]}"; do
    echo "- $item"
  done
  echo
}

print_retained_related() {
  local idx

  echo "[plan_related_md_kept_referenced_elsewhere]"
  echo "count: ${#retained_related[@]}"
  if [[ ${#retained_related[@]} -eq 0 ]]; then
    echo "- none"
    echo
    return
  fi

  for idx in "${!retained_related[@]}"; do
    echo "- ${retained_related[$idx]}"
    echo "  referenced_by: ${retained_related_referrers[$idx]}"
  done
  echo
}

resolve_input_path() {
  local candidate="$1"
  if [[ "$candidate" == /* ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if [[ -f "$repo_root/$candidate" ]]; then
    printf '%s\n' "$repo_root/$candidate"
    return 0
  fi
  printf '%s\n' "$candidate"
}

project_path_arg=''
project_path="."
project_path_source="cwd"
execute=0
delete_important=0
delete_empty_dirs=0
keep_plans_file=''
keep_entries=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --project-path)
      [[ $# -ge 2 ]] || usage_error "--project-path requires a value"
      project_path_arg="${2:-}"
      shift 2
      ;;
    --keep-plan)
      [[ $# -ge 2 ]] || usage_error "--keep-plan requires a value"
      keep_entries+=( "${2:-}" )
      shift 2
      ;;
    --keep-plans-file)
      [[ $# -ge 2 ]] || usage_error "--keep-plans-file requires a value"
      keep_plans_file="${2:-}"
      shift 2
      ;;
    --execute)
      execute=1
      shift
      ;;
    --delete-important)
      delete_important=1
      shift
      ;;
    --delete-empty-dirs)
      delete_empty_dirs=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage_error "unknown argument: ${1:-}"
      ;;
  esac
done

required_cmds=(git find rg sort rm sed awk date)
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    usage_error "missing required tool on PATH: $cmd"
  fi
done

if [[ -n "${PROJECT_PATH:-}" ]]; then
  project_path="$PROJECT_PATH"
  project_path_source="PROJECT_PATH"
fi
if [[ -n "$project_path_arg" ]]; then
  project_path="$project_path_arg"
  project_path_source="--project-path"
fi

[[ -d "$project_path" ]] || usage_error "project path not found: $project_path"

repo_root="$(cd "$project_path" && git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo_root" ]] || die "target is not inside a git work tree: $project_path"
cd "$repo_root"

[[ -d docs/plans ]] || die "missing docs/plans directory"

plan_files=()
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  plan_files+=( "$rel" )
done < <(find docs/plans -type f -name '*.md' -print | LC_ALL=C sort)

if [[ ${#plan_files[@]} -eq 0 ]]; then
  echo "ok: no markdown plan files found under docs/plans"
  exit 0
fi

if [[ -n "$keep_plans_file" ]]; then
  keep_file_abs="$(resolve_input_path "$keep_plans_file")"
  [[ -f "$keep_file_abs" ]] || usage_error "--keep-plans-file not found: $keep_plans_file"
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="$(trim_spaces "$line")"
    [[ -n "$line" ]] || continue
    keep_entries+=( "$line" )
  done < "$keep_file_abs"
fi

keep_plans=()
for keep_entry in "${keep_entries[@]}"; do
  resolved="$(resolve_keep_entry "$keep_entry")" || usage_error "invalid keep-plan entry: $keep_entry"
  if ! array_contains "$resolved" "${keep_plans[@]}"; then
    keep_plans+=( "$resolved" )
  fi
done

keep_bundle_dirs=()
for keep_plan in "${keep_plans[@]}"; do
  bundle_dir="$(bundle_dir_for_plan_file "$keep_plan")"
  if [[ -n "$bundle_dir" ]] && ! array_contains "$bundle_dir" "${keep_bundle_dirs[@]}"; then
    keep_bundle_dirs+=( "$bundle_dir" )
  fi
done

for plan in "${plan_files[@]}"; do
  plan_bundle_dir="$(bundle_dir_for_plan_file "$plan")"
  if [[ -z "$plan_bundle_dir" ]]; then
    continue
  fi
  if ! array_contains "$plan_bundle_dir" "${keep_bundle_dirs[@]}"; then
    continue
  fi
  if ! array_contains "$plan" "${keep_plans[@]}"; then
    keep_plans+=( "$plan" )
  fi
done

delete_plans=()
for plan in "${plan_files[@]}"; do
  if array_contains "$plan" "${keep_plans[@]}"; then
    continue
  fi
  delete_plans+=( "$plan" )
done

docs_files=()
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  docs_files+=( "$rel" )
done < <(find docs -type f -name '*.md' ! -path 'docs/plans/*' -print | LC_ALL=C sort)

candidate_related=()
candidate_related_type=()
review_related=()
delete_related=()
important_related=()
retained_related=()
retained_related_referrers=()

for rel in "${docs_files[@]}"; do
  abs="${repo_root}/${rel}"
  refs=()
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    refs+=( "$(normalize_relpath "$ref")" )
  done < <(extract_plan_refs "$abs")

  if [[ ${#refs[@]} -eq 0 ]]; then
    continue
  fi

  has_deleted_ref=0
  has_kept_ref=0
  for ref in "${refs[@]}"; do
    if array_contains "$ref" "${delete_plans[@]}"; then
      has_deleted_ref=1
    fi
    if array_contains "$ref" "${keep_plans[@]}"; then
      has_kept_ref=1
    fi
  done

  if [[ "$has_deleted_ref" -eq 0 ]]; then
    continue
  fi

  if [[ "$has_kept_ref" -eq 1 ]]; then
    review_related+=( "$rel" )
    continue
  fi

  if is_retained_heuristic_record "$rel"; then
    review_related+=( "$rel" )
    continue
  fi

  if is_important_doc "$rel"; then
    candidate_related+=( "$rel" )
    candidate_related_type+=( "important" )
  else
    candidate_related+=( "$rel" )
    candidate_related_type+=( "normal" )
  fi
done

for idx in "${!candidate_related[@]}"; do
  rel="${candidate_related[$idx]}"
  doc_type="${candidate_related_type[$idx]}"

  referrers=()
  while IFS= read -r referrer; do
    [[ -n "$referrer" ]] || continue
    referrers+=( "$referrer" )
  done < <(list_markdown_referrers "$rel")

  if [[ ${#referrers[@]} -gt 0 ]]; then
    retained_related+=( "$rel" )
    retained_related_referrers+=( "$(join_with ', ' "${referrers[@]}")" )
    continue
  fi

  if [[ "$doc_type" == "important" ]]; then
    important_related+=( "$rel" )
  else
    delete_related+=( "$rel" )
  fi
done

external_refs=()
all_markdown=()
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  all_markdown+=( "$rel" )
done < <(rg --files -g '*.md' . | sed 's#^\./##' | LC_ALL=C sort)

for rel in "${all_markdown[@]}"; do
  if [[ "$rel" == docs/plans/* ]]; then
    continue
  fi
  if array_contains "$rel" "${delete_related[@]}" || array_contains "$rel" "${important_related[@]}" || array_contains "$rel" "${review_related[@]}" || array_contains "$rel" "${retained_related[@]}"; then
    continue
  fi

  refs=()
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    refs+=( "$(normalize_relpath "$ref")" )
  done < <(extract_plan_refs "${repo_root}/${rel}")

  if [[ ${#refs[@]} -eq 0 ]]; then
    continue
  fi

  for ref in "${refs[@]}"; do
    if array_contains "$ref" "${delete_plans[@]}"; then
      external_refs+=( "$rel" )
      break
    fi
  done
done

mode_label="dry-run"
if [[ "$execute" -eq 1 ]]; then
  mode_label="execute"
fi

echo "=== docs-plan-cleanup-report:v1 ==="
echo "project: $repo_root"
echo "project_path_source: $project_path_source"
echo "mode: $mode_label"
echo "generated_at_utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo

echo "[summary]"
echo "total_plan_md: ${#plan_files[@]}"
echo "plan_md_to_keep: ${#keep_plans[@]}"
echo "plan_md_to_clean: ${#delete_plans[@]}"
echo "plan_related_md_to_clean: ${#delete_related[@]}"
echo "plan_related_md_kept_referenced_elsewhere: ${#retained_related[@]}"
echo "plan_related_md_to_rehome: ${#important_related[@]}"
echo "plan_related_md_manual_review: ${#review_related[@]}"
echo "non_docs_md_referencing_removed_plan: ${#external_refs[@]}"
echo

print_list "plan_md_to_keep" "${keep_plans[@]}"
print_list "plan_md_to_clean" "${delete_plans[@]}"
print_list "plan_related_md_to_clean" "${delete_related[@]}"
print_retained_related
print_list "plan_related_md_to_rehome" "${important_related[@]}"
print_list "plan_related_md_manual_review" "${review_related[@]}"
print_list "non_docs_md_referencing_removed_plan" "${external_refs[@]}"

if [[ "$execute" -eq 0 ]]; then
  echo "[execution]"
  echo "status: skipped (dry-run)"
  echo "deleted_plan_md: 0"
  echo "deleted_plan_related_md: 0"
  echo "deleted_important_md: 0"
  exit 0
fi

deleted_plans=0
for rel in "${delete_plans[@]}"; do
  if [[ -f "$rel" ]]; then
    rm -f "$rel"
    deleted_plans=$((deleted_plans + 1))
  fi
done

deleted_related=0
for rel in "${delete_related[@]}"; do
  if [[ -f "$rel" ]]; then
    rm -f "$rel"
    deleted_related=$((deleted_related + 1))
  fi
done

deleted_important=0
if [[ "$delete_important" -eq 1 ]]; then
  for rel in "${important_related[@]}"; do
    if [[ -f "$rel" ]]; then
      rm -f "$rel"
      deleted_important=$((deleted_important + 1))
    fi
  done
fi

if [[ "$delete_empty_dirs" -eq 1 ]]; then
  while IFS= read -r empty_dir; do
    [[ -n "$empty_dir" ]] || continue
    rmdir "$empty_dir" 2>/dev/null || true
  done < <(find docs -type d -empty -print | LC_ALL=C sort -r)
fi

echo "[execution]"
echo "status: applied"
echo "deleted_plan_md: $deleted_plans"
echo "deleted_plan_related_md: $deleted_related"
echo "deleted_important_md: $deleted_important"
