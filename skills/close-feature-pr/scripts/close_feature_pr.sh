#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  close_feature_pr.sh [--pr <number>]

What it does:
  - Ensures the progress file linked to the PR is archived under docs/progress/archived/
  - Merges the PR with a merge commit and deletes the feature branch
  - Updates the PR body "## Progress" link to point to the base branch (e.g. main)

Notes:
  - Requires: gh, git, python3
  - Run inside a git repo with a GitHub PR
USAGE
}

pr_number=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      pr_number="${2:-}"
      shift 2
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

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "error: rg is required" >&2
  exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: must run inside a git work tree" >&2
  exit 1
}

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

if [[ -z "$repo_full" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" ]]; then
  echo "error: failed to resolve PR metadata via gh" >&2
  exit 1
fi

progress_file=""

if [[ -d "docs/progress/archived" ]]; then
  progress_file="$(rg -l --fixed-string "$pr_url" docs/progress/archived 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$progress_file" && -d "docs/progress" ]]; then
  progress_file="$(rg -l --fixed-string "$pr_url" docs/progress 2>/dev/null | rg -v '^docs/progress/archived/' | head -n 1 || true)"
fi

if [[ -z "$progress_file" ]]; then
  echo "error: cannot find progress file containing PR URL: $pr_url" >&2
  echo "hint: expected it under docs/progress/ or docs/progress/archived/" >&2
  exit 1
fi

if [[ "$progress_file" == docs/progress/*.md && "$progress_file" != docs/progress/archived/* ]]; then
  filename="$(basename "$progress_file")"
  archived_path="docs/progress/archived/${filename}"

  python3 - "$progress_file" <<'PY'
import datetime
import re
import sys

path = sys.argv[1]
today = datetime.date.today().isoformat()

with open(path, "r", encoding="utf-8") as f:
  lines = f.readlines()

out = []
patched_status = False

for line in lines:
  if not patched_status and re.match(r"^\|\s*IN PROGRESS\s*\|", line):
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    if len(parts) == 3:
      out.append(f"| DONE | {parts[1]} | {today} |\n")
      patched_status = True
      continue
  out.append(line)

with open(path, "w", encoding="utf-8") as f:
  f.writelines(out)

if not patched_status:
  raise SystemExit(f"error: cannot patch Status table row in {path}")
PY

  git mv "$progress_file" "$archived_path"

  python3 - "$filename" <<'PY'
import sys

filename = sys.argv[1]
index_path = "docs/progress/README.md"

with open(index_path, "r", encoding="utf-8") as f:
  lines = f.readlines()

in_progress_start = None
archived_start = None
for i, line in enumerate(lines):
  if line.strip() == "### In progress":
    in_progress_start = i
  if line.strip() == "### Archived":
    archived_start = i

if in_progress_start is None or archived_start is None:
  raise SystemExit("error: cannot find '### In progress' / '### Archived' sections in docs/progress/README.md")

row_idx = None
row_line = None
for i in range(in_progress_start, archived_start):
  if f"({filename})" in lines[i]:
    row_idx = i
    row_line = lines[i]
    break

if row_idx is None:
  raise SystemExit(f"error: cannot find index row for {filename} under 'In progress'")

lines.pop(row_idx)
row_line = row_line.replace(f"({filename})", f"(archived/{filename})")

insert_at = None
for i in range(archived_start, len(lines)):
  if lines[i].startswith("| ---"):
    insert_at = i + 1
    break

if insert_at is None:
  raise SystemExit("error: cannot find archived table header separator")

lines.insert(insert_at, row_line)

with open(index_path, "w", encoding="utf-8") as f:
  f.writelines(lines)
PY

  if [[ -n "$(git status --porcelain=v1)" ]]; then
    git add "docs/progress/archived/${filename}" "docs/progress/README.md"
    git commit -m "docs(progress): archive ${filename%.md}"
    git push
  fi

  progress_file="$archived_path"
fi

gh pr merge "$pr_number" --merge --delete-branch --yes

progress_url="https://github.com/${repo_full}/blob/${base_branch}/${progress_file}"

tmp_file="$(mktemp)"
gh pr view "$pr_number" --json body -q .body >"$tmp_file"

python3 - "$tmp_file" "$progress_file" "$progress_url" <<'PY'
import sys

body_path, progress_path, progress_url = sys.argv[1], sys.argv[2], sys.argv[3]

with open(body_path, "r", encoding="utf-8") as f:
  body = f.read()

lines = body.splitlines()

def render_progress_section() -> list[str]:
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

echo "merged: https://github.com/${repo_full}/pull/${pr_number}" >&2
echo "progress: ${progress_url}" >&2
