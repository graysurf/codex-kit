#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  close_progress_pr.sh [--pr <number>] [--progress-file <path>] [--no-merge]

What it does:
  - Resolves the progress file path (prefer parsing PR body "## Progress"; fallback to scanning docs/progress by PR URL)
  - Fail-fast if any unchecked checklist item in "## Steps (Checklist)" lacks a Reason (excluding Step 4 “Release / wrap-up”)
  - Sets progress Status to DONE and updates the Updated date
  - Sets the progress "Links -> PR" to the PR URL
  - Moves the progress file to docs/progress/archived/
  - Best-effort updates docs/progress/README.md index
  - Commits + pushes the changes on the PR head branch
  - Merges the PR (merge commit) and deletes the head branch (unless --no-merge)
  - Patches the PR body "## Progress" link to point to the base branch
  - If the progress file has "Links -> Planning PR", patches that PR body to include an "## Implementation" section linking to this PR

Notes:
  - Requires: gh, git, python3
  - Run inside the target git repo, ideally already on the PR head branch
USAGE
}

pr_number=""
progress_file=""
merge_pr="1"

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
    --no-merge)
      merge_pr="0"
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

if [[ -n "$(git status --porcelain=v1)" ]]; then
  echo "error: working tree is not clean; commit/stash first" >&2
  git status --porcelain=v1 >&2 || true
  exit 1
fi

pr_meta="$(gh pr view "$pr_number" --json url,title,baseRefName,headRefName,state -q '[.url, .title, .baseRefName, .headRefName, .state] | @tsv')"
IFS=$'\t' read -r pr_url pr_title base_branch head_branch pr_state <<<"$pr_meta"

repo_origin="$(python3 - "$pr_url" <<'PY'
from urllib.parse import urlparse
import sys

u = urlparse(sys.argv[1])
if not u.scheme or not u.netloc:
  raise SystemExit(1)
print(f"{u.scheme}://{u.netloc}")
PY
)"

repo_full="$(python3 - "$pr_url" <<'PY'
from urllib.parse import urlparse
import sys

path = urlparse(sys.argv[1]).path.strip("/")
parts = path.split("/")
if len(parts) < 4 or parts[2] != "pull":
  raise SystemExit(1)
print(parts[0] + "/" + parts[1])
PY
)"

if [[ -z "$repo_full" || -z "$repo_origin" || -z "$base_branch" || -z "$head_branch" || -z "$pr_url" || -z "$pr_state" ]]; then
  echo "error: failed to resolve PR metadata via gh" >&2
  exit 1
fi

if [[ "$pr_state" != "OPEN" ]]; then
  echo "error: PR is not OPEN (state=$pr_state); this script is intended to run before merge" >&2
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "$head_branch" ]]; then
  echo "error: current branch ($current_branch) != PR head branch ($head_branch)" >&2
  echo "hint: run: gh pr checkout $pr_number" >&2
  exit 1
fi

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

if [[ -z "$progress_file" && -d "docs/progress" ]]; then
  progress_file="$(python3 - "$pr_url" <<'PY'
import sys
from pathlib import Path

needle = sys.argv[1]
root = Path("docs/progress")

if not root.is_dir():
  raise SystemExit(0)

for path in sorted(root.rglob("*.md"), key=lambda p: str(p)):
  try:
    if needle in path.read_text(encoding="utf-8", errors="ignore"):
      print(path.as_posix())
      raise SystemExit(0)
  except OSError:
    continue
PY
)"
fi

if [[ -z "$progress_file" ]]; then
  echo "error: cannot resolve progress file for PR $pr_number" >&2
  echo "hint: ensure PR body contains a docs/progress link under '## Progress', or pass --progress-file" >&2
  echo "hint: or ensure the progress file contains the PR URL under Links -> PR" >&2
  echo "hint: if this PR is not progress-tracked (e.g. '## Progress' is 'None'), use close-feature-pr instead" >&2
  exit 1
fi

progress_file="${progress_file#./}"

if [[ ! -f "$progress_file" ]]; then
  filename="$(basename "$progress_file")"
  if [[ -f "docs/progress/${filename}" ]]; then
    progress_file="docs/progress/${filename}"
  elif [[ -f "docs/progress/archived/${filename}" ]]; then
    progress_file="docs/progress/archived/${filename}"
  else
    echo "error: progress file does not exist in repo: $progress_file" >&2
    exit 1
  fi
fi

filename="$(basename "$progress_file")"
archived_path="docs/progress/archived/${filename}"

