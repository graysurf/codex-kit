#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deliver-gitlab-mr.sh --kind <feature|bug|config|deploy|docs|chore> <command> [options]

Commands:
  preflight      Validate delivery preconditions and enforce base-branch guard.
  wait-pipeline  Poll the source branch pipeline until success, failure, or timeout.
  close          Delegate MR merge/cleanup to close-gitlab-mr.
  merge          Alias for close.

Global options:
  --kind <kind>  Delivery kind: feature, bug, config, deploy, docs, or chore.

preflight options:
  --base <branch>       Expected starting/base branch (default: main)
  --bypass-ambiguity    Continue when ambiguity signals are present.
  --proceed-all         Alias of --bypass-ambiguity.

wait-pipeline options:
  --mr <iid|branch>          Resolve the source branch from a GitLab MR.
  --branch <branch>          Source branch to poll.
  --source-branch <branch>   Alias of --branch.
  --allow-no-pipeline        Treat an absent GitLab pipeline as an explicit pass.
  --poll-seconds <n>         Poll interval in seconds (default: 20)
  --max-wait-seconds <n>     Maximum wait time in seconds (default: 7200)

close options:
  --mr <iid|branch>          MR to close (optional; defaults to current-branch MR).
  --poll-seconds <n>         Pipeline poll interval before merge (default: 20)
  --max-wait-seconds <n>     Maximum pipeline wait before merge (default: 7200)
  --skip-pipeline            Skip pipeline wait only after explicit user confirmation.
  --allow-no-pipeline        Merge when no pipeline exists, but still fail failed pipelines.
  --remove-source-branch     Ask GitLab to remove the remote source branch on merge.
  --squash                   Squash commits on merge.
  --sha <commit>             Merge only if the source branch HEAD matches the SHA.
  --keep-local-branch        Keep the local source branch during cleanup.
  --no-cleanup               Skip target checkout/pull and local source branch cleanup.

Exit codes:
  0    Success
  1    Blocked/failure (branch mismatch, pipeline failure, command errors)
  2    Usage error
  124  Pipeline wait timeout
USAGE
}

DELIVER_GITLAB_MR_KIND=""

require_kind() {
  local kind="${1:-}"
  case "$kind" in
    feature|bug|config|deploy|docs|chore)
      return 0
      ;;
    "")
      echo "error: --kind <feature|bug|config|deploy|docs|chore> is required" >&2
      return 2
      ;;
    *)
      echo "error: invalid --kind: $kind (expected feature|bug|config|deploy|docs|chore)" >&2
      return 2
      ;;
  esac
}

branch_prefix_for_kind() {
  local kind="${1:-}"
  case "$kind" in
    feature)
      echo "feat"
      ;;
    bug)
      echo "fix"
      ;;
    docs)
      echo "docs"
      ;;
    config|deploy|chore)
      echo "chore"
      ;;
    *)
      return 2
      ;;
  esac
}

require_cmd() {
  local cmd="${1:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: missing required command: $cmd" >&2
    exit 1
  fi
}

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: must run inside a git work tree" >&2
    exit 1
  }
}

