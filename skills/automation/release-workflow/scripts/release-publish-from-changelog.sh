#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-publish-from-changelog: $1" >&2
  exit 2
}

info() {
  echo "info: $1" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-publish-from-changelog.sh --version <vX.Y.Z> [--repo <path>] [--changelog <path>] [--notes-output <path>] [--title <text>] [--if-exists <edit|fail>] [--push-current-branch] [--no-verify-body]

Behavior:
  - Extracts release notes from CHANGELOG.md for --version.
  - Requires a clean git work tree on a checked-out branch with a configured upstream.
  - Fails when HEAD is not synced to upstream unless --push-current-branch is set.
  - Creates the release when missing.
  - Edits the release when it already exists (default behavior).
  - Verifies the published release body is non-empty unless --no-verify-body is set.

Notes:
  - Default repo: current directory
  - Default changelog: CHANGELOG.md
  - Default title: <version>
  - Default --if-exists: edit
  - This script is the supported publish entrypoint for release-workflow.
EOF
}

repo="."
version=""
changelog="CHANGELOG.md"
notes_output=""
title=""
if_exists="edit"
verify_body=1
push_current_branch=0

ensure_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "repo is not a git work tree: $repo"
}

ensure_clean_worktree() {
  local status_output=''
  status_output="$(git status --porcelain 2>/dev/null || true)"
  if [[ -n "$status_output" ]]; then
    die "working tree must be clean before publishing (commit or stash changes first)"
  fi
}

require_publishable_head() {
  local current_branch=''
  local head_sha=''
  local upstream_ref=''
  local counts=''
  local ahead_count='0'
  local behind_count='0'
  local upstream_remote=''
  local upstream_branch=''

  current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [[ -n "$current_branch" ]] || die "detached HEAD: checkout a branch before publishing"

  head_sha="$(git rev-parse HEAD 2>/dev/null || true)"
  [[ "$head_sha" =~ ^[0-9a-f]{40}$ ]] || die "unable to resolve HEAD commit"

  upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  [[ -n "$upstream_ref" ]] || die "current branch has no upstream: $current_branch (push with --set-upstream before publishing)"
  [[ "$upstream_ref" == */* ]] || die "unsupported upstream ref format: $upstream_ref"

  counts="$(git rev-list --left-right --count "HEAD...$upstream_ref" 2>/dev/null || true)"
  [[ -n "$counts" ]] || die "unable to compare HEAD with upstream $upstream_ref"
  read -r ahead_count behind_count <<<"$counts"
  [[ "$ahead_count" =~ ^[0-9]+$ ]] || die "unable to parse ahead count for $upstream_ref"
  [[ "$behind_count" =~ ^[0-9]+$ ]] || die "unable to parse behind count for $upstream_ref"

  if [[ "$behind_count" -gt 0 && "$ahead_count" -gt 0 ]]; then
    die "current branch diverged from $upstream_ref (ahead=$ahead_count behind=$behind_count); reconcile before publishing"
  fi
  if [[ "$behind_count" -gt 0 ]]; then
    die "current branch is behind $upstream_ref by $behind_count commit(s); pull/rebase before publishing"
  fi
  if [[ "$ahead_count" -gt 0 ]]; then
    if [[ "$push_current_branch" -ne 1 ]]; then
      die "current branch is ahead of $upstream_ref by $ahead_count commit(s); push first or rerun with --push-current-branch"
    fi

    upstream_remote="${upstream_ref%%/*}"
    upstream_branch="${upstream_ref#*/}"
    info "pushing $current_branch to $upstream_ref before publishing"
    git push "$upstream_remote" "HEAD:${upstream_branch}" >/dev/null
  fi

  printf "%s\n" "$head_sha"
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --version)
      version="${2:-}"
      shift 2
      ;;
    --changelog)
      changelog="${2:-}"
      shift 2
      ;;
    --notes-output)
      notes_output="${2:-}"
      shift 2
      ;;
    --title)
      title="${2:-}"
      shift 2
      ;;
    --if-exists)
      if_exists="${2:-}"
      shift 2
      ;;
    --push-current-branch)
      push_current_branch=1
      shift
      ;;
    --no-verify-body)
      verify_body=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: ${1:-}"
      ;;
  esac