validate_checklist() {
  python3 - "$1" <<'PY'
import re
import sys

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
  lines = f.read().splitlines()

start = None
for i, line in enumerate(lines):
  if line.strip() == "## Steps (Checklist)":
    start = i + 1
    break

if start is None:
  raise SystemExit(f"error: cannot find '## Steps (Checklist)' in {path}")

end = len(lines)
for i in range(start, len(lines)):
  if lines[i].startswith("## "):
    end = i
    break

checkbox_re = re.compile(r"^(\s*)-\s*\[(?P<mark>[ xX])\]\s+.+$")
step_re = re.compile(r"^\s*-\s*\[[ xX]\]\s*Step\s+(?P<num>\d+):")
missing = []
in_code_block = False
current_step = None

# Step 4 ("Release / wrap-up") is intentionally excluded from Reason checks because it includes post-merge tasks.
exempt_step_min = 4

for i in range(start, end):
  line = lines[i]
  if line.strip().startswith("```"):
    in_code_block = not in_code_block
    continue
  if in_code_block:
    continue

  m_step = step_re.match(line)
  if m_step:
    try:
      current_step = int(m_step.group("num"))
    except ValueError:
      current_step = None

  m = checkbox_re.match(line)
  if not m or m.group("mark") != " ":
    continue
  if current_step is not None and current_step >= exempt_step_min:
    continue
  if "reason:" in line.lower():
    continue
  found = False
  for j in range(i + 1, end):
    next_line = lines[j]
    if checkbox_re.match(next_line):
      break
    if "reason:" in next_line.lower():
      found = True
      break
  if not found:
    missing.append((i + 1, line.rstrip()))

if missing:
  print("error: unchecked checklist items in '## Steps (Checklist)' require a Reason:", file=sys.stderr)
  for lineno, text in missing:
    print(f"  - {path}:{lineno}: {text}", file=sys.stderr)
  print("hint: add 'Reason: ...' to the same line or a following line before the next checkbox.", file=sys.stderr)
  raise SystemExit(1)
PY
}

validate_checklist "$progress_file"

today="$(date +%Y-%m-%d)"

python3 - "$progress_file" "$today" "$pr_url" "$archived_path" <<'PY'
import os
import re
import sys

path, today, pr_url, archived_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(path, "r", encoding="utf-8") as f:
  lines = f.readlines()

patched_status = False
patched_pr = False
patched_docs = False
patched_glossary = False

repo_root = os.getcwd()

final_dir = os.path.dirname(archived_path)
final_dir_abs = os.path.normpath(os.path.join(repo_root, final_dir))

md_link_re = re.compile(r"^\[(?P<text>[^\]]+)\]\((?P<href>[^)]+)\)$")
backtick_re = re.compile(r"^`(?P<path>[^`]+)`$")


def is_url(value: str) -> bool:
  return value.startswith("http://") or value.startswith("https://")


def normalize_link_value(raw_value: str, label: str) -> str:
  raw_value = raw_value.strip()
  if raw_value in ("None", "TBD"):
    return raw_value

  m = md_link_re.match(raw_value)
  if m:
    text = m.group("text").strip()
    href = m.group("href").strip()
    if is_url(href):
      return f"[{text}]({href})"

    if href.startswith("../") or href.startswith("./"):
      target_abs = os.path.normpath(os.path.join(final_dir_abs, href))
      rel = href
    else:
      target_abs = os.path.normpath(os.path.join(repo_root, href))
      rel = os.path.relpath(target_abs, start=final_dir_abs).replace(os.sep, "/")

    if not os.path.exists(target_abs):
      raise SystemExit(f"error: cannot resolve Links -> {label} target path: {href}")

    display = text or href
    return f"[{display}]({rel})"

  m = backtick_re.match(raw_value)
  if m:
    raw_value = m.group("path").strip()

  if is_url(raw_value):
    return f"[{raw_value}]({raw_value})"

  if raw_value.startswith("../") or raw_value.startswith("./"):
    target_abs = os.path.normpath(os.path.join(final_dir_abs, raw_value))
    rel = raw_value
  else:
    target_abs = os.path.normpath(os.path.join(repo_root, raw_value))
    rel = os.path.relpath(target_abs, start=final_dir_abs).replace(os.sep, "/")

  if not os.path.exists(target_abs):
    raise SystemExit(f"error: cannot resolve Links -> {label} target path: {raw_value}")

  return f"[{raw_value}]({rel})"

new_lines = []

for line in lines:
  m = re.match(r"^\|\s*(DRAFT|IN PROGRESS|DONE)\s*\|\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\s*\|\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\s*\|\s*$", line)
  if m and not patched_status:
    created = m.group(2)
    new_lines.append(f"| DONE | {created} | {today} |\n")
    patched_status = True
    continue

  if line.startswith("- PR:") and not patched_pr:
    expanded = line.replace("\\n", "\n")
    expanded_lines = expanded.splitlines(keepends=True)
    new_lines.append(f"- PR: {pr_url}\n")
    if len(expanded_lines) > 1:
      new_lines.extend(expanded_lines[1:])
    patched_pr = True
    continue

  if line.startswith("- Docs:") and not patched_docs:
    value = line.split(":", 1)[1].strip()
    normalized = normalize_link_value(value, "Docs")
    new_lines.append(f"- Docs: {normalized}\n")
    patched_docs = True
    continue

  if line.startswith("- Glossary:") and not patched_glossary:
    value = line.split(":", 1)[1].strip()
    normalized = normalize_link_value(value, "Glossary")
    new_lines.append(f"- Glossary: {normalized}\n")
    patched_glossary = True
    continue

  new_lines.append(line)

