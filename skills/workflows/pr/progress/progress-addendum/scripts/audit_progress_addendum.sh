#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  audit_progress_addendum.sh [options]

Audits:
  - DONE progress files under docs/progress/** for canonical Addendum placement:
    - `## Addendum` must be the first `## ...` section after `Links:`
  - Addendum content shape:
    - Either `- None`, OR contains at least one `### YYYY-MM-DD` entry heading

Options:
  --require-addendum   Fail if a DONE progress file has no `## Addendum` section
  --check-updated      When Addendum has dated entries, require header `Updated` >= max entry date
  --require-links      When Addendum has dated entries, require each entry to include a `- Links:` bullet
  --require-progress-link
                      When Addendum has dated entries, require each entry to reference a progress file (e.g. `20260114_some-slug.md`)

Notes:
  - Run inside the target git repo (any subdir is fine).
  - Success: exit 0, no output. Failure: non-zero, errors on stderr.
USAGE
}

require_addendum="0"
check_updated="0"
require_links="0"
require_progress_link="0"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --require-addendum)
      require_addendum="1"
      shift
      ;;
    --check-updated)
      check_updated="1"
      shift
      ;;
    --require-links)
      require_links="1"
      shift
      ;;
    --require-progress-link)
      require_progress_link="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for cmd in git python3; do
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

python3 - "$require_addendum" "$check_updated" "$require_links" "$require_progress_link" <<'PY'
import datetime
import re
import sys
from pathlib import Path

require_addendum = sys.argv[1] == "1"
check_updated = sys.argv[2] == "1"
require_links = sys.argv[3] == "1"
require_progress_link = sys.argv[4] == "1"

progress_root = Path("docs/progress")
if not progress_root.is_dir():
  raise SystemExit("error: docs/progress/ does not exist; nothing to audit")

progress_file_re = re.compile(r"^\d{8}_[A-Za-z0-9_-]+\.md$")
progress_file_any_re = re.compile(r"\d{8}_[A-Za-z0-9_-]+\.md")

files = []
for p in progress_root.rglob("*.md"):
  if not p.is_file():
    continue
  if progress_file_re.fullmatch(p.name):
    files.append(p)

files_sorted = sorted(files, key=lambda p: str(p))

def parse_status_row(lines, path: Path):
  candidates = []
  for i, line in enumerate(lines[:80]):
    if not line.lstrip().startswith("|"):
      continue
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    if len(parts) != 3:
      continue
    status, created, updated = parts
    if status not in {"DRAFT", "IN PROGRESS", "DONE"}:
      continue
    try:
      created_d = datetime.date.fromisoformat(created)
      updated_d = datetime.date.fromisoformat(updated)
    except ValueError:
      continue
    candidates.append((i, status, created_d, updated_d))
  if not candidates:
    return None
  if len(candidates) > 1:
    raise ValueError("multiple header status rows detected")
  return candidates[0]

def find_links_idx(lines):
  for i, line in enumerate(lines):
    if line.strip() == "Links:":
      return i
  return None

def first_h2_after(lines, start_idx):
  for j in range(start_idx + 1, len(lines)):
    if lines[j].startswith("## "):
      return j
  return None

def section_range(lines, heading):
  idxs = [i for i, line in enumerate(lines) if line.strip() == heading]
  if not idxs:
    return None
  if len(idxs) > 1:
    raise ValueError(f"multiple {heading!r} sections found")
  start = idxs[0]
  end = start + 1
  while end < len(lines) and not lines[end].startswith("## "):
    end += 1
  return start, end

errors = []

for path in files_sorted:
  try:
    text = path.read_text(encoding="utf-8")
  except Exception as e:
    errors.append(f"{path}: cannot read file: {e}")
    continue

  lines = text.splitlines()

  if any(line.strip() == "## xx" for line in lines):
    errors.append(f"{path}: placeholder heading '## xx' must be replaced (use '## Addendum')")

  try:
    status_row = parse_status_row(lines, path)
  except Exception as e:
    errors.append(f"{path}: {e}")
    continue

  if status_row is None:
    errors.append(f"{path}: cannot find header status table row")
    continue

  _row_idx, status, _created_d, updated_d = status_row

  links_idx = find_links_idx(lines)
  if links_idx is None:
    errors.append(f"{path}: missing 'Links:' section")
    continue

  addendum_range = section_range(lines, "## Addendum")
  first_h2 = first_h2_after(lines, links_idx)

  if status != "DONE":
    continue

  if require_addendum and addendum_range is None:
    errors.append(f"{path}: Status is DONE but missing '## Addendum' (required by --require-addendum)")
    continue

  if addendum_range is None:
    continue

  add_start, add_end = addendum_range
  if first_h2 is not None and add_start != first_h2:
    errors.append(f"{path}: '## Addendum' must be the first section after 'Links:'")
    continue

  content_lines = []
  for line in lines[add_start + 1 : add_end]:
    if line.strip():
      content_lines.append(line.strip())

  if content_lines == ["- None"]:
    continue

  entry_dates = []
  date_heading_re = re.compile(r"^###\s+(?P<date>\d{4}-\d{2}-\d{2})\s*$")
  date_markers = []
  for i in range(add_start + 1, add_end):
    m = date_heading_re.match(lines[i])
    if not m:
      continue
    try:
      dt = datetime.date.fromisoformat(m.group("date"))
    except ValueError:
      errors.append(f"{path}: invalid Addendum date heading: {lines[i].strip()!r}")
      continue
    entry_dates.append(dt)
    date_markers.append((i, dt))

  if not entry_dates:
    errors.append(f"{path}: Addendum must contain '- None' or at least one '### YYYY-MM-DD' entry heading")
    continue

  if require_links or require_progress_link:
    for idx, dt in date_markers:
      next_idx = add_end
      for j, _ in date_markers:
        if j > idx:
          next_idx = j
          break
      entry_block = lines[idx + 1 : next_idx]

      links_lines = [ln.strip() for ln in entry_block if ln.strip().startswith("- Links:")]
      if require_links and not links_lines:
        errors.append(f"{path}: Addendum entry {dt.isoformat()} missing '- Links:' bullet")
        continue

      if require_progress_link:
        haystack = "\n".join(entry_block)
        if not progress_file_any_re.search(haystack):
          errors.append(f"{path}: Addendum entry {dt.isoformat()} missing a progress file reference (e.g. 20260114_some-slug.md)")

  if check_updated:
    max_entry = max(entry_dates)
    if updated_d < max_entry:
      errors.append(f"{path}: header Updated ({updated_d}) is older than latest Addendum entry ({max_entry})")

if errors:
  for e in errors:
    print(f"error: {e}", file=sys.stderr)
  raise SystemExit(1)
PY
