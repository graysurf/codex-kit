#!/usr/bin/env bash
#
# release.sh — agent-kit's curator-only release flow.
#
# Run from the repo root:
#   .agents/scripts/release.sh --version X.Y.Z [options]
#
# Curator-only model: this script does NOT auto-draft notes from git log.
# Authors are expected to keep `## [Unreleased]` in CHANGELOG.md up to date as
# work lands; release.sh promotes that body into the next version section,
# updates the footer compare-link block, commits, pushes main, and delegates
# the GitHub release publish step to the release-workflow skill helper.
#
# Flow:
#   1. preflight    — clean tree / on main / origin synced / version sane /
#                     [Unreleased] body non-empty / no existing [X.Y.Z]
#                     section / no existing tag
#   2. gate suite   — bash scripts/check.sh --all
#   3. promote      — rename `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD`,
#                     insert a fresh empty `## [Unreleased]` above, and update
#                     the footer compare-link block
#   4. confirm loop — y / e (edit in $EDITOR) / n
#   5. lint         — bash scripts/check.sh --markdown on the edited CHANGELOG
#   6. commit       — semantic-commit with the CHANGELOG edit
#   7. push main    — origin main
#   8. publish      — release-publish-from-changelog.sh creates the GitHub
#                     release (tag + notes) from the freshly promoted section
#
set -euo pipefail

SCRIPT_NAME="release.sh"

usage() {
  cat <<'USAGE'
Usage:
  .agents/scripts/release.sh --version X.Y.Z [options]

Required:
  --version X.Y.Z     Target release version (accepts leading 'v'; normalised).

Options:
  --dry-run           Print planned actions without mutating anything.
  --allow-dirty       Do not fail when the working tree is dirty.
  --skip-checks       Skip `bash scripts/check.sh --all`.
  --skip-push         Do not push main to origin (skips publish step too).
  --no-edit           Skip the $EDITOR review step.
  --yes, -y           Skip confirmation prompts (implies --no-edit).
  -h, --help          Show this help.

Env:
  EDITOR              Used for the optional review step (defaults to `vi`).

Notes:
  CHANGELOG.md `## [Unreleased]` body must be non-empty. Authors are expected
  to keep it current as work lands; release.sh does not auto-generate entries
  from git log. The publish step is delegated to
  skills/automation/release-workflow/scripts/release-publish-from-changelog.sh.
USAGE
}

# --- arg parse --------------------------------------------------------------

version=""
dry_run=0
allow_dirty=0
skip_checks=0
skip_push=0
no_edit=0
assume_yes=0

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --version) version="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --allow-dirty) allow_dirty=1; shift ;;
    --skip-checks) skip_checks=1; shift ;;
    --skip-push) skip_push=1; shift ;;
    --no-edit) no_edit=1; shift ;;
    --yes|-y) assume_yes=1; no_edit=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$version" ]] && { echo "error: --version is required" >&2; usage >&2; exit 2; }
version="${version#v}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo "error: invalid semver: $version (expect X.Y.Z[-pre])" >&2
  exit 2
fi
tag="v$version"

# --- helpers ---------------------------------------------------------------

