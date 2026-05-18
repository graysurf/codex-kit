#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  close-gitlab-mr.sh --kind <feature|bug|config|deploy|docs|chore> [--mr <iid|branch>] [options]

What it does:
  - Blocks missing GitLab pipelines unless --allow-no-pipeline is explicit
  - Blocks failed, canceled, skipped, blocked, manual, pending, or unknown pipelines
  - Marks draft MRs as ready automatically before merge
  - Merges the MR with glab mr merge
  - Removes the remote source branch only when --remove-source-branch is supplied
  - Switches to the target branch, fast-forwards from origin, and deletes the local source branch unless cleanup is disabled

Options:
  --kind <kind>            Delivery kind: feature, bug, config, deploy, docs, or chore.
  --mr <iid|branch>        MR to close. Defaults to the current-branch MR.
  --poll-seconds <n>       Pipeline poll interval before merge (default: 20)
  --max-wait-seconds <n>   Maximum pipeline wait before merge (default: 7200)
  --skip-pipeline          Skip pipeline wait only after explicit user confirmation.
  --allow-no-pipeline      Merge when no pipeline exists, but still fail failed pipelines.
  --remove-source-branch   Ask GitLab to remove the remote source branch on merge.
  --squash                 Squash commits on merge.
  --sha <commit>           Merge only if the source branch HEAD matches the SHA.
  --keep-local-branch      Keep the local source branch during cleanup.
  --no-cleanup             Skip target checkout/pull and local source branch cleanup.

Exit codes:
  0    Success
  1    Blocked/failure
  2    Usage error
  124  Pipeline wait timeout
USAGE
}

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

mr_json_for_ref() {
  local mr_ref="${1:-}"
  local -a args=(mr view)
  if [[ -n "$mr_ref" ]]; then
    args+=("$mr_ref")
  fi
  args+=(--output json)
  glab "${args[@]}"
}

pipeline_status_from_json() {
  json_field pipeline.status pipeline.detailed_status.group pipeline.detailedStatus.group status detailed_status.group detailedStatus.group 2>/dev/null || true
}

pipeline_status_for_branch() {
  local branch="${1:-}"
  local output status rc

  set +e
  output="$(glab ci status --branch "$branch" --output json 2>&1)"
  rc=$?
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

ensure_origin_target_ref() {
  local target_branch="${1:-}"

  if [[ -z "$target_branch" ]]; then
    return 1
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/${target_branch}"; then
    return 0
  fi

  git fetch origin "$target_branch" >/dev/null 2>&1 || return 1
  git show-ref --verify --quiet "refs/remotes/origin/${target_branch}"
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

  if ensure_origin_target_ref "$target_branch"; then
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
  else
    echo "note: skipped target-branch fast-forward because local cleanup is using detached origin/${target_branch}" >&2
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

query_mr_state() {
  local mr_ref="${1:-}"
  local mr_json state

  if [[ -z "$mr_ref" ]]; then
    return 1
  fi

  mr_json="$(mr_json_for_ref "$mr_ref" 2>/dev/null || true)"
  if [[ -z "$mr_json" ]]; then
    return 1
  fi

  state="$(printf '%s' "$mr_json" | json_field state 2>/dev/null || true)"
  if [[ -z "$state" ]]; then
    return 1
  fi

  printf '%s\n' "$state"
}

kind=''
mr_ref=''
poll_seconds='20'
max_wait_seconds='7200'
skip_pipeline='0'
allow_no_pipeline='0'
remove_source_branch='0'
squash='0'
sha=''
keep_local_branch='0'
no_cleanup='0'

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
      skip_pipeline='1'
      shift
      ;;
    --allow-no-pipeline)
      allow_no_pipeline='1'
      shift
      ;;
    --remove-source-branch)
      remove_source_branch='1'
      shift
      ;;
    --squash)
      squash='1'
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
      keep_local_branch='1'
      shift
      ;;
    --no-cleanup)
      no_cleanup='1'
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