require_clean_worktree() {
  if [[ -n "$(git status --porcelain=v1)" ]]; then
    echo "error: working tree is not clean; commit/stash first" >&2
    git status --porcelain=v1 >&2 || true
    exit 1
  fi
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

run_glab_auth_status() {
  local timeout_sec="${AGENT_KIT_GLAB_AUTH_TIMEOUT_SEC:-30}"
  parse_positive_int "AGENT_KIT_GLAB_AUTH_TIMEOUT_SEC" "$timeout_sec"

  python3 - "$timeout_sec" <<'PY'
import subprocess
import sys

timeout_sec = int(sys.argv[1])
try:
    proc = subprocess.run(
        ["glab", "auth", "status"],
        text=True,
        capture_output=True,
        timeout=timeout_sec,
        check=False,
    )
except subprocess.TimeoutExpired as exc:
    sys.stderr.write(f"error: glab auth status timed out after {timeout_sec}s\n")
    if exc.stdout:
        sys.stdout.write(exc.stdout if isinstance(exc.stdout, str) else exc.stdout.decode(errors="replace"))
    if exc.stderr:
        sys.stderr.write(exc.stderr if isinstance(exc.stderr, str) else exc.stderr.decode(errors="replace"))
    raise SystemExit(1)

if proc.stdout:
    sys.stdout.write(proc.stdout)
if proc.stderr:
    sys.stderr.write(proc.stderr)
raise SystemExit(proc.returncode)
PY
}

json_field() {
  python3 -c '
import json
import sys

keys = sys.argv[1:]
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)

if isinstance(data, list):
    data = data[0] if data else {}

def lookup(obj, key):
    cur = obj
    for part in key.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur

def emit(value):
    if isinstance(value, bool):
        print("true" if value else "false")
    elif value is not None:
        print(value)

for key in keys:
    value = lookup(data, key)
    if value is not None:
        emit(value)
        sys.exit(0)

sys.exit(1)
' "$@"
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
    .gitlab-ci.yml|.github/*|scripts/*|skills/*|setup/*|.editorconfig|.pre-commit-config.yaml|.pre-commit-config.yml|.tool-versions|Makefile|package-lock.json|pnpm-lock.yaml|yarn.lock|go.sum|Cargo.lock)
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
          SUSPICIOUS_REASONS[i]="${SUSPICIOUS_REASONS[$i]},$reason"
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
    DIFF_INSPECTION_RESULTS[i]="$(inspect_suspicious_path "$path")"
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

mr_json_for_ref() {
  local mr_ref="${1:-}"
  local -a args=(mr view)
  if [[ -n "$mr_ref" ]]; then
    args+=("$mr_ref")
  fi
  args+=(--output json)
  glab "${args[@]}"
}

resolve_mr_source_branch() {
  local mr_ref="${1:-}"
  local mr_json source_branch

  mr_json="$(mr_json_for_ref "$mr_ref")"
  source_branch="$(printf '%s' "$mr_json" | json_field source_branch sourceBranch headRefName 2>/dev/null || true)"
  if [[ -z "$source_branch" ]]; then
    echo "error: failed to resolve source branch from MR metadata" >&2
    exit 1
  fi

  printf '%s\n' "$source_branch"
}

pipeline_status_from_json() {
  json_field pipeline.status pipeline.detailed_status.group pipeline.detailedStatus.group status detailed_status.group detailedStatus.group 2>/dev/null || true
}

pipeline_status_for_branch() {
  local branch="${1:-}"
  local output status

  set +e
  output="$(glab ci status --branch "$branch" --output json 2>&1)"
  local rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    if printf '%s\n' "$output" | grep -qi 'No pipeline found'; then
      printf '%s\n' "$output" >&2
      printf '%s\n' "missing"
      return 3
    fi
    printf '%s\n' "$output" >&2
    return "$rc"
  fi

  status="$(printf '%s' "$output" | pipeline_status_from_json)"
  if [[ -z "$status" ]]; then
    echo "error: failed to parse pipeline status for branch ${branch}" >&2
    printf '%s\n' "$output" >&2
    return 1
  fi

  printf '%s\n' "$status"
}

wait_pipeline_for_branch() {
  local branch="${1:-}"
  local poll_seconds="${2:-20}"
  local max_wait_seconds="${3:-7200}"
  local allow_no_pipeline="${4:-0}"
  local start now elapsed status normalized status_rc

  if [[ -z "$branch" ]]; then
    echo "error: source branch is required for pipeline wait" >&2
    exit 2
  fi
  parse_positive_int "--poll-seconds" "$poll_seconds"
  parse_positive_int "--max-wait-seconds" "$max_wait_seconds"

  start="$(date +%s)"
  while true; do
    status_rc=0
    set +e
    status="$(pipeline_status_for_branch "$branch")"
    status_rc=$?
    set -e
    normalized="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')"
    echo "PIPELINE_STATUS=${normalized}"

    if [[ "$status_rc" -eq 3 && "$normalized" == "missing" ]]; then
      if [[ "$allow_no_pipeline" == "1" ]]; then
        echo "ok: no pipeline found for branch ${branch}; accepted by --allow-no-pipeline"
        return 0
      fi
      echo "error: no pipeline found for branch ${branch}; use --allow-no-pipeline only after confirming this repo has no CI" >&2
      return 1
    fi
    if [[ "$status_rc" -ne 0 ]]; then
      return "$status_rc"
    fi

    case "$normalized" in
      success|succeeded|passed|pass)
        echo "ok: pipeline passed for branch ${branch}"
        return 0
        ;;
      skipped|manual|blocked|action_required)
        echo "error: source-branch pipeline is not mergeable for branch ${branch} (status=${normalized})" >&2
        echo "error: if this repo intentionally uses target-branch CI, verify MR mergeability and target-branch validation, then use --skip-pipeline only after explicit user confirmation" >&2
        return 1
        ;;
      failed|fail|canceled|cancelled)
        echo "error: pipeline is not mergeable for branch ${branch} (status=${normalized})" >&2
        return 1
        ;;
      running|pending|created|preparing|waiting_for_resource|scheduled)
        ;;
      *)
        echo "error: unknown pipeline status for branch ${branch}: ${status}" >&2
        return 1
        ;;
    esac

    now="$(date +%s)"
    elapsed=$((now - start))
    if [[ "$elapsed" -ge "$max_wait_seconds" ]]; then
      echo "error: timed out waiting for GitLab pipeline (elapsed=${elapsed}s, limit=${max_wait_seconds}s)" >&2
      exit 124
    fi

    sleep "$poll_seconds"
  done
}

ensure_origin_base_ref() {
  local base_branch="${1:-}"

  if [[ -z "$base_branch" ]]; then
    return 1
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
    return 0
  fi

  git fetch origin "$base_branch" >/dev/null 2>&1 || return 1
  git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"
}

checkout_target_for_local_cleanup() {
  local target_branch="${1:-}"
  local switch_out=''
  local switch_rc=0
  local detach_out=''
  local detach_rc=0

  if [[ -z "$target_branch" ]]; then
    echo "none"
    return 1
  fi

  set +e
  switch_out="$(git switch "$target_branch" 2>&1)"
  switch_rc=$?
  set -e

  if [[ "$switch_rc" -eq 0 ]]; then
    if [[ -n "$switch_out" ]]; then
      printf '%s\n' "$switch_out" >&2
    fi
    echo "attached"
    return 0
  fi

  if [[ -n "$switch_out" ]]; then
    printf '%s\n' "$switch_out" >&2
  fi

  if ensure_origin_base_ref "$target_branch"; then
    set +e
    detach_out="$(git switch --detach "origin/${target_branch}" 2>&1)"
    detach_rc=$?
    set -e

    if [[ "$detach_rc" -eq 0 ]]; then
      if [[ -n "$detach_out" ]]; then
        printf '%s\n' "$detach_out" >&2
      fi
      echo "note: using detached origin/${target_branch} for local cleanup (target branch may be checked out in another worktree)" >&2
      echo "detached"
      return 0
    fi

    if [[ -n "$detach_out" ]]; then
      printf '%s\n' "$detach_out" >&2
    fi
  fi

  echo "none"
  return 1
}

cleanup_after_merge() {
  local target_branch="${1:-}"
  local source_branch="${2:-}"
  local keep_local_branch="${3:-0}"
  local checkout_mode current_branch

  checkout_mode="$(checkout_target_for_local_cleanup "$target_branch" || true)"
  if [[ "$checkout_mode" == "none" ]]; then
    echo "warning: failed to switch to target branch ${target_branch}; skipping local cleanup" >&2
    return 0
  fi

  if [[ "$checkout_mode" == "attached" ]]; then
    git fetch origin "$target_branch"
    git merge --ff-only "origin/${target_branch}"
  fi

  if [[ "$keep_local_branch" == "1" || -z "$source_branch" ]]; then
    return 0
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$current_branch" == "$source_branch" ]]; then
    echo "warning: still on source branch ${source_branch}; skipping local branch deletion" >&2
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/${source_branch}"; then
    git branch -d "$source_branch" || echo "warning: failed to delete local branch ${source_branch}" >&2
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
  require_cmd glab
  require_cmd python3
  require_git_repo
  collect_worktree_state
  print_worktree_state_summary
  echo "KIND=$DELIVER_GITLAB_MR_KIND"
  echo "BRANCH_PREFIX=$(branch_prefix_for_kind "$DELIVER_GITLAB_MR_KIND")"
  echo "CREATE_SKILL=create-gitlab-mr"
  echo "CLOSE_SKILL=close-gitlab-mr"
  echo "FINALIZE_COMMAND=close"

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$current_branch" != "$base" ]]; then
    echo "error: initial branch guard failed (current=$current_branch, expected=$base)" >&2
    echo "action: stop and ask user to confirm source branch and target branch before continuing." >&2
    exit 1
  fi

  run_glab_auth_status >/dev/null
  triage_preflight_scope_or_block "$bypass_ambiguity"
  echo "ok: preflight passed (base=$base)"
}

cmd_wait_pipeline() {
  local mr_ref=''
  local branch=''
  local allow_no_pipeline="0"
  local poll_seconds="20"
  local max_wait_seconds="7200"

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --mr)
        if [[ $# -lt 2 ]]; then
          echo "error: --mr requires a value" >&2
          exit 2
        fi
        mr_ref="${2:-}"
        shift 2
        ;;
      --branch|--source-branch)
        if [[ $# -lt 2 ]]; then
          echo "error: ${1:-} requires a value" >&2
          exit 2
        fi
        branch="${2:-}"
        shift 2
        ;;
      --allow-no-pipeline)
        allow_no_pipeline="1"
        shift
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
        echo "error: unknown wait-pipeline argument: ${1:-}" >&2
        exit 2
        ;;
    esac
  done

  require_cmd git
  require_cmd glab
  require_cmd python3
  require_git_repo

  if [[ -z "$branch" && -n "$mr_ref" ]]; then
    branch="$(resolve_mr_source_branch "$mr_ref")"
  fi
  if [[ -z "$branch" ]]; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
  fi

  echo "SOURCE_BRANCH=$branch"
  wait_pipeline_for_branch "$branch" "$poll_seconds" "$max_wait_seconds" "$allow_no_pipeline"
}

cmd_close() {
  local mr_ref=''
  local poll_seconds="20"
  local max_wait_seconds="7200"
  local skip_pipeline="0"
  local allow_no_pipeline="0"
  local remove_source_branch="0"
  local squash="0"
  local sha=''
  local keep_local_branch="0"
  local no_cleanup="0"

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --mr)
        if [[ $# -lt 2 ]]; then
          echo "error: --mr requires a value" >&2
          exit 2
        fi
        mr_ref="${2:-}"
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
      --skip-pipeline)
        skip_pipeline="1"
        shift
        ;;
      --allow-no-pipeline)
        allow_no_pipeline="1"
        shift
        ;;
      --remove-source-branch)
        remove_source_branch="1"
        shift
        ;;
      --squash)
        squash="1"
        shift
        ;;
      --sha)
        if [[ $# -lt 2 ]]; then
          echo "error: --sha requires a value" >&2
          exit 2
        fi
        sha="${2:-}"
        shift 2
        ;;
      --keep-local-branch)
        keep_local_branch="1"
        shift
        ;;
      --no-cleanup)
        no_cleanup="1"
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
  require_cmd glab
  require_cmd python3
  require_git_repo
  require_clean_worktree

  local script_dir gitlab_workflow_dir close_script
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  gitlab_workflow_dir="$(cd "$script_dir/../.." && pwd)"
  close_script="$gitlab_workflow_dir/close-gitlab-mr/scripts/close-gitlab-mr.sh"

  if [[ ! -x "$close_script" ]]; then
    echo "error: close-gitlab-mr helper not found or not executable: $close_script" >&2
    exit 1
  fi

  local -a cmd=( "$close_script" --kind "$DELIVER_GITLAB_MR_KIND" )
  if [[ -n "$mr_ref" ]]; then
    cmd+=(--mr "$mr_ref")
  fi
  cmd+=(--poll-seconds "$poll_seconds")
  cmd+=(--max-wait-seconds "$max_wait_seconds")
  if [[ "$skip_pipeline" == "1" ]]; then
    cmd+=(--skip-pipeline)
  fi
  if [[ "$allow_no_pipeline" == "1" ]]; then
    cmd+=(--allow-no-pipeline)
  fi
  if [[ "$remove_source_branch" == "1" ]]; then
    cmd+=(--remove-source-branch)
  fi
  if [[ "$squash" == "1" ]]; then
    cmd+=(--squash)
  fi
  if [[ -n "$sha" ]]; then
    cmd+=(--sha "$sha")
  fi
  if [[ "$keep_local_branch" == "1" ]]; then
    cmd+=(--keep-local-branch)
  fi
  if [[ "$no_cleanup" == "1" ]]; then
    cmd+=(--no-cleanup)
  fi

  "${cmd[@]}"
}

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 2
  fi

  local kind=''
  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --kind)
        if [[ $# -lt 2 ]]; then
          echo "error: --kind requires a value" >&2
          exit 2
        fi
        kind="${2:-}"
        shift 2
        ;;
      --kind=*)
        kind="${1#--kind=}"
        shift
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        break
        ;;
    esac
  done

  require_kind "$kind" || exit $?
  DELIVER_GITLAB_MR_KIND="$kind"

  if [[ $# -eq 0 ]]; then
    echo "error: missing command" >&2
    usage >&2
    exit 2
  fi

  local command="${1:-}"
  shift

  case "$command" in
    preflight)
      cmd_preflight "$@"
      ;;
    wait-pipeline)
      cmd_wait_pipeline "$@"
      ;;
    close|merge)
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