lines = new_lines

with open(path, "w", encoding="utf-8") as f:
  f.writelines(lines)

if not patched_status:
  raise SystemExit(f"error: cannot patch Status table row in {path}")
if not patched_pr:
  raise SystemExit(f"error: cannot patch Links -> PR line in {path}")
if not patched_docs:
  raise SystemExit(f"error: cannot patch Links -> Docs line in {path}")
if not patched_glossary:
  raise SystemExit(f"error: cannot patch Links -> Glossary line in {path}")
PY

if [[ "$progress_file" == docs/progress/*.md && "$progress_file" != docs/progress/archived/* ]]; then
  mkdir -p "docs/progress/archived"
  if git ls-files --error-unmatch "$progress_file" >/dev/null 2>&1; then
    git mv "$progress_file" "$archived_path"
  else
    mv "$progress_file" "$archived_path"
  fi
  progress_file="$archived_path"
fi

extract_title() {
  python3 - "$1" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
  for line in f:
    line = line.rstrip("\n")
    if line.startswith("# "):
      h1 = line[2:].strip()
      if ": " in h1:
        return_title = h1.split(": ", 1)[1].strip()
      else:
        return_title = h1
      print(return_title)
      raise SystemExit(0)

print("Progress", file=sys.stderr)
raise SystemExit(0)
PY
}

title="$(extract_title "$progress_file")"

if [[ -f "docs/progress/README.md" ]]; then
  python3 - "docs/progress/README.md" "$filename" "$title" "$pr_url" "$pr_number" <<'PY'
import datetime
import re
import sys

index_path, filename, title, pr_url, pr_number = sys.argv[1:]

yyyymmdd = filename.split("_", 1)[0]
try:
  date_iso = datetime.datetime.strptime(yyyymmdd, "%Y%m%d").date().isoformat()
except ValueError:
  date_iso = "TBD"

pr_cell = f"[#{pr_number}]({pr_url})"

with open(index_path, "r", encoding="utf-8") as f:
  lines = f.readlines()

in_progress_start = None
archived_start = None

for i, line in enumerate(lines):
  if line.strip() == "## In progress":
    in_progress_start = i
  if line.strip() == "## Archived":
    archived_start = i

if in_progress_start is None or archived_start is None:
  print("warning: cannot find '## In progress' / '## Archived' sections in docs/progress/README.md; skipping index update", file=sys.stderr)
  raise SystemExit(0)

def find_table_sep(start, end):
  for i in range(start, end):
    if lines[i].startswith("| ---"):
      return i
  return None

in_sep = find_table_sep(in_progress_start, archived_start)
arch_sep = find_table_sep(archived_start, len(lines))

if in_sep is None or arch_sep is None:
  print("warning: cannot find progress index table headers; skipping index update", file=sys.stderr)
  raise SystemExit(0)

def row_cells(row_line):
  return [p.strip() for p in row_line.strip().strip("|").split("|")]

def render_row(feature_cell):
  return f"| {date_iso} | {feature_cell} | {pr_cell} |\n"

def normalize_feature_cell(cell):
  cell = cell.replace(f"(docs/progress/{filename})", f"(docs/progress/archived/{filename})")
  cell = cell.replace(f"({filename})", f"(archived/{filename})")
  return cell

def sort_table_rows(sep_idx: int):
  row_start = sep_idx + 1
  row_end = row_start
  rows = []

  while row_end < len(lines) and lines[row_end].startswith("|"):
    if lines[row_end].startswith("| ---"):
      row_end += 1
      continue
    rows.append(lines[row_end])
    row_end += 1

  if not rows:
    return

  def sort_key(row_line: str):
    cells = row_cells(row_line)
    date_cell = cells[0].strip() if len(cells) >= 1 else ""
    pr_cell = cells[2].strip() if len(cells) >= 3 else ""

    try:
      date_ord = datetime.date.fromisoformat(date_cell).toordinal()
    except ValueError:
      date_ord = -1

    m = re.search(r"#(?P<num>\\d+)", pr_cell)
    pr_num = int(m.group("num")) if m else -1

    return (date_ord, pr_num, row_line)

  rows_sorted = sorted(rows, key=sort_key, reverse=True)
  lines[row_start:row_end] = rows_sorted

# Try to find an existing row (prefer In progress, then Archived) that mentions the filename.
in_row_idx = None
in_row_line = None
for i in range(in_sep + 1, archived_start):
  if lines[i].startswith("|") and filename in lines[i]:
    in_row_idx = i
    in_row_line = lines[i]
    break

arch_row_idx = None
arch_row_line = None
for i in range(arch_sep + 1, len(lines)):
  if lines[i].startswith("|") and filename in lines[i]:
    arch_row_idx = i
    arch_row_line = lines[i]
    break

feature_cell = title

if in_row_line:
  cells = row_cells(in_row_line)
  if len(cells) >= 2 and cells[1]:
    feature_cell = cells[1]
  feature_cell = normalize_feature_cell(feature_cell)
  lines.pop(in_row_idx)

if arch_row_line:
  cells = row_cells(arch_row_line)
  if len(cells) >= 2 and cells[1]:
    feature_cell = cells[1]
  feature_cell = normalize_feature_cell(feature_cell)
  lines[arch_row_idx] = render_row(feature_cell)
else:
  feature_cell = f"[{title}](archived/{filename})"
  insert_at = arch_sep + 1
  lines.insert(insert_at, render_row(feature_cell))

sort_table_rows(in_sep)
sort_table_rows(arch_sep)

with open(index_path, "w", encoding="utf-8") as f:
  f.writelines(lines)
PY
fi

if [[ -n "$(git status --porcelain=v1)" ]]; then
  git add "$progress_file"
  if [[ -f "docs/progress/README.md" ]]; then
    git add "docs/progress/README.md"
  fi
  git commit -m "docs(progress): archive ${filename%.md}"
  git push
fi

if [[ "$merge_pr" == "1" ]]; then
  is_draft="$(gh pr view "$pr_number" --json isDraft -q .isDraft)"
  if [[ "$is_draft" == "true" ]]; then
    gh pr ready "$pr_number"
  fi

  merge_args=("$pr_number" --merge --delete-branch)
  if gh pr merge --help 2>/dev/null | grep -q -- "--yes"; then
    merge_args+=(--yes)
  fi
  gh pr merge "${merge_args[@]}"

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

  set +e
  planning_pr_number="$(python3 - "$progress_file" <<'PY'
import re
import sys
from urllib.parse import urlparse

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
  text = f.read()

m = re.search(r"^\\s*-\\s*Planning PR:\\s*(?P<value>.+?)\\s*$", text, re.M)
if not m:
  raise SystemExit(1)

value = m.group("value").strip()
u = re.search(r"https?://[^ )]+", value)
if not u:
  raise SystemExit(2)

pr_path = urlparse(u.group(0)).path
m_num = re.search(r"/pull/(?P<num>\\d+)", pr_path)
if not m_num:
  raise SystemExit(2)

print(m_num.group("num"))
PY
)"
  rc=$?
  set -e

  if [[ "$rc" == "2" ]]; then
    echo "error: cannot parse 'Links -> Planning PR' from ${progress_file}" >&2
    exit 1
  fi

  if [[ "$rc" == "0" && -n "$planning_pr_number" && "$planning_pr_number" != "$pr_number" ]]; then
    planning_tmp_file="$(mktemp)"
    gh pr view "$planning_pr_number" --json body -q .body >"$planning_tmp_file"

    python3 - "$planning_tmp_file" "$progress_file" "$progress_url" "$pr_number" "$pr_title" "$pr_url" <<'PY'
import sys

body_path, progress_path, progress_url, impl_num, impl_title, impl_url = sys.argv[1:]

with open(body_path, "r", encoding="utf-8") as f:
  body = f.read()

lines = [line.rstrip("\r") for line in body.splitlines()]

def find_section(heading: str):
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

def render_progress_section():
  return [
    "## Progress",
    f"- [{progress_path}]({progress_url})",
    "",
  ]

def render_implementation_section():
  return [
    "## Implementation",
    f"- #{impl_num}",
    "",
  ]

progress_section = render_progress_section()
impl_section = render_implementation_section()

start, end = find_section("## Progress")
if start is None:
  lines = progress_section + lines
  progress_end = len(progress_section)
else:
  lines = lines[:start] + progress_section + lines[end:]
  progress_end = start + len(progress_section)

start, end = find_section("## Implementation")
if start is None:
  lines = lines[:progress_end] + impl_section + lines[progress_end:]
else:
  lines = lines[:start] + impl_section + lines[end:]

with open(body_path, "w", encoding="utf-8") as f:
  f.write("\n".join(lines).rstrip() + "\n")
PY

    gh pr edit "$planning_pr_number" --body-file "$planning_tmp_file"
    rm -f "$planning_tmp_file"
  fi

  echo "merged: ${pr_url}" >&2
  echo "progress: ${progress_url}" >&2
else
  echo "progress: ${progress_file}" >&2
fi
