#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create_worktrees_from_tsv.sh --spec <path> [--worktrees-root <path>] [--dry-run]

Spec format (TSV):
  branch<TAB>start_point<TAB>worktree_name<TAB>gh_base

Rules:
  - Lines starting with "#" are ignored.
  - Empty lines are ignored.
  - Worktrees are created under: <repo_root>/../.worktrees/<repo_name>/<worktree_name>

Example:
  feat/notifications-sprint1<TAB>main<TAB>feat__notifications-sprint1<TAB>main

Notes:
  - If a start_point doesn't resolve locally, this script will try to use `origin/<start_point>` when available
    (best-effort; it will not create local branches for start points).
USAGE
}

spec=""
worktrees_root_override=""
dry_run="0"
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --spec)
      spec="${2:-}"
      shift 2
      ;;
    --worktrees-root)
      worktrees_root_override="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run="1"
      shift
      ;;
    -h|--help|"")
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${spec}" ]]; then
  echo "error: --spec is required" >&2
  usage >&2
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
repo_name="$(basename "$repo_root")"
worktrees_root=""
if [[ -n "$worktrees_root_override" ]]; then
  if [[ "$worktrees_root_override" == /* ]]; then
    worktrees_root="$worktrees_root_override"
  else
    worktrees_root="${repo_root}/${worktrees_root_override}"
  fi
else
  worktrees_root="${repo_root}/../.worktrees/${repo_name}"
fi

mkdir -p "$worktrees_root"

echo "Repo root:        $repo_root"
echo "Worktrees root:   $worktrees_root"
echo "Spec:             $spec"
echo "Dry run:          $dry_run"
echo

resolve_start_point() {
  local start_point="${1:-}"
  if [[ -z "$start_point" ]]; then
    return 1
  fi

  if git rev-parse --verify --quiet "${start_point}^{commit}" >/dev/null; then
    printf "%s" "$start_point"
    return 0
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/${start_point}"; then
    printf "%s" "origin/${start_point}"
    return 0
  fi

  set +e
  git fetch origin "$start_point" >/dev/null 2>&1
  set -e

  if git show-ref --verify --quiet "refs/remotes/origin/${start_point}"; then
    printf "%s" "origin/${start_point}"
    return 0
  fi

  return 1
}

while IFS=$'\t' read -r branch start_point worktree_name gh_base; do
  [[ -z "${branch:-}" ]] && continue
  [[ "${branch:-}" =~ ^# ]] && continue

  if [[ -z "${start_point:-}" || -z "${worktree_name:-}" || -z "${gh_base:-}" ]]; then
    echo "error: invalid spec line (need 4 columns): branch start_point worktree_name gh_base" >&2
    echo "line: ${branch}\t${start_point:-}\t${worktree_name:-}\t${gh_base:-}" >&2
    exit 1
  fi

  path="${worktrees_root}/${worktree_name}"

  echo "==> Creating worktree"
  echo "  branch:      ${branch}"
  echo "  start_point: ${start_point}"
  echo "  path:        ${path}"
  echo "  gh_base:     ${gh_base}"

  if [[ -e "$path" ]]; then
    echo "error: path already exists: $path" >&2
    exit 1
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "error: branch already exists: ${branch}" >&2
    exit 1
  fi

  resolved_start_point="$(resolve_start_point "$start_point" || true)"
  if [[ -z "$resolved_start_point" ]]; then
    echo "error: start_point does not resolve to a commit: ${start_point}" >&2
    echo "hint: fetch/create it first, or use an explicit ref (e.g. origin/main)" >&2
    exit 1
  fi
  echo "  start_ref:   ${resolved_start_point}"

  if [[ "$dry_run" == "1" ]]; then
    echo "  (dry-run) skipping git worktree add"
    echo
    continue
  fi

  git worktree add -b "$branch" "$path" "$resolved_start_point"
  echo
done <"$spec"

echo "Done. Current worktrees:"
git worktree list --porcelain
