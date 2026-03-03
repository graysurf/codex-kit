#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/ci/stale-skill-scripts-audit.sh [--check]

Classifies tracked skill scripts deterministically using three signals:
  - skill contract reference (SKILL.md)
  - skill entrypoint test reference (assert_entrypoints_exist usage)
  - runtime coverage spec (tests/script_specs/**.json)

Classification:
  ACTIVE        Contract + entrypoint test both reference the script.
  TRANSITIONAL  Partial ownership coverage; review before removal.
  REMOVABLE     No contract, no entrypoint test, and no runtime coverage spec.

Options:
  --check   Exit non-zero when removable scripts are detected.
  -h, --help
USAGE
}

check_mode=0
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --check)
      check_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" || ! -d "$repo_root" ]]; then
  echo "error: must run inside a git work tree" >&2
  exit 2
fi
cd "$repo_root"

pass() {
  printf 'PASS [stale-skill-scripts] %s\n' "$1"
}

warn() {
  printf 'WARN [stale-skill-scripts] %s\n' "$1"
}

fail() {
  printf 'FAIL [stale-skill-scripts] %s\n' "$1" >&2
  exit 1
}

skill_scripts=()
while IFS= read -r script; do
  [[ -n "$script" ]] || continue
  [[ -f "$script" ]] || continue
  skill_scripts+=("$script")
done < <(git ls-files 'skills/**/scripts/*' | sort)

if [[ "${#skill_scripts[@]}" -eq 0 ]]; then
  pass "no tracked skill scripts found"
  exit 0
fi

active_count=0
transitional_count=0
removable_count=0
removable_scripts=()

for script in "${skill_scripts[@]}"; do
  skill_root="${script%/scripts/*}"
  script_rel="scripts/${script##*/}"
  skill_md="${skill_root}/SKILL.md"
  test_dir="${skill_root}/tests"
  coverage_spec="tests/script_specs/${script}.json"

  contract_ref=0
  if [[ -f "$skill_md" ]]; then
    if grep -F -q -- "$script_rel" "$skill_md" || grep -F -q -- "$script" "$skill_md"; then
      contract_ref=1
    fi
  fi

  test_ref=0
  if [[ -d "$test_dir" ]]; then
    if grep -R -F -q -- "$script_rel" "$test_dir" || grep -R -F -q -- "$script" "$test_dir"; then
      test_ref=1
    fi
  fi

  runtime_ref=0
  if [[ -f "$coverage_spec" ]]; then
    runtime_ref=1
  fi

  classification="TRANSITIONAL"
  if [[ "$contract_ref" -eq 1 && "$test_ref" -eq 1 ]]; then
    classification="ACTIVE"
    active_count=$((active_count + 1))
  elif [[ "$contract_ref" -eq 0 && "$test_ref" -eq 0 && "$runtime_ref" -eq 0 ]]; then
    classification="REMOVABLE"
    removable_count=$((removable_count + 1))
    removable_scripts+=("$script")
  else
    transitional_count=$((transitional_count + 1))
  fi

  printf '%s\t%s\tcontract=%s\ttests=%s\truntime_coverage=%s\n' \
    "$classification" \
    "$script" \
    "$contract_ref" \
    "$test_ref" \
    "$runtime_ref"
done

printf 'SUMMARY\tactive=%s\ttransitional=%s\tremovable=%s\n' \
  "$active_count" \
  "$transitional_count" \
  "$removable_count"

if [[ "$removable_count" -gt 0 ]]; then
  warn "detected removable scripts:"
  for script in "${removable_scripts[@]}"; do
    warn "  - ${script}"
  done
  if [[ "$check_mode" -eq 1 ]]; then
    fail "remove or justify removable scripts before merge"
  fi
fi

pass "stale-skill-scripts audit complete (check=${check_mode})"
