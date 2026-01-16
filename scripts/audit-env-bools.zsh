#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="scripts/$SCRIPT_NAME"

# print_usage: Print CLI usage/help.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [--check] [-h|--help]"
  print -r --
  print -r -- "Purpose:"
  print -r -- "  Enforce repo boolean env rules for Inventory flags."
  print -r --
  print -r -- "Checks (Inventory flags):"
  print -r -- "  - No legacy env names in tracked files (excludes docs/progress/**)."
  print -r -- "  - No 0/1/yes/no/on/off assignments (only true|false allowed)."
  print -r --
  print -r -- "Examples:"
  print -r -- "  $SCRIPT_HINT --check"
}

# repo_root_from_script: Resolve repo root directory from this script path.
repo_root_from_script() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset script_dir='' root_dir='' git_root=''
  script_dir="${SCRIPT_PATH:h}"
  root_dir="${script_dir:h}"

  if command -v git >/dev/null 2>&1; then
    git_root="$(command git -C "$root_dir" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$git_root" ]]; then
      print -r -- "$git_root"
      return 0
    fi
  fi

  print -r -- "$root_dir"
}

# list_scan_files <root_dir>
# Print the absolute file paths to scan (tracked files excluding docs/progress).
list_scan_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
  typeset -a files=()
  typeset rel=''

  if command -v git >/dev/null 2>&1 && git -C "$root_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue

      case "$rel" in
        docs/progress/*) continue ;;
        out/*) continue ;;
        tmp/*) continue ;;
        scripts/audit-env-bools.zsh) continue ;;
      esac

      files+=("$root_dir/$rel")
    done < <(git -C "$root_dir" ls-files)
  else
    print -u2 -r -- "error: cannot list tracked files (git not available); run inside a git repo"
    return 2
  fi

  print -rl -- "${files[@]}"
}

# grep_hits <pattern> <file>
# Print matching lines with line numbers (grep -nE -I); return 0 when hits exist.
grep_hits() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset pattern="$1"
  typeset file="$2"

  command grep -nEI -- "$pattern" "$file" 2>/dev/null
}

# grep_hits_ci <pattern> <file>
# Print matching lines with line numbers (grep -niE -I); return 0 when hits exist.
grep_hits_ci() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset pattern="$1"
  typeset file="$2"

  command grep -niEI -- "$pattern" "$file" 2>/dev/null
}

# check_no_legacy_names <files...>
# Ensure legacy env names are not referenced (excluding docs/progress/** which is already excluded from file list).
check_no_legacy_names() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a files=("$@")
  typeset -a legacy_strict=(
    CHROME_DEVTOOLS_DRY_RUN
    CHROME_DEVTOOLS_PREFLIGHT
    CHROME_DEVTOOLS_AUTOCONNECT
    REST_HISTORY
    REST_HISTORY_LOG_URL
    REST_REPORT_INCLUDE_COMMAND
    REST_REPORT_COMMAND_LOG_URL
    GQL_HISTORY
    GQL_HISTORY_LOG_URL
    GQL_REPORT_INCLUDE_COMMAND
    GQL_REPORT_COMMAND_LOG_URL
    GQL_ALLOW_EMPTY
    API_TEST_ALLOW_WRITES
    CODEX_CURL_STUB_MODE
    CODEX_XH_STUB_MODE
    CODEX_GH_STUB_MODE
    CODEX_GH_STUB_MERGE_HELP_HAS_YES
  )

  typeset -i failed=0
  typeset flag='' file='' hits='' pattern=''

  for flag in "${legacy_strict[@]}"; do
    pattern="(^|[^[:alnum:]_])${flag}([^[:alnum:]_]|$)"
    for file in "${files[@]}"; do
      [[ -r "$file" ]] || continue
      hits="$(grep_hits "$pattern" "$file" || true)"
      [[ -n "$hits" ]] || continue
      failed=1
      print -u2 -r -- "❌ legacy env name referenced: $flag"
      print -u2 -r -- "$file"
      print -u2 -r -- "$hits"
    done
  done

  return "$failed"
}

# check_no_forbidden_values <files...>
# Ensure Inventory flags are never assigned to forbidden boolean vocab (0/1/yes/no/on/off).
check_no_forbidden_values() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a files=("$@")
  typeset -a inventory_flags=(
    CHROME_DEVTOOLS_DRY_RUN_ENABLED
    CHROME_DEVTOOLS_PREFLIGHT_ENABLED
    CHROME_DEVTOOLS_AUTOCONNECT_ENABLED
    REST_HISTORY_ENABLED
    REST_HISTORY_LOG_URL_ENABLED
    REST_REPORT_INCLUDE_COMMAND_ENABLED
    REST_REPORT_COMMAND_LOG_URL_ENABLED
    GQL_HISTORY_ENABLED
    GQL_HISTORY_LOG_URL_ENABLED
    GQL_REPORT_INCLUDE_COMMAND_ENABLED
    GQL_REPORT_COMMAND_LOG_URL_ENABLED
    GQL_ALLOW_EMPTY_ENABLED
    API_TEST_ALLOW_WRITES_ENABLED
    CODEX_CURL_STUB_MODE_ENABLED
    CODEX_XH_STUB_MODE_ENABLED
    CODEX_GH_STUB_MODE_ENABLED
    CODEX_GH_STUB_MERGE_HELP_HAS_YES_ENABLED
  )

  typeset -i failed=0
  typeset flag='' file='' hits='' pattern=''

  for flag in "${inventory_flags[@]}"; do
    pattern="(^|[^[:alnum:]_])${flag}[[:space:]]*[:=][[:space:]]*['\\\"]?(0|1|yes|no|on|off)['\\\"]?([^[:alnum:]_]|$)"
    for file in "${files[@]}"; do
      [[ -r "$file" ]] || continue
      hits="$(grep_hits_ci "$pattern" "$file" || true)"
      [[ -n "$hits" ]] || continue
      failed=1
      print -u2 -r -- "❌ forbidden boolean value for: $flag (only true|false allowed)"
      print -u2 -r -- "$file"
      print -u2 -r -- "$hits"
    done
  done

  return "$failed"
}

# main [args...]
# CLI entrypoint for the audit script.
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  zparseopts -D -E -A opts -- -check h -help || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset root_dir=''
  root_dir="$(repo_root_from_script)"

  typeset -a files=()
  typeset file=''
  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done < <(list_scan_files "$root_dir")

  typeset -i failed=0
  check_no_legacy_names "${files[@]}" || failed=1
  check_no_forbidden_values "${files[@]}" || failed=1

  if (( failed )); then
    return 1
  fi

  return 0
}

main "$@"
