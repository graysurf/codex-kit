#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "release-audit: $1" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  release-audit.sh --version <vX.Y.Z> [--repo <path>] [--branch <name>] [--changelog <path>] [--strict]

Checks:
  - Git repo present and working tree is clean
  - Optional: current branch matches --branch
  - Tag <version> does not already exist locally
  - CHANGELOG.md contains a "## <version> - YYYY-MM-DD" entry with required sections
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
repo_template=""

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

cd "$repo" || die "unable to cd: $repo"

if ! command -v git >/dev/null 2>&1; then
  die "git is required"
fi

if [[ -f "docs/templates/RELEASE_TEMPLATE.md" ]]; then
  repo_template="docs/templates/RELEASE_TEMPLATE.md"
  say_ok "repo template present: $repo_template"
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

if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
  say_fail "working tree not clean (commit/stash changes first)"
else
  say_ok "working tree clean"
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
    if [[ -z "$repo_template" ]]; then
      for section in "### Added" "### Changed" "### Fixed"; do
        if [[ "$notes" != *$'\n'"$section"$'\n'* ]]; then
          say_fail "missing required section: $section"
        fi
      done
    fi

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
