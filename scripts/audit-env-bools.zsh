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

# scan_hits <root_dir> <pattern> [ci]
# Print matching lines with file + line numbers using grep across tracked files.
scan_hits() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset root_dir="$1"
  typeset pattern="$2"
  typeset ci="${3:-0}"
  typeset -a grep_args=()
  typeset scan_status=0

  if [[ "$ci" == "1" ]]; then
    grep_args=(-niE -I)
  else
    grep_args=(-nE -I)
  fi

  if ! command -v git >/dev/null 2>&1; then
    print -u2 -r -- "error: git not available; run inside a git repo"
    return 2
  fi

  command git -C "$root_dir" grep "${grep_args[@]}" -- "$pattern" -- \
    . \
    ':(exclude)docs/progress' \
    ':(exclude)out' \
    ':(exclude)tmp' \
    ':(exclude)scripts/audit-env-bools.zsh' \
    2>/dev/null || scan_status=$?

  if (( scan_status == 1 )); then
    return 0
  fi
  if (( scan_status != 0 )); then
    return "$scan_status"
  fi
}

# check_no_legacy_names <root_dir>
# Ensure legacy env names are not referenced (excluding docs/progress/** which is already excluded from file list).
check_no_legacy_names() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
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
  typeset flag='' line='' file='' hits='' pattern='' joined='' line_upper='' payload=''

  joined="${(j:|:)legacy_strict}"
  pattern="(^|[^[:alnum:]_])(${joined})([^[:alnum:]_]|$)"
  hits="$(scan_hits "$root_dir" "$pattern" 0)"
  [[ -n "$hits" ]] || return 0

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    file="${line%%:*}"
    payload="${line#*:}"
    line_upper="${line:u}"
    for flag in "${legacy_strict[@]}"; do
      if [[ "$line_upper" == *"$flag"* ]] && [[ "$line" =~ "(^|[^[:alnum:]_])${flag}([^[:alnum:]_]|$)" ]]; then
        failed=1
        print -u2 -r -- "❌ legacy env name referenced: $flag"
        print -u2 -r -- "$file"
        print -u2 -r -- "$payload"
        break
      fi
    done
  done <<< "$hits"

  return "$failed"
}

# check_no_forbidden_values <root_dir>
# Ensure Inventory flags are never assigned to forbidden boolean vocab (0/1/yes/no/on/off).
check_no_forbidden_values() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
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
  typeset flag='' line='' file='' hits='' pattern='' joined='' line_upper='' payload=''

  joined="${(j:|:)inventory_flags}"
  pattern="(^|[^[:alnum:]_])(${joined})[[:space:]]*[:=][[:space:]]*['\\\"]?(0|1|yes|no|on|off)['\\\"]?([^[:alnum:]_]|$)"
  hits="$(scan_hits "$root_dir" "$pattern" 1)"
  [[ -n "$hits" ]] || return 0

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    file="${line%%:*}"
    payload="${line#*:}"
    line_upper="${line:u}"
    for flag in "${inventory_flags[@]}"; do
      if [[ "$line_upper" == *"$flag"* ]] && [[ "$line_upper" =~ "(^|[^[:alnum:]_])${flag}([[:space:]]*[:=][[:space:]]*['\\\"]?(0|1|YES|NO|ON|OFF)['\\\"]?)([^[:alnum:]_]|$)" ]]; then
        failed=1
        print -u2 -r -- "❌ forbidden boolean value for: $flag (only true|false allowed)"
        print -u2 -r -- "$file"
        print -u2 -r -- "$payload"
        break
      fi
    done
  done <<< "$hits"

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

  typeset -i failed=0
  check_no_legacy_names "$root_dir" || failed=1
  check_no_forbidden_values "$root_dir" || failed=1

  if (( failed )); then
    return 1
  fi

  return 0
}

main "$@"