require_kind "$kind" || exit $?
require_cmd git
require_cmd glab
require_cmd python3
require_git_repo

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
require_clean_worktree
parse_positive_int "--poll-seconds" "$poll_seconds"
parse_positive_int "--max-wait-seconds" "$max_wait_seconds"
run_glab_auth_status >/dev/null

mr_json="$(mr_json_for_ref "$mr_ref")"
mr_iid="$(printf '%s' "$mr_json" | json_field iid id 2>/dev/null || true)"
mr_url="$(printf '%s' "$mr_json" | json_field web_url webUrl url 2>/dev/null || true)"
source_branch="$(printf '%s' "$mr_json" | json_field source_branch sourceBranch headRefName 2>/dev/null || true)"
target_branch="$(printf '%s' "$mr_json" | json_field target_branch targetBranch baseRefName 2>/dev/null || true)"
mr_state="$(printf '%s' "$mr_json" | json_field state 2>/dev/null || true)"
mr_draft="$(printf '%s' "$mr_json" | json_field draft work_in_progress workInProgress isDraft 2>/dev/null || true)"

if [[ -z "$source_branch" || -z "$target_branch" ]]; then
  echo "error: failed to resolve MR source/target branch metadata" >&2
  exit 1
fi
case "$(printf '%s' "$mr_state" | tr '[:upper:]' '[:lower:]')" in
  opened|open|"")
    ;;
  *)
    echo "error: MR is not open (state=${mr_state})" >&2
    exit 1
    ;;
esac

echo "MR_KIND=$kind"
echo "MR_IID=${mr_iid:-$mr_ref}"
echo "MR_URL=${mr_url:-unknown}"
echo "SOURCE_BRANCH=$source_branch"
echo "TARGET_BRANCH=$target_branch"

if [[ "$skip_pipeline" == "0" ]]; then
  wait_pipeline_for_branch "$source_branch" "$poll_seconds" "$max_wait_seconds" "$allow_no_pipeline"
else
  echo "PIPELINE_STATUS=skipped_by_user_confirmation"
fi

mr_args=()
if [[ -n "$mr_ref" ]]; then
  mr_args+=("$mr_ref")
fi

if [[ "$(printf '%s' "$mr_draft" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
  glab mr update "${mr_args[@]}" --ready --yes
fi

merge_args=(mr merge)
if [[ -n "$mr_ref" ]]; then
  merge_args+=("$mr_ref")
fi
if [[ "$remove_source_branch" == "1" ]]; then
  merge_args+=(--remove-source-branch)
fi
if [[ "$squash" == "1" ]]; then
  merge_args+=(--squash)
fi
if [[ -n "$sha" ]]; then
  merge_args+=(--sha "$sha")
fi
merge_args+=(--yes)

merge_output=''
merge_rc=0
set +e
merge_output="$(glab "${merge_args[@]}" 2>&1)"
merge_rc=$?
set -e

if [[ -n "$merge_output" ]]; then
  printf '%s\n' "$merge_output" >&2
fi

if [[ "$merge_rc" -ne 0 ]]; then
  mr_state_after_merge="$(query_mr_state "${mr_ref:-$mr_iid}" || true)"
  if [[ "$(printf '%s' "$mr_state_after_merge" | tr '[:upper:]' '[:lower:]')" != "merged" ]]; then
    exit "$merge_rc"
  fi
  echo "warning: glab mr merge exited non-zero after MR ${mr_iid:+!$mr_iid} became merged; continuing with local cleanup" >&2
fi

echo "merged: ${mr_url:-GitLab MR ${mr_iid:+!$mr_iid}}" >&2

if [[ "$no_cleanup" == "0" ]]; then
  cleanup_after_merge "$target_branch" "$source_branch" "$keep_local_branch"
fi

echo "ok: merged GitLab MR ${mr_iid:+!$mr_iid}"
