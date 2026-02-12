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
  - Merges the planning PR (merge commit)
  - Best-effort deletes the remote head branch via `git push origin --delete` (unless --keep-branch)
  - Patches the planning PR body "## Progress" link to point to the base branch (survives branch deletion)
  - (Best-effort) Switches to the base branch, pulls, and deletes the local head branch (unless --no-cleanup or --keep-branch)

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

pr_body=""
pr_body_loaded="0"

load_pr_body() {
  if [[ "$pr_body_loaded" != "1" ]]; then
    pr_body="$(gh pr view "$pr_number" --json body -q .body)"
    pr_body_loaded="1"
  fi
}

write_pr_body_to_file() {
  local dest="$1"
  load_pr_body
  printf '%s' "$pr_body" >"$dest"
}

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

if [[ -z "$pr_number" || -z "$repo_full" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" || -z "$pr_state" ]]; then
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
  load_pr_body
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

if [[ ! "$progress_file" =~ ^docs/progress/.+\.md$ ]]; then
  echo "error: --progress-file must be a docs/progress/*.md path" >&2
  exit 1
fi

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

  if [[ "$pr_is_draft" == "true" ]]; then
    gh pr ready "$pr_number"
  fi

  merge_args=("$pr_number" --merge)
  if gh pr merge --help 2>/dev/null | grep -q -- "--yes"; then
    merge_args+=(--yes)
  fi
  gh pr merge "${merge_args[@]}"

  echo "merged: ${pr_url}" >&2
fi

progress_url="${repo_origin}/${repo_full}/blob/${base_branch}/${progress_file}"

tmp_file="$(mktemp)"
write_pr_body_to_file "$tmp_file"

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
echo "feature-pr-render-args: --from-progress-pr --planning-pr ${pr_number} --progress-url ${progress_url}" >&2

if [[ "$patch_only" == "0" && "$keep_branch" == "0" ]]; then
  if [[ "$head_branch" == "$base_branch" ]]; then
    echo "warning: head branch matches base branch (${head_branch}); skipping remote delete" >&2
  else
    git push origin --delete "$head_branch" >/dev/null 2>&1 || \
      echo "warning: failed to delete remote branch ${head_branch}; delete manually if needed" >&2
  fi
fi

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

if [[ "$keep_branch" == "0" ]] && git show-ref --verify --quiet "refs/heads/${head_branch}"; then
  git branch -d "$head_branch" || echo "warning: failed to delete local branch ${head_branch}; delete manually if needed" >&2
fi
