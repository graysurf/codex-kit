#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  close_bug_pr.sh [--pr <number>] [--keep-branch] [--no-cleanup] [--skip-checks]

What it does:
  - (Optional) Fails fast if PR checks are not passing
  - Marks draft PRs as ready automatically before merge
  - Merges the PR with a merge commit
  - Deletes the remote head branch (unless --keep-branch)
  - Switches to the base branch, pulls, and deletes the local head branch (unless --no-cleanup)

Notes:
  - Requires: gh, git
  - Run inside a git repo with a GitHub PR (best: on the PR head branch)
USAGE
}

query_pr_state() {
  local pr_number="${1:-}"
  local meta=''
  local state=''

  if [[ -z "$pr_number" ]]; then
    return 1
  fi

  meta="$(gh pr view "$pr_number" --json url,baseRefName,headRefName,state,isDraft -q '[.url, .baseRefName, .headRefName, .state, .isDraft] | @tsv' 2>/dev/null || true)"
  if [[ -z "$meta" ]]; then
    return 1
  fi

  IFS=$'\t' read -r _ _ _ state _ <<<"$meta"
  if [[ -z "$state" ]]; then
    return 1
  fi

  printf "%s\n" "$state"
  return 0
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

checkout_base_for_local_cleanup() {
  local base_branch="${1:-}"
  local switch_out=''
  local switch_rc=0
  local detach_out=''
  local detach_rc=0

  if [[ -z "$base_branch" ]]; then
    echo "none"
    return 1
  fi

  set +e
  switch_out="$(git switch "$base_branch" 2>&1)"
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

  if ensure_origin_base_ref "$base_branch"; then
    set +e
    detach_out="$(git switch --detach "origin/${base_branch}" 2>&1)"
    detach_rc=$?
    set -e

    if [[ "$detach_rc" -eq 0 ]]; then
      if [[ -n "$detach_out" ]]; then
        printf '%s\n' "$detach_out" >&2
      fi
      echo "note: using detached origin/${base_branch} for local cleanup (base branch may be checked out in another worktree)" >&2
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

delete_remote_head_branch_best_effort() {
  local head_branch="${1:-}"

  if [[ -z "$head_branch" ]]; then
    return 0
  fi

  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "warning: origin remote not configured; skipping remote branch deletion for ${head_branch}" >&2
    return 0
  fi

  local remote_head=''
  remote_head="$(git ls-remote --heads origin "$head_branch" 2>/dev/null || true)"
  if [[ -z "$remote_head" ]]; then
    return 0
  fi

  if ! git push origin --delete "$head_branch"; then
    echo "warning: failed to delete remote branch ${head_branch}; delete manually if needed" >&2
  fi
}

pr_number=""
keep_branch="0"
no_cleanup="0"
skip_checks="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      pr_number="${2:-}"
      shift 2
      ;;
    --keep-branch)
      keep_branch="1"
      shift
      ;;
    --no-cleanup)
      no_cleanup="1"
      shift
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
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh is required" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required" >&2
  exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: must run inside a git work tree" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain=v1)" ]]; then
  echo "error: working tree is not clean; commit/stash first" >&2
  git status --porcelain=v1 >&2 || true
  exit 1
fi

pr_view_args=()
if [[ -n "$pr_number" ]]; then
  pr_view_args=("$pr_number")
fi

pr_meta="$(gh pr view "${pr_view_args[@]}" --json url,baseRefName,headRefName,state,isDraft -q '[.url, .baseRefName, .headRefName, .state, .isDraft] | @tsv')"
IFS=$'\t' read -r pr_url base_branch head_branch pr_state pr_is_draft <<<"$pr_meta"

if [[ -z "$pr_number" ]]; then
  pr_number="$(python3 - "$pr_url" <<'PY'
from urllib.parse import urlparse
import sys

parts = [p for p in urlparse(sys.argv[1]).path.split("/") if p]

# Expected: /<owner>/<repo>/pull/<number>
if len(parts) < 4 or parts[2] != "pull":
  raise SystemExit(1)

print(parts[3])
PY
)"
fi

repo_full="$(python3 - "$pr_url" <<'PY'
from urllib.parse import urlparse
import sys

u = urlparse(sys.argv[1])
parts = [p for p in u.path.split("/") if p]

# Expected: /<owner>/<repo>/pull/<number>
if len(parts) < 4 or parts[2] != "pull":
  raise SystemExit(1)

print(f"{parts[0]}/{parts[1]}")
PY
)"

if [[ -z "$pr_number" || -z "$repo_full" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" || -z "$pr_state" || -z "$pr_is_draft" ]]; then
  echo "error: failed to resolve PR metadata via gh" >&2
  exit 1
fi

if [[ "$pr_state" != "OPEN" ]]; then
  echo "error: PR is not OPEN (state=$pr_state)" >&2
  exit 1
fi

if [[ "$skip_checks" == "0" ]]; then
  gh pr checks "$pr_number"
fi

if [[ "$pr_is_draft" == "true" ]]; then
  echo "note: PR #${pr_number} is draft; marking ready automatically" >&2
  gh pr ready "$pr_number"
fi

merge_args=(--merge)
if gh pr merge --help 2>/dev/null | grep -q -- "--yes"; then
  merge_args+=(--yes)
fi

merge_output=''
merge_rc=0
set +e
merge_output="$(gh pr merge "$pr_number" "${merge_args[@]}" 2>&1)"
merge_rc=$?
set -e

if [[ -n "$merge_output" ]]; then
  printf '%s\n' "$merge_output" >&2
fi

if [[ "$merge_rc" -ne 0 ]]; then
  pr_state_after_merge="$(query_pr_state "$pr_number" || true)"
  if [[ "$pr_state_after_merge" != "MERGED" ]]; then
    exit "$merge_rc"
  fi
  echo "warning: gh pr merge exited non-zero after PR #${pr_number} became MERGED; continuing with manual cleanup" >&2
fi

echo "merged: https://github.com/${repo_full}/pull/${pr_number}" >&2
echo "pr: ${pr_url}" >&2

if [[ "$keep_branch" == "0" ]]; then
  delete_remote_head_branch_best_effort "$head_branch"
fi

if [[ "$no_cleanup" == "1" ]]; then
  exit 0
fi

cleanup_mode="$(checkout_base_for_local_cleanup "$base_branch" || true)"
if [[ "$cleanup_mode" == "none" || -z "$cleanup_mode" ]]; then
  echo "warning: cannot switch to base branch (${base_branch}) or detached origin/${base_branch}; skipping local cleanup" >&2
  exit 0
fi

if [[ "$cleanup_mode" == "attached" ]]; then
  git pull --ff-only || echo "warning: git pull --ff-only failed; verify base branch manually" >&2
else
  echo "note: skipped git pull --ff-only because local cleanup is using detached origin/${base_branch}" >&2
fi

if git show-ref --verify --quiet "refs/heads/${head_branch}"; then
  git branch -d "$head_branch" || echo "warning: failed to delete local branch ${head_branch}; delete manually if needed" >&2
fi
