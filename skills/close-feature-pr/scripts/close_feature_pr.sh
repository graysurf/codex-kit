#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  close_feature_pr.sh [--pr <number>] [--keep-branch] [--no-cleanup] [--skip-checks]

What it does:
  - (Optional) Fails fast if PR checks are not passing
  - Merges the PR with a merge commit
  - Deletes the remote head branch (unless --keep-branch)
  - Switches to the base branch, pulls, and deletes the local head branch (unless --no-cleanup)

Notes:
  - Requires: gh, git
  - Run inside a git repo with a GitHub PR (best: on the PR head branch)
USAGE
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

if [[ -z "$pr_number" ]]; then
  pr_number="$(gh pr view --json number -q .number 2>/dev/null || true)"
fi

if [[ -z "$pr_number" ]]; then
  echo "error: PR number is required (use --pr <number> or run on a branch with an open PR)" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain=v1)" ]]; then
  echo "error: working tree is not clean; commit/stash first" >&2
  git status --porcelain=v1 >&2 || true
  exit 1
fi

pr_url="$(gh pr view "$pr_number" --json url -q .url)"
base_branch="$(gh pr view "$pr_number" --json baseRefName -q .baseRefName)"
head_branch="$(gh pr view "$pr_number" --json headRefName -q .headRefName)"
repo_full="$(gh pr view "$pr_number" --json baseRepository -q .baseRepository.nameWithOwner)"
pr_state="$(gh pr view "$pr_number" --json state -q .state)"

if [[ -z "$repo_full" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" || -z "$pr_state" ]]; then
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

merge_args=(--merge --yes)
if [[ "$keep_branch" == "0" ]]; then
  merge_args+=(--delete-branch)
fi

gh pr merge "$pr_number" "${merge_args[@]}"

echo "merged: https://github.com/${repo_full}/pull/${pr_number}" >&2
echo "pr: ${pr_url}" >&2

if [[ "$no_cleanup" == "1" ]]; then
  exit 0
fi

set +e
git switch "$base_branch"
switched=$?
set -e

if [[ "$switched" != "0" ]]; then
  if git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
    git switch -c "$base_branch" "origin/${base_branch}" || true
  else
    git fetch origin "$base_branch" >/dev/null 2>&1 || true
    if git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
      git switch -c "$base_branch" "origin/${base_branch}" || true
    fi
  fi
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "$base_branch" ]]; then
  echo "warning: cannot switch to base branch (${base_branch}); skipping local cleanup" >&2
  exit 0
fi

git pull --ff-only || echo "warning: git pull --ff-only failed; verify base branch manually" >&2

if git show-ref --verify --quiet "refs/heads/${head_branch}"; then
  git branch -d "$head_branch" || echo "warning: failed to delete local branch ${head_branch}; delete manually if needed" >&2
fi
