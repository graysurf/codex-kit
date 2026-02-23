#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deliver-bug-pr.sh <command> [options]

Commands:
  preflight  Validate delivery preconditions and enforce base-branch guard.
  wait-ci    Poll PR checks until fully green, failure, or timeout.
  close      Delegate PR merge/cleanup to close-bug-pr helper.

preflight options:
  --base <branch>           Expected starting/base branch (default: main)
  --bypass-ambiguity        Continue when ambiguity signals are present.
  --proceed-all             Alias of --bypass-ambiguity.

wait-ci options:
  --pr <number>             PR number (required)
  --poll-seconds <n>        Poll interval in seconds (default: 20)
  --max-wait-seconds <n>    Maximum wait time in seconds (default: 7200)

close options:
  --pr <number>             PR number (optional; defaults to current-branch PR)
  --skip-checks             Pass-through to close_bug_pr.sh

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

declare -a WORKTREE_STAGED_PATHS=()
declare -a WORKTREE_UNSTAGED_PATHS=()
declare -a WORKTREE_UNTRACKED_PATHS=()
declare -a WORKTREE_ALL_PATHS=()
declare -a SUSPICIOUS_PATHS=()
declare -a SUSPICIOUS_REASONS=()
declare -a DIFF_INSPECTION_RESULTS=()

collect_worktree_state() {
  local path

  WORKTREE_STAGED_PATHS=()
  while IFS= read -r -d '' path; do
    WORKTREE_STAGED_PATHS+=("$path")
  done < <(git diff --name-only --cached -z)

  WORKTREE_UNSTAGED_PATHS=()
  while IFS= read -r -d '' path; do
    WORKTREE_UNSTAGED_PATHS+=("$path")
  done < <(git diff --name-only -z)

  WORKTREE_UNTRACKED_PATHS=()
  while IFS= read -r -d '' path; do
    WORKTREE_UNTRACKED_PATHS+=("$path")
  done < <(git ls-files --others --exclude-standard -z)
}

