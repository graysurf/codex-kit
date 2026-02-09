#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deliver-feature-pr.sh <command> [options]

Commands:
  preflight  Validate delivery preconditions and enforce base-branch guard.
  wait-ci    Poll PR checks until fully green, failure, or timeout.
  close      Delegate PR merge/cleanup to close-feature-pr helper.

preflight options:
  --base <branch>           Expected starting/base branch (default: main)

wait-ci options:
  --pr <number>             PR number (required)
  --poll-seconds <n>        Poll interval in seconds (default: 20)
  --max-wait-seconds <n>    Maximum wait time in seconds (default: 7200)

close options:
  --pr <number>             PR number (optional; defaults to current-branch PR)
  --skip-checks             Pass-through to close_feature_pr.sh

Exit codes:
  0   Success
  1   Blocked/failure (branch mismatch, CI failure, command errors)
  2   Usage error
  124 CI wait timeout
USAGE
}

require_cmd() {
  local cmd="${1:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: missing required command: $cmd" >&2
    exit 1
  fi
}

require_clean_worktree() {
  if [[ -n "$(git status --porcelain=v1)" ]]; then
    echo "error: working tree is not clean; commit/stash first" >&2
    git status --porcelain=v1 >&2 || true
    exit 1
  fi
}

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: must run inside a git work tree" >&2
    exit 1
  }
}

contains_failed_check_state() {
  local text="${1:-}"
  if command -v rg >/dev/null 2>&1; then
    echo "$text" | rg -qi '(^|[[:space:]])(fail|failed|cancel|cancelled|timed_out|action_required|startup_failure)([[:space:]]|$)'
    return $?
  fi

  echo "$text" | grep -Eqi '(^|[[:space:]])(fail|failed|cancel|cancelled|timed_out|action_required|startup_failure)([[:space:]]|$)'
}

parse_positive_int() {
  local name="${1:-value}"
  local raw="${2:-}"
  if [[ ! "$raw" =~ ^[0-9]+$ ]]; then
    echo "error: $name must be a positive integer: $raw" >&2
    exit 2
  fi
  if [[ "$raw" -le 0 ]]; then
    echo "error: $name must be > 0: $raw" >&2
    exit 2
  fi
}

cmd_preflight() {
  local base="main"

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --base)
        if [[ $# -lt 2 ]]; then
          echo "error: --base requires a value" >&2
          exit 2
        fi
        base="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "error: unknown preflight argument: ${1:-}" >&2
        exit 2
        ;;
    esac
  done

  require_cmd git
  require_cmd gh
  require_git_repo
  require_clean_worktree
  gh auth status >/dev/null

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$current_branch" != "$base" ]]; then
    echo "error: initial branch guard failed (current=$current_branch, expected=$base)" >&2
    echo "action: stop and ask user to confirm source branch and merge target before continuing." >&2
    exit 1
  fi

  echo "ok: preflight passed (base=$base)"
}

cmd_wait_ci() {
  local pr=""
  local poll_seconds="20"
  local max_wait_seconds="7200"

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --pr)
        if [[ $# -lt 2 ]]; then
          echo "error: --pr requires a value" >&2
          exit 2
        fi
        pr="${2:-}"
        shift 2
        ;;
      --poll-seconds)
        if [[ $# -lt 2 ]]; then
          echo "error: --poll-seconds requires a value" >&2
          exit 2
        fi
        poll_seconds="${2:-}"
        shift 2
        ;;
      --max-wait-seconds)
        if [[ $# -lt 2 ]]; then
          echo "error: --max-wait-seconds requires a value" >&2
          exit 2
        fi
        max_wait_seconds="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "error: unknown wait-ci argument: ${1:-}" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$pr" ]]; then
    echo "error: --pr is required for wait-ci" >&2
    exit 2
  fi
  parse_positive_int "--poll-seconds" "$poll_seconds"
  parse_positive_int "--max-wait-seconds" "$max_wait_seconds"

  require_cmd gh
  local start now elapsed out rc
  start="$(date +%s)"

  while true; do
    out="$(gh pr checks "$pr" 2>&1)" || rc=$?
    rc="${rc:-0}"
    echo "$out"

    if [[ "$rc" -eq 0 ]]; then
      echo "ok: all checks passed for PR #$pr"
      exit 0
    fi

    if contains_failed_check_state "$out"; then
      echo "error: detected failing check state for PR #$pr" >&2
      exit 1
    fi

    now="$(date +%s)"
    elapsed=$((now - start))
    if [[ "$elapsed" -ge "$max_wait_seconds" ]]; then
      echo "error: timed out waiting for PR checks (elapsed=${elapsed}s, limit=${max_wait_seconds}s)" >&2
      exit 124
    fi

    sleep "$poll_seconds"
    rc=0
  done
}

cmd_close() {
  local pr=""
  local skip_checks="0"

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --pr)
        if [[ $# -lt 2 ]]; then
          echo "error: --pr requires a value" >&2
          exit 2
        fi
        pr="${2:-}"
        shift 2
        ;;
      --skip-checks)
        skip_checks="1"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "error: unknown close argument: ${1:-}" >&2
        exit 2
        ;;
    esac
  done

  require_cmd git
  require_cmd gh
  require_git_repo
  require_clean_worktree

  local script_dir feature_dir close_script
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  feature_dir="$(cd "$script_dir/../.." && pwd)"
  close_script="$feature_dir/close-feature-pr/scripts/close_feature_pr.sh"

  if [[ ! -x "$close_script" ]]; then
    echo "error: close-feature-pr helper not found or not executable: $close_script" >&2
    exit 1
  fi

  local -a cmd=( "$close_script" )
  if [[ -n "$pr" ]]; then
    cmd+=(--pr "$pr")
  fi
  if [[ "$skip_checks" == "1" ]]; then
    cmd+=(--skip-checks)
  fi

  "${cmd[@]}"
}

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 2
  fi

  local command="${1:-}"
  shift

  case "$command" in
    preflight)
      cmd_preflight "$@"
      ;;
    wait-ci)
      cmd_wait_ci "$@"
      ;;
    close)
      cmd_close "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "error: unknown command: $command" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