log()    { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn()   { printf '[%s] WARN: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die()    { printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

require_cmd() {
  local cmd="$1"; local hint="${2:-}"
  command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd${hint:+ — $hint}"
}

confirm() {
  local prompt="$1"
  if [[ "$assume_yes" -eq 1 ]]; then
    return 0
  fi
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# --- preflight -------------------------------------------------------------

require_cmd git
require_cmd gh   "brew install gh"
require_cmd awk
require_cmd semantic-commit "brew install nils-cli"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$repo_root" ]] && die "must run inside a git work tree"
cd "$repo_root"

[[ -f CHANGELOG.md ]] || die "CHANGELOG.md missing at $repo_root"

publish_script="skills/automation/release-workflow/scripts/release-publish-from-changelog.sh"
[[ -x "$publish_script" ]] || die "$publish_script missing or not executable"

current_branch="$(git symbolic-ref --short -q HEAD 2>/dev/null || true)"
[[ "$current_branch" == "main" ]] || die "must be on main (currently: ${current_branch:-<detached>})"

if [[ "$allow_dirty" -eq 0 ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    die "working tree is dirty; commit or stash first, or rerun with --allow-dirty"
  fi
fi

git fetch origin --quiet
local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse origin/main)"
if [[ "$local_head" != "$remote_head" ]]; then
  ahead="$(git rev-list --count "$remote_head..$local_head")"
  behind="$(git rev-list --count "$local_head..$remote_head")"
  die "main is not in sync with origin/main (ahead=$ahead behind=$behind); push or rebase first"
fi

if grep -qE "^## \[${version//./\\.}\]" CHANGELOG.md; then
  die "CHANGELOG.md already has a [$version] section; abort"
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  die "local tag $tag already exists"
fi
if git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null | grep -q "refs/tags/$tag"; then
  die "remote tag $tag already exists"
fi

# --- gate: [Unreleased] body must be non-empty ----------------------------

unreleased_body="$(awk '
  /^## \[Unreleased\]/ { in_block=1; next }
  /^## \[/ && in_block { exit }
  in_block { print }
' CHANGELOG.md | sed '/^[[:space:]]*$/d')"

if [[ -z "$unreleased_body" ]]; then
  die "CHANGELOG.md ## [Unreleased] body is empty — write release notes there before invoking release.sh (curator-only model: release.sh does not auto-generate notes)"
fi

if [[ "$skip_checks" -eq 0 ]]; then
  log "running full gate suite (scripts/check.sh --all)..."
  bash scripts/check.sh --all >/dev/null || die "scripts/check.sh --all failed — fix or rerun with --skip-checks"
  log "all gates green"
fi

# --- promote [Unreleased] -> [X.Y.Z] --------------------------------------

today="$(date +%Y-%m-%d)"
backup="$(mktemp -t CHANGELOG.orig.XXXXXX)"
cp CHANGELOG.md "$backup"
trap 'rm -f "$backup"' EXIT

promote_section() {
  local target="$1"
  awk -v version="$version" -v today="$today" '
    BEGIN { promoted = 0 }
    /^## \[Unreleased\]/ && !promoted {
      print "## [Unreleased]"
      print ""
      print "## [" version "] - " today
      promoted = 1
      next
    }
    { print }
  ' CHANGELOG.md > "$target"
}

update_links() {
  local target="$1"
  awk -v version="$version" '
    /^\[unreleased\]:/ {
      sub(/compare\/v[^.]+\.[^.]+\.[^.]+(\.\.\.HEAD|\.\.\.main)?/, "compare/v" version "...HEAD")
      print
      print "[" version "]: https://github.com/graysurf/agent-kit/releases/tag/v" version
      next
    }
    { print }
  ' "$target" > "$target.tmp"
  mv "$target.tmp" "$target"
}

if [[ "$dry_run" -eq 1 ]]; then
  tmp_preview="$(mktemp -t CHANGELOG.preview.XXXXXX)"
  trap 'rm -f "$backup" "$tmp_preview"' EXIT
  promote_section "$tmp_preview"
  cp "$tmp_preview" CHANGELOG.md
  update_links CHANGELOG.md
  log "[dry-run] proposed CHANGELOG.md changes:"
  printf -- '---\n'
  git --no-pager diff -- CHANGELOG.md | sed '/^[^-+@]/d'
  printf -- '---\n'
  cp "$backup" CHANGELOG.md
  log "[dry-run] would commit + push + publish via $publish_script"
  exit 0
fi

tmp_changelog="$(mktemp -t CHANGELOG.new.XXXXXX)"
trap 'rm -f "$backup" "$tmp_changelog"' EXIT
promote_section "$tmp_changelog"
mv "$tmp_changelog" CHANGELOG.md
update_links CHANGELOG.md

# --- confirm loop ---------------------------------------------------------

show_diff() {
  git --no-pager diff -- CHANGELOG.md | sed '/^[^-+@]/d' | head -200 || true
}

restore_and_abort() {
  cp "$backup" CHANGELOG.md
  die "aborted; CHANGELOG.md restored"
}

while :; do
  echo
  log "proposed CHANGELOG.md changes for v$version:"
  echo "--------------------------------------------------------------------"
  show_diff
  echo "--------------------------------------------------------------------"

  if [[ "$assume_yes" -eq 1 ]]; then
    break
  fi

  read -r -p "proceed? [y=yes / e=edit in \$EDITOR / n=abort] " reply
  case "$reply" in
    [yY]) break ;;
    [nN]) restore_and_abort ;;
    [eE])
      if [[ "$no_edit" -eq 1 ]]; then
        warn "--no-edit set; not opening editor"
        continue
      fi
      "${EDITOR:-vi}" CHANGELOG.md
      ;;
    *) echo "(answer y, e, or n)" ;;
  esac
done

# --- lint the edited CHANGELOG before committing --------------------------

log "re-running markdown lint on CHANGELOG.md..."
if ! bash scripts/check.sh --markdown >/dev/null; then
  warn "markdown lint failed; open \$EDITOR to fix?"
  if confirm "open editor?"; then
    "${EDITOR:-vi}" CHANGELOG.md
  else
    restore_and_abort
  fi
fi

# --- commit, push, publish ------------------------------------------------

commit_subject="docs(changelog): cut v$version release notes"
commit_body="- Promote curated [Unreleased] body to [$version] - $today."

log "committing CHANGELOG.md via semantic-commit..."
git add CHANGELOG.md
semantic-commit commit --message "$(printf '%s\n\n%s\n' "$commit_subject" "$commit_body")"

if [[ "$skip_push" -eq 1 ]]; then
  log "--skip-push set; stopping before push and publish."
  log "  to publish later: git push origin main && $publish_script --repo . --version v$version"
  exit 0
fi

log "pushing main to origin..."
git push origin main

log "publishing GitHub release via $publish_script..."
"$publish_script" --repo . --version "v$version"

log "done."
