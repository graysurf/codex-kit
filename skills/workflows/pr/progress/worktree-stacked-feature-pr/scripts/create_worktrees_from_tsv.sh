#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create_worktrees_from_tsv.sh --spec <path>

Spec format (TSV):
  branch<TAB>start_point<TAB>worktree_name<TAB>gh_base

Rules:
  - Lines starting with "#" are ignored.
  - Empty lines are ignored.
  - Worktrees are created under: <repo_root>/../.worktrees/<repo_name>/<worktree_name>

Example:
  feat/notifications-sprint1<TAB>main<TAB>feat__notifications-sprint1<TAB>main
USAGE
}

spec=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --spec)
      spec="${2:-}"
      shift 2
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
worktrees_root="${repo_root}/../.worktrees/${repo_name}"

mkdir -p "$worktrees_root"

echo "Repo root:        $repo_root"
echo "Worktrees root:   $worktrees_root"
echo "Spec:             $spec"
echo

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

  git worktree add -b "$branch" "$path" "$start_point"
  echo
done <"$spec"

echo "Done. Current worktrees:"
git worktree list --porcelain