done

[[ -n "$version" ]] || die "missing --version (expected vX.Y.Z)"
[[ "$if_exists" == "edit" || "$if_exists" == "fail" ]] || die "invalid --if-exists value: $if_exists (expected edit|fail)"

if [[ -z "$title" ]]; then
  title="$version"
fi

cd "$repo" || die "unable to cd: $repo"

require_cmd gh
require_cmd git
require_cmd awk
ensure_git_repo
ensure_clean_worktree
if [[ ! -f "$changelog" ]]; then
  die "changelog not found: $changelog"
fi

head_sha="$(require_publishable_head)"

if [[ -z "$notes_output" ]]; then
  agent_home="${AGENT_HOME:-}"
  if [[ -n "$agent_home" ]]; then
    notes_output="${agent_home%/}/out/release-notes-${version}.md"
  else
    notes_output="./release-notes-${version}.md"
  fi
fi

notes_output_dir="$(dirname "$notes_output")"
mkdir -p -- "$notes_output_dir"
tmp_notes="$(mktemp "${notes_output_dir%/}/.release-notes-${version}.XXXXXX.tmp")"
cleanup_tmp() {
  if [[ -n "${tmp_notes:-}" && -f "$tmp_notes" ]]; then
    rm -f -- "$tmp_notes"
  fi
}
trap cleanup_tmp EXIT

info "extracting release notes for $version"
awk -v v="$version" '
  $0 ~ "^## " v " " { f=1; heading=NR }
  f {
    if (NR > heading && $0 ~ "^## ") { exit }
    print
  }
' "$changelog" >"$tmp_notes"

if [[ ! -s "$tmp_notes" ]]; then
  die "version section not found in $changelog: $version"
fi
if ! grep -Fq "## ${version} " "$tmp_notes"; then
  die "extracted notes heading mismatch for $version"
fi
mv -f -- "$tmp_notes" "$notes_output"
trap - EXIT
notes_file="$notes_output"
backticked_ref_pattern=$'`#[0-9]+`'

if grep -Eq "$backticked_ref_pattern" "$notes_file"; then
  die "backticked issue/PR reference detected in release notes (use plain #123)"
fi
if grep -Eq '\.\.\.' "$notes_file"; then
  die "placeholder text detected in release notes (remove \"...\")"
fi

if ! gh auth status >/dev/null 2>&1; then
  die "gh auth status failed (run: gh auth login)"
fi

release_exists=0
if gh release view "$version" >/dev/null 2>&1; then
  release_exists=1
fi

if [[ "$release_exists" -eq 1 ]]; then
  if [[ "$if_exists" == "fail" ]]; then
    die "release already exists: $version"
  fi
  info "release $version exists; updating notes/body"
  gh release edit "$version" --title "$title" --notes-file "$notes_file" >/dev/null
else
  info "creating release $version"
  gh release create "$version" -F "$notes_file" --title "$title" --target "$head_sha" >/dev/null
fi

if (( verify_body )); then
  body_len="$(gh release view "$version" --json body --jq '.body | length' 2>/dev/null || true)"
  if [[ ! "$body_len" =~ ^[0-9]+$ ]]; then
    die "unable to verify release body length for $version"
  fi
  if [[ "$body_len" -le 0 ]]; then
    die "release body is empty for $version"
  fi
fi

release_url="$(gh release view "$version" --json url --jq '.url' 2>/dev/null || true)"
[[ -n "$release_url" ]] || die "unable to fetch release url for $version"
printf "%s\n" "$release_url"
