#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  handoff_progress_pr.sh [--pr <number>] [--progress-file <path>] [--patch-only]
                        [--keep-branch] [--no-cleanup] [--skip-checks]

What it does:
  - Resolves the planning PR number (or uses the current-branch PR)
  - Resolves the progress file path (prefer parsing PR body "## Progress"; fallback to --progress-file)
  - Merges the planning PR (merge commit) and deletes the remote head branch by default
  - Patches the planning PR body "## Progress" link to point to the base branch (survives branch deletion)
  - (Best-effort) Switches to the base branch, pulls, and deletes the local head branch (unless --no-cleanup)

Notes:
  - Requires: gh, git, python3
  - Run inside the target git repo (best: on the planning PR branch)
USAGE
}

pr_number=""
progress_file=""
patch_only="0"
keep_branch="0"
no_cleanup="0"
skip_checks="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      pr_number="${2:-}"
      shift 2
      ;;
    --progress-file)
      progress_file="${2:-}"
      shift 2
      ;;
    --patch-only)
      patch_only="1"
      shift
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

for cmd in gh git python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required" >&2
    exit 1
  fi
done

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

pr_url="$(gh pr view "$pr_number" --json url -q .url)"
pr_title="$(gh pr view "$pr_number" --json title -q .title)"
base_branch="$(gh pr view "$pr_number" --json baseRefName -q .baseRefName)"
head_branch="$(gh pr view "$pr_number" --json headRefName -q .headRefName)"
repo_full="$(gh pr view "$pr_number" --json baseRepository -q .baseRepository.nameWithOwner)"
pr_state="$(gh pr view "$pr_number" --json state -q .state)"

if [[ -z "$repo_full" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" || -z "$pr_state" ]]; then
  echo "error: failed to resolve PR metadata via gh" >&2
  exit 1
fi

repo_origin="$(python3 - "$pr_url" <<'PY'
from urllib.parse import urlparse
import sys

u = urlparse(sys.argv[1])
if not u.scheme or not u.netloc:
  raise SystemExit(1)
print(f"{u.scheme}://{u.netloc}")
PY
)"

resolve_progress_from_body() {
  local body="$1"
  python3 - "$body" <<'PY'
import re
import sys

body = sys.argv[1]
matches = re.findall(r"docs/progress/(?:archived/)?\d{8}_[A-Za-z0-9_-]+\.md", body)

unique = []
for m in matches:
  if m not in unique:
    unique.append(m)

if not unique:
  raise SystemExit(1)

if len(unique) > 1:
  print("error: multiple progress files found in PR body; use --progress-file to choose one:", file=sys.stderr)
  for m in unique:
    print(f"  - {m}", file=sys.stderr)
  raise SystemExit(2)

print(unique[0])
PY
}

if [[ -z "$progress_file" ]]; then
  pr_body="$(gh pr view "$pr_number" --json body -q .body)"
  set +e
  progress_from_body="$(resolve_progress_from_body "$pr_body")"
  rc=$?
  set -e
  if [[ "$rc" == "0" ]]; then
    progress_file="$progress_from_body"
  elif [[ "$rc" == "2" ]]; then
    exit 2
  fi
fi

if [[ -z "$progress_file" ]]; then
  echo "error: cannot resolve progress file from PR body; pass --progress-file docs/progress/<file>.md" >&2
  exit 1
fi

progress_file="${progress_file#./}"

if [[ "$patch_only" == "0" ]]; then
  if [[ -n "$(git status --porcelain=v1)" ]]; then
    echo "error: working tree is not clean; commit/stash first" >&2
    git status --porcelain=v1 >&2 || true
    exit 1
  fi

  if [[ "$pr_state" != "OPEN" ]]; then
    echo "error: PR is not OPEN (state=$pr_state); use --patch-only to patch links on a closed PR" >&2
    exit 1
  fi

  if [[ "$skip_checks" == "0" ]]; then
    gh pr checks "$pr_number"
  fi

  is_draft="$(gh pr view "$pr_number" --json isDraft -q .isDraft)"
  if [[ "$is_draft" == "true" ]]; then
    gh pr ready "$pr_number"
  fi

  merge_args=("$pr_number" --merge)
  if [[ "$keep_branch" == "0" ]]; then
    merge_args+=(--delete-branch)
  fi
  if gh pr merge --help 2>/dev/null | grep -q -- "--yes"; then
    merge_args+=(--yes)
  fi
  gh pr merge "${merge_args[@]}"

  echo "merged: ${pr_url}" >&2
fi

progress_url="${repo_origin}/${repo_full}/blob/${base_branch}/${progress_file}"

tmp_file="$(mktemp)"
gh pr view "$pr_number" --json body -q .body >"$tmp_file"

python3 - "$tmp_file" "$progress_file" "$progress_url" <<'PY'
import sys

body_path, progress_path, progress_url = sys.argv[1], sys.argv[2], sys.argv[3]

with open(body_path, "r", encoding="utf-8") as f:
  body = f.read()

lines = body.splitlines()

def render_progress_section():
  return [
    "## Progress",
    f"- [{progress_path}]({progress_url})",
    "",
  ]

start = None
end = None

for i, line in enumerate(lines):
  if line.strip() == "## Progress":
    start = i
    break

if start is not None:
  end = len(lines)
  for j in range(start + 1, len(lines)):
    if lines[j].startswith("## "):
      end = j
      break
  new_lines = lines[:start] + render_progress_section() + lines[end:]
else:
  new_lines = render_progress_section() + lines

with open(body_path, "w", encoding="utf-8") as f:
  f.write("\n".join(new_lines).rstrip() + "\n")
PY

gh pr edit "$pr_number" --body-file "$tmp_file"
rm -f "$tmp_file"

echo "progress: ${progress_url}" >&2

if [[ "$patch_only" == "1" || "$no_cleanup" == "1" ]]; then
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

