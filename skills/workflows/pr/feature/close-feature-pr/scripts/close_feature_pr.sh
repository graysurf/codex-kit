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

normalize_progress_and_planning_sections() {
  local pr_number="${1:-}"
  if [[ -z "$pr_number" ]]; then
    return 0
  fi

  local tmp_in=''
  local tmp_out=''
  tmp_in="$(mktemp)"
  tmp_out="$(mktemp)"

  gh pr view "$pr_number" --json body -q .body >"$tmp_in"

python3 - "$tmp_in" "$tmp_out" <<'PY'
import sys

in_path, out_path = sys.argv[1], sys.argv[2]

with open(in_path, "r", encoding="utf-8") as handle:
  body = handle.read()

lines = [line.rstrip("\r") for line in body.splitlines()]

def find_section(heading):
  start = None
  for i, line in enumerate(lines):
    if line.strip() == heading:
      start = i
      break
  if start is None:
    return (None, None)
  end = len(lines)
  for j in range(start + 1, len(lines)):
    if lines[j].startswith("## "):
      end = j
      break
  return (start, end)

def section_content(start, end):
  if start is None or end is None:
    return []
  content = lines[start + 1 : end]
  return [c.strip() for c in content if c.strip() != ""]

def section_is_empty_or_none(content):
  if len(content) == 0:
    return True
  if len(content) != 1:
    return False
  value = content[0]
  if value.startswith("-"):
    value = value[1:].strip()
  value = value.strip()
  if value.startswith("`") and value.endswith("`") and len(value) >= 2:
    value = value[1:-1].strip()
  if value == "":
    return True
  return value.lower() == "none"

progress = find_section("## Progress")
planning = find_section("## Planning PR")

progress_exists = progress[0] is not None
planning_exists = planning[0] is not None

progress_invalid = progress_exists and section_is_empty_or_none(section_content(*progress))
planning_invalid = planning_exists and section_is_empty_or_none(section_content(*planning))

remove_progress = False
remove_planning = False

if progress_exists and planning_exists:
  # Progress metadata must be a pair. Keep both only when both are meaningful.
  if progress_invalid or planning_invalid:
    remove_progress = True
    remove_planning = True
elif progress_exists or planning_exists:
  # Partial pair is invalid for close-feature-pr hygiene.
  remove_progress = progress_exists
  remove_planning = planning_exists

sections_to_remove = []
if remove_progress:
  sections_to_remove.append(progress)
if remove_planning:
  sections_to_remove.append(planning)

new_lines = list(lines)
if sections_to_remove:
  # Delete in descending order to avoid index shifting.
  for start, end in sorted(sections_to_remove, key=lambda x: x[0], reverse=True):
    if start is None or end is None:
      continue
    del new_lines[start:end]

  cleaned = []
  prev_blank = False
  for line in new_lines:
    blank = line.strip() == ""
    if blank and prev_blank:
      continue
    cleaned.append(line)
    prev_blank = blank
  while cleaned and cleaned[0].strip() == "":
    cleaned.pop(0)
  new_lines = cleaned

  out = "\n".join(new_lines).rstrip() + "\n"
else:
  out = body
with open(out_path, "w", encoding="utf-8") as handle:
  handle.write(out)
PY

  if ! cmp -s "$tmp_in" "$tmp_out"; then
    gh pr edit "$pr_number" --body-file "$tmp_out"
  fi

  rm -f "$tmp_in" "$tmp_out"
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

pr_meta="$(gh pr view "${pr_view_args[@]}" --json url,baseRefName,headRefName,state -q '[.url, .baseRefName, .headRefName, .state] | @tsv')"
IFS=$'\t' read -r pr_url base_branch head_branch pr_state <<<"$pr_meta"

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

if [[ -z "$pr_number" || -z "$repo_full" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" || -z "$pr_state" ]]; then
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

normalize_progress_and_planning_sections "$pr_number"

merge_args=(--merge)
if [[ "$keep_branch" == "0" ]]; then
  merge_args+=(--delete-branch)
fi

if gh pr merge --help 2>/dev/null | grep -q -- "--yes"; then
  merge_args+=(--yes)
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