add_unique_worktree_path() {
  local path="${1:-}"
  local existing
  local i

  for (( i=0; i<${#WORKTREE_ALL_PATHS[@]}; i++ )); do
    existing="${WORKTREE_ALL_PATHS[$i]}"
    if [[ "$existing" == "$path" ]]; then
      return
    fi
  done

  WORKTREE_ALL_PATHS+=("$path")
}

build_all_worktree_paths() {
  local path
  local i
  WORKTREE_ALL_PATHS=()

  for (( i=0; i<${#WORKTREE_STAGED_PATHS[@]}; i++ )); do
    path="${WORKTREE_STAGED_PATHS[$i]}"
    add_unique_worktree_path "$path"
  done
  for (( i=0; i<${#WORKTREE_UNSTAGED_PATHS[@]}; i++ )); do
    path="${WORKTREE_UNSTAGED_PATHS[$i]}"
    add_unique_worktree_path "$path"
  done
  for (( i=0; i<${#WORKTREE_UNTRACKED_PATHS[@]}; i++ )); do
    path="${WORKTREE_UNTRACKED_PATHS[$i]}"
    add_unique_worktree_path "$path"
  done
}

path_in_unstaged_paths() {
  local needle="${1:-}"
  local i

  for (( i=0; i<${#WORKTREE_UNSTAGED_PATHS[@]}; i++ )); do
    if [[ "${WORKTREE_UNSTAGED_PATHS[$i]}" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

path_in_untracked_paths() {
  local needle="${1:-}"
  local i

  for (( i=0; i<${#WORKTREE_UNTRACKED_PATHS[@]}; i++ )); do
    if [[ "${WORKTREE_UNTRACKED_PATHS[$i]}" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

is_docs_path() {
  local path="${1:-}"
  if [[ "$path" == docs/* || "$path" == *.md ]]; then
    return 0
  fi
  return 1
}

is_infra_tooling_path() {
  local path="${1:-}"
  case "$path" in
    .github/*|scripts/*|skills/tools/*|setup/*|.editorconfig|.pre-commit-config.yaml|.pre-commit-config.yml|.tool-versions|Makefile|package-lock.json|pnpm-lock.yaml|yarn.lock|go.sum|Cargo.lock)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_path_domain() {
  local path="${1:-}"

  if is_infra_tooling_path "$path"; then
    echo "infra"
    return
  fi
  if is_docs_path "$path"; then
    echo "docs"
    return
  fi

  echo "product"
}

add_or_merge_suspicious_path() {
  local path="${1:-}"
  local reason="${2:-}"
  local i

  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    if [[ "${SUSPICIOUS_PATHS[$i]}" == "$path" ]]; then
      case ",${SUSPICIOUS_REASONS[$i]}," in
        *",$reason,"*)
          ;;
        *)
          SUSPICIOUS_REASONS[$i]="${SUSPICIOUS_REASONS[$i]},$reason"
          ;;
      esac
      return
    fi
  done

  SUSPICIOUS_PATHS+=("$path")
  SUSPICIOUS_REASONS+=("$reason")
  DIFF_INSPECTION_RESULTS+=("uncertain")
}

inspect_suspicious_path() {
  local path="${1:-}"
  local cached_diff unstaged_diff

  cached_diff="$(git diff --cached -- "$path" 2>/dev/null || true)"
  unstaged_diff="$(git diff -- "$path" 2>/dev/null || true)"

  if path_in_untracked_paths "$path"; then
    echo "uncertain"
    return
  fi
  if [[ -n "$cached_diff$unstaged_diff" ]]; then
    echo "uncertain"
    return
  fi

  echo "out-of-scope"
}

evaluate_suspicious_signals() {
  local has_product=0
  local has_infra=0
  local has_docs=0
  local path domain
  local staged_and_unstaged_overlap=0
  local all_infra_only=1
  local i

  SUSPICIOUS_PATHS=()
  SUSPICIOUS_REASONS=()
  DIFF_INSPECTION_RESULTS=()

  for (( i=0; i<${#WORKTREE_ALL_PATHS[@]}; i++ )); do
    path="${WORKTREE_ALL_PATHS[$i]}"
    domain="$(detect_path_domain "$path")"
    case "$domain" in
      infra)
        has_infra=1
        ;;
      docs)
        has_docs=1
        all_infra_only=0
        ;;
      *)
        has_product=1
        all_infra_only=0
        ;;
    esac
  done

  for (( i=0; i<${#WORKTREE_STAGED_PATHS[@]}; i++ )); do
    path="${WORKTREE_STAGED_PATHS[$i]}"
    if path_in_unstaged_paths "$path"; then
      staged_and_unstaged_overlap=1
      add_or_merge_suspicious_path "$path" "same_file_overlap"
    fi
  done

  if (( (has_product + has_infra + has_docs) >= 2 )) && [[ "${#WORKTREE_ALL_PATHS[@]}" -gt 1 ]]; then
    for (( i=0; i<${#WORKTREE_ALL_PATHS[@]}; i++ )); do
      path="${WORKTREE_ALL_PATHS[$i]}"
      add_or_merge_suspicious_path "$path" "cross_domain_path_spread"
    done
  fi

  if [[ "${#WORKTREE_ALL_PATHS[@]}" -gt 0 ]] && [[ "$all_infra_only" -eq 1 ]]; then
    for (( i=0; i<${#WORKTREE_ALL_PATHS[@]}; i++ )); do
      path="${WORKTREE_ALL_PATHS[$i]}"
      add_or_merge_suspicious_path "$path" "infra_tooling_only"
    done
  fi

  if [[ "$staged_and_unstaged_overlap" -eq 1 ]]; then
    echo "signal: same_file_overlap detected"
  fi
}

populate_diff_inspection_results() {
  local i path

  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    path="${SUSPICIOUS_PATHS[$i]}"
    DIFF_INSPECTION_RESULTS[$i]="$(inspect_suspicious_path "$path")"
  done
}

emit_block_payload_and_exit() {
  local flow="${1:-single_status_escalation}"
  local mixed_status="${2:-false}"
  local i

  echo "FLOW=$flow" >&2
  echo "BLOCK_STATE=blocked_for_ambiguity" >&2
  echo "CHANGE_STATE_SUMMARY=staged:${#WORKTREE_STAGED_PATHS[@]},unstaged:${#WORKTREE_UNSTAGED_PATHS[@]},untracked:${#WORKTREE_UNTRACKED_PATHS[@]},mixed_status=${mixed_status}" >&2

  echo "SUSPICIOUS_FILES=" >&2
  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    echo "- ${SUSPICIOUS_PATHS[$i]}" >&2
  done

  echo "SUSPICIOUS_REASONS=" >&2
  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    echo "- ${SUSPICIOUS_PATHS[$i]}: ${SUSPICIOUS_REASONS[$i]}" >&2
  done

  echo "DIFF_INSPECTION_RESULT=" >&2
  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    echo "- ${SUSPICIOUS_PATHS[$i]}: ${DIFF_INSPECTION_RESULTS[$i]}" >&2
  done

  echo "CONFIRMATION_PROMPT=Confirm whether the suspicious files are in scope for this task (proceed/abort)." >&2
  echo "NEXT_ACTION=wait for user confirmation before continuing" >&2
  exit 1
}

emit_bypass_payload() {
  local flow="${1:-single_status_escalation}"
  local mixed_status="${2:-false}"
  local i

  echo "FLOW=${flow}_bypass_ambiguity"
  echo "BYPASS_STATE=ambiguity_bypassed"
  echo "CHANGE_STATE_SUMMARY=staged:${#WORKTREE_STAGED_PATHS[@]},unstaged:${#WORKTREE_UNSTAGED_PATHS[@]},untracked:${#WORKTREE_UNTRACKED_PATHS[@]},mixed_status=${mixed_status}"

  echo "SUSPICIOUS_FILES="
  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    echo "- ${SUSPICIOUS_PATHS[$i]}"
  done

  echo "SUSPICIOUS_REASONS="
  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    echo "- ${SUSPICIOUS_PATHS[$i]}: ${SUSPICIOUS_REASONS[$i]}"
  done

  echo "DIFF_INSPECTION_RESULT="
  for (( i=0; i<${#SUSPICIOUS_PATHS[@]}; i++ )); do
    echo "- ${SUSPICIOUS_PATHS[$i]}: ${DIFF_INSPECTION_RESULTS[$i]}"
  done

  echo "BYPASS_NOTE=Preflight ambiguity checks were explicitly bypassed via --bypass-ambiguity."
  echo "NEXT_ACTION=continue delivery workflow with explicit user-confirmed scope"
}

triage_preflight_scope_or_block() {
  local bypass_ambiguity="${1:-0}"
  local is_mixed_status=0
  local flow="single_status_fast_path"
  local has_uncertain=0
  local i

  if [[ "${#WORKTREE_STAGED_PATHS[@]}" -gt 0 ]] && [[ "${#WORKTREE_UNSTAGED_PATHS[@]}" -gt 0 ]]; then
    is_mixed_status=1
    flow="mixed_status"
  fi

  build_all_worktree_paths
  evaluate_suspicious_signals

  if [[ "${#SUSPICIOUS_PATHS[@]}" -eq 0 ]]; then
    echo "FLOW=$flow"
    return
  fi

  if [[ "$is_mixed_status" -eq 0 ]]; then
    flow="single_status_escalation"
  fi

  populate_diff_inspection_results
  for (( i=0; i<${#DIFF_INSPECTION_RESULTS[@]}; i++ )); do
    if [[ "${DIFF_INSPECTION_RESULTS[$i]}" == "uncertain" ]]; then
      has_uncertain=1
      break
    fi
  done

  if [[ "$has_uncertain" -eq 1 ]]; then
    if [[ "$bypass_ambiguity" -eq 1 ]]; then
      emit_bypass_payload "$flow" "$([[ "$is_mixed_status" -eq 1 ]] && echo "true" || echo "false")"
      return
    fi
    emit_block_payload_and_exit "$flow" "$([[ "$is_mixed_status" -eq 1 ]] && echo "true" || echo "false")"
  fi

  echo "FLOW=$flow"
}

print_worktree_state_summary() {
  echo "state: worktree changes (staged=${#WORKTREE_STAGED_PATHS[@]}, unstaged=${#WORKTREE_UNSTAGED_PATHS[@]}, untracked=${#WORKTREE_UNTRACKED_PATHS[@]})"
  echo "CHANGE_STATE_SUMMARY=staged:${#WORKTREE_STAGED_PATHS[@]},unstaged:${#WORKTREE_UNSTAGED_PATHS[@]},untracked:${#WORKTREE_UNTRACKED_PATHS[@]},mixed_status=$([[ "${#WORKTREE_STAGED_PATHS[@]}" -gt 0 && "${#WORKTREE_UNSTAGED_PATHS[@]}" -gt 0 ]] && echo "true" || echo "false")"
}

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: must run inside a git work tree" >&2
    exit 1
  }
}

query_pr_state_for_close() {
  local pr="${1:-}"
  local meta=''
  local state=''

  if [[ -z "$pr" ]]; then
    return 1
  fi

  meta="$(gh pr view "$pr" --json url,baseRefName,headRefName,state,isDraft -q '[.url, .baseRefName, .headRefName, .state, .isDraft] | @tsv' 2>/dev/null || true)"
  if [[ -z "$meta" ]]; then
    return 1
  fi

  IFS=$'\t' read -r _ _ _ state _ <<<"$meta"
  if [[ -z "$state" ]]; then
    return 1
  fi

  printf '%s\n' "$state"
  return 0
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
  local bypass_ambiguity=0

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
      --bypass-ambiguity|--proceed-all)
        bypass_ambiguity=1
        shift
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
  collect_worktree_state
  print_worktree_state_summary
  gh auth status >/dev/null
  triage_preflight_scope_or_block "$bypass_ambiguity"

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
  local pr=''
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
  local pr=''
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

  local script_dir bug_workflow_dir close_script
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bug_workflow_dir="$(cd "$script_dir/../.." && pwd)"
  close_script="$bug_workflow_dir/close-bug-pr/scripts/close_bug_pr.sh"

  if [[ ! -x "$close_script" ]]; then
    echo "error: close-bug-pr helper not found or not executable: $close_script" >&2
    exit 1
  fi

  local -a cmd=( "$close_script" )
  if [[ -n "$pr" ]]; then
    cmd+=(--pr "$pr")
  fi
  if [[ "$skip_checks" == "1" ]]; then
    cmd+=(--skip-checks)
  fi

  local close_rc=0
  set +e
  "${cmd[@]}"
  close_rc=$?
  set -e

  if [[ "$close_rc" -eq 0 ]]; then
    return 0
  fi

  local resolved_pr="$pr"
  if [[ -z "$resolved_pr" ]]; then
    resolved_pr="$(gh pr view --json number -q .number 2>/dev/null || true)"
  fi

  if [[ -n "$resolved_pr" ]]; then
    local pr_state=''
    pr_state="$(query_pr_state_for_close "$resolved_pr" || true)"
    if [[ "$pr_state" == "MERGED" ]]; then
      echo "warning: close-bug-pr helper exited ${close_rc}, but PR #${resolved_pr} is already MERGED; treating close as success" >&2
      return 0
    fi
  fi

  exit "$close_rc"
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
