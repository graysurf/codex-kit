#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-audit: $1" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-audit.sh --version <vX.Y.Z> [--repo <path>] [--branch <name>] [--changelog <path>] [--allow-dirty-path <path>] [--strict]

Checks:
  - Git repo present and working tree is clean (or only dirty in allowed paths)
  - Optional: current branch matches --branch
  - Tag <version> does not already exist locally
  - CHANGELOG.md contains a "## <version> - YYYY-MM-DD" entry (empty None sections removed)
  - GitHub CLI auth status (when gh is installed)

Exit:
  - 0 when all checks pass
  - 1 when any check fails
  - 2 on usage error
EOF
}

repo="."
branch=""
version=""
changelog="CHANGELOG.md"
strict=0
allow_dirty_paths=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --branch)
      branch="${2:-}"
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
    --allow-dirty-path)
      allow_dirty_paths+=("${2:-}")
      shift 2
      ;;
    --strict)
      strict=1
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

failed=0
warned=0

say_ok() { printf "ok: %s\n" "$1"; }
say_fail() { printf "fail: %s\n" "$1" >&2; failed=1; }
say_warn() { printf "warn: %s\n" "$1" >&2; warned=1; }

normalize_repo_path() {
  local path="${1:-}"
  local repo_root="${2:-}"
  path="${path#./}"
  if [[ -n "$repo_root" && "$path" == "$repo_root/"* ]]; then
    path="${path#"$repo_root/"}"
  fi
  path="${path%/}"
  printf "%s" "$path"
}

is_allowed_dirty_path() {
  local candidate="${1:-}"
  local allowed=''
  for allowed in "${allow_dirty_paths[@]-}"; do
    [[ -n "$allowed" ]] || continue
    if [[ "$candidate" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

cd "$repo" || die "unable to cd: $repo"

if ! command -v git >/dev/null 2>&1; then
  die "git is required"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "not a git repository: $repo"
fi

if [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  say_ok "version format: $version"
else
  if (( strict )); then
    say_fail "version format invalid (expected vX.Y.Z): $version"
  else
    say_warn "version format unusual (expected vX.Y.Z): $version"
  fi
fi

typeset -a allow_dirty_paths_normalized=()
repo_root="$(pwd -P)"
for allow_dirty_path in "${allow_dirty_paths[@]-}"; do
  [[ -n "$allow_dirty_path" ]] || continue
  normalized_allow_path="$(normalize_repo_path "$allow_dirty_path" "$repo_root")"
  if [[ -z "$normalized_allow_path" || "$normalized_allow_path" == "." ]]; then
    say_fail "invalid --allow-dirty-path value: $allow_dirty_path"
    continue
  fi
  allow_dirty_paths_normalized+=("$normalized_allow_path")
done
allow_dirty_paths=("${allow_dirty_paths_normalized[@]-}")

dirty_status="$(git status --porcelain 2>/dev/null || true)"
if [[ -z "$dirty_status" ]]; then
  say_ok "working tree clean"
else
  if [[ -z "${allow_dirty_paths[*]-}" ]]; then
    say_fail "working tree not clean (commit/stash changes first)"
  else
    typeset -a unexpected_dirty_paths=()
    while IFS= read -r dirty_line; do
      [[ -n "$dirty_line" ]] || continue
      dirty_path="${dirty_line:3}"
      dirty_path="${dirty_path# }"
      if [[ "$dirty_path" == *" -> "* ]]; then
        dirty_path="${dirty_path##* -> }"
      fi
      dirty_path="${dirty_path#\"}"
      dirty_path="${dirty_path%\"}"
      dirty_path="$(normalize_repo_path "$dirty_path" "$repo_root")"
      if [[ -z "$dirty_path" || "$dirty_path" == "." ]]; then
        continue
      fi
      if ! is_allowed_dirty_path "$dirty_path"; then
        unexpected_dirty_paths+=("$dirty_path")
      fi
    done <<< "$dirty_status"

    if [[ -n "${unexpected_dirty_paths[*]-}" ]]; then
      unexpected_joined="$(printf '%s, ' "${unexpected_dirty_paths[@]-}")"
      unexpected_joined="${unexpected_joined%, }"
      say_fail "working tree has unexpected changes: $unexpected_joined"
    else
      allowed_joined="$(printf '%s, ' "${allow_dirty_paths[@]-}")"
      allowed_joined="${allowed_joined%, }"
      say_ok "working tree changes limited to allowed paths: $allowed_joined"
    fi
  fi
fi

current_branch="$(git branch --show-current 2>/dev/null || true)"
if [[ -n "$branch" ]]; then
  if [[ "$current_branch" != "$branch" ]]; then
    say_fail "branch mismatch (current=$current_branch expected=$branch)"
  else
    say_ok "on branch $branch"
  fi
else
  if [[ -n "$current_branch" ]]; then
    say_ok "current branch: $current_branch"
  else
    say_warn "unable to detect current branch"
  fi
fi

if git show-ref --tags --verify --quiet "refs/tags/$version" 2>/dev/null; then
  say_fail "tag already exists: $version"
else
  say_ok "tag not present: $version"
fi

if [[ ! -f "$changelog" ]]; then
  say_fail "changelog not found: $changelog"
else
  say_ok "changelog present: $changelog"
fi

if [[ -f "$changelog" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  audit_changelog="${script_dir}/audit-changelog.zsh"
  if [[ -x "$audit_changelog" ]]; then
    if (( strict )); then
      if "$audit_changelog" --repo . --changelog "$changelog" --check; then
        say_ok "audit-changelog --check"
      else
        say_fail "audit-changelog --check failed"
      fi
    else
      "$audit_changelog" --repo . --changelog "$changelog" || say_warn "audit-changelog errored"
      say_ok "audit-changelog (non-strict)"
    fi
  else
    say_warn "audit-changelog script not found; skipping"
  fi

  if ! grep -qF "## ${version} - " "$changelog"; then
    say_fail "missing changelog heading: ## ${version} - YYYY-MM-DD"
  else
    say_ok "changelog entry exists: $version"
  fi

  notes="$(
    awk -v v="$version" '
      $0 ~ "^## " v " " { f=1; heading=NR }
      f {
        if (NR > heading && $0 ~ "^## ") { exit }
        print
      }
    ' "$changelog" 2>/dev/null || true
  )"

  if [[ -z "$notes" ]]; then
    say_fail "unable to extract notes for $version from $changelog"
  else
    if [[ "$notes" == *"- ..."* || "$notes" == *"..."* ]]; then
      if (( strict )); then
        say_fail "placeholder text detected (remove \"...\" placeholders before publishing)"
      else
        say_warn "placeholder text detected (fill out release notes before publishing)"
      fi
    fi
  fi
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    say_ok "gh auth status"
  else
    say_fail "gh auth status failed (run: gh auth login)"
  fi
else
  say_warn "gh not installed; skipping gh auth check"
fi

if (( failed )); then
  exit 1
fi

if (( warned )); then
  exit 0
fi

exit 0
