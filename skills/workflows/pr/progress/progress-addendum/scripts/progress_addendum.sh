#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
progress_dir="$(cd "${skill_dir}/.." && pwd)"
create_progress_file_script="${progress_dir}/create-progress-pr/scripts/create_progress_file.sh"

usage() {
  cat <<'USAGE'
Usage:
  progress_addendum.sh --file <path> [options]
  progress_addendum.sh --file <path> --followup-progress <path> [options]
  progress_addendum.sh --file <path> --followup-title "<short title>" [options]
  progress_addendum.sh --print-entry [--date <YYYY-MM-DD>]
  progress_addendum.sh --print-section

What it does:
  - Ensures a DONE progress file has a top-of-file `## Addendum` section (immediately after `Links:`).
  - Default mode: inserts a new entry template for the given date (newest-first) and updates the header `Updated` date.
  - `--ensure-only`: inserts `## Addendum` with `- None` if missing; does not change the header `Updated` date.
  - Optional: prefill the entry `- Links:` with a follow-up progress file link (existing or newly created).

Options:
  --file <path>          Target progress file (usually under docs/progress/archived/)
  --date <YYYY-MM-DD>    Date for the entry + header Updated date (default: today)
  --ensure-only          Only ensure the section exists; do not add a new entry; do not bump Updated
  --fix-location         If `## Addendum` exists in the wrong place, move it to the canonical location
  --allow-not-done       Allow editing files whose Status is not DONE (not recommended)
  --followup-progress <path>
                        Prefill `- Links:` with a Markdown link to an existing progress file under docs/progress/
  --followup-title <short title>
                        Create a new follow-up progress file (via create-progress-pr helper) and link it
  --print-entry          Print a copy/paste entry template to stdout (no file edits)
  --print-section        Print a copy/paste `## Addendum` section skeleton (no file edits)

Notes:
  - Run inside the target git repo (any subdir is fine).
  - `--followup-title` may also create/update: docs/templates/* and docs/progress/README.md (delegated to create_progress_file.sh).
USAGE
}

file=""
date_iso="$(date +%Y-%m-%d)"
ensure_only="0"
fix_location="0"
allow_not_done="0"
followup_progress=""
followup_title=""
print_entry="0"
print_section="0"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --file)
      file="${2:-}"
      shift 2
      ;;
    --date)
      date_iso="${2:-}"
      shift 2
      ;;
    --ensure-only)
      ensure_only="1"
      shift
      ;;
    --fix-location)
      fix_location="1"
      shift
      ;;
    --allow-not-done)
      allow_not_done="1"
      shift
      ;;
    --followup-progress)
      followup_progress="${2:-}"
      shift 2
      ;;
    --followup-title)
      followup_title="${2:-}"
      shift 2
      ;;
    --print-entry)
      print_entry="1"
      shift
      ;;
    --print-section)
      print_section="1"
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

if [[ "$print_entry" == "1" && "$print_section" == "1" ]]; then
  echo "error: choose at most one of --print-entry or --print-section" >&2
  exit 1
fi

if [[ "$print_entry" == "1" || "$print_section" == "1" ]]; then
  if [[ -n "$followup_progress" || -n "$followup_title" ]]; then
    echo "error: --followup-progress/--followup-title cannot be used with --print-entry/--print-section" >&2
    exit 1
  fi
fi

if [[ -n "$followup_progress" && -n "$followup_title" ]]; then
  echo "error: choose at most one of --followup-progress or --followup-title" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required" >&2
  exit 1
fi

python3 - "$date_iso" "$print_entry" "$print_section" <<'PY'
import datetime
import sys

date_iso, print_entry, print_section = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"

try:
  datetime.date.fromisoformat(date_iso)
except ValueError:
  raise SystemExit(f"error: --date must be YYYY-MM-DD, got: {date_iso!r}")

if print_entry:
  print(f"""### {date_iso}

- Change: TBD
- Reason: TBD
- Impact: TBD
- Links: TBD
""".rstrip())
elif print_section:
  print("""## Addendum

- None""")
PY

if [[ "$print_entry" == "1" || "$print_section" == "1" ]]; then
  exit 0
fi

if [[ -z "$file" ]]; then
  echo "error: --file is required (or use --print-entry / --print-section)" >&2
  usage >&2
  exit 1
fi

if [[ "$ensure_only" == "1" ]]; then
  if [[ -n "$followup_progress" || -n "$followup_title" ]]; then
    echo "error: --ensure-only cannot be combined with --followup-progress/--followup-title (no entry is added)" >&2
    exit 1
  fi
fi

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

file="${file#./}"

if [[ ! -f "$file" ]]; then
  echo "error: file not found: ${repo_root}/${file}" >&2
  exit 1
fi

date_yyyymmdd="${date_iso//-/}"

if [[ -n "$followup_title" ]]; then
  if [[ ! -x "$create_progress_file_script" ]]; then
    echo "error: create-progress-pr helper not found or not executable: ${create_progress_file_script}" >&2
    exit 1
  fi

  followup_progress="$("$create_progress_file_script" --title "$followup_title" --date "$date_yyyymmdd")"
fi

if [[ -n "$followup_progress" ]]; then
  followup_progress="${followup_progress#./}"

  if [[ ! -f "$followup_progress" ]]; then
    filename="$(basename "$followup_progress")"
    if [[ -f "docs/progress/${filename}" ]]; then
      followup_progress="docs/progress/${filename}"
    elif [[ -f "docs/progress/archived/${filename}" ]]; then
      followup_progress="docs/progress/archived/${filename}"
    else
      echo "error: follow-up progress file not found: ${repo_root}/${followup_progress}" >&2
      exit 1
    fi
  fi

  if [[ "$followup_progress" != docs/progress/* ]]; then
    echo "error: follow-up progress file must be under docs/progress/: $followup_progress" >&2
    exit 1
  fi
fi

python3 - "$file" "$date_iso" "$ensure_only" "$allow_not_done" "$fix_location" "$followup_progress" <<'PY'
import datetime
import os
import sys

path, date_iso, ensure_only, allow_not_done, fix_location, followup_progress = (
  sys.argv[1],
  sys.argv[2],
  sys.argv[3] == "1",
  sys.argv[4] == "1",
  sys.argv[5] == "1",
  sys.argv[6],
)

try:
  datetime.date.fromisoformat(date_iso)
except ValueError:
  raise SystemExit(f"error: --date must be YYYY-MM-DD, got: {date_iso!r}")

with open(path, "r", encoding="utf-8") as f:
  original_text = f.read()

lines = original_text.splitlines()

def parse_status_row():
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
      datetime.date.fromisoformat(created)
      datetime.date.fromisoformat(updated)
    except ValueError:
      continue
    candidates.append((i, status, created, updated))
  if not candidates:
    return None
  if len(candidates) > 1:
    raise SystemExit(f"error: multiple status rows detected in header table: {path}")
  return candidates[0]

status_row = parse_status_row()
if status_row is None:
  raise SystemExit(f"error: cannot find header status table row in {path}")

status_row_idx, status, created, updated = status_row

if not allow_not_done and status != "DONE":
  raise SystemExit(f"error: Status is {status!r}, expected 'DONE' (use --allow-not-done to override): {path}")

links_idx = None
for i, line in enumerate(lines):
  if line.strip() == "Links:":
    links_idx = i
    break
if links_idx is None:
  raise SystemExit(f"error: cannot find 'Links:' section in {path}")

def first_h2_after(start):
  for j in range(start + 1, len(lines)):
    if lines[j].startswith("## "):
      return j
  return None

def section_range(start_heading):
  idxs = [i for i, line in enumerate(lines) if line.strip() == start_heading]
  if not idxs:
    return None
  if len(idxs) > 1:
    raise SystemExit(f"error: multiple {start_heading!r} sections found in {path}")
  start_idx = idxs[0]
  end_idx = start_idx + 1
  while end_idx < len(lines) and not lines[end_idx].startswith("## "):
    end_idx += 1
  return start_idx, end_idx

addendum_range = section_range("## Addendum")

if addendum_range is not None:
  add_start, add_end = addendum_range
  canonical_first_h2 = first_h2_after(links_idx)
  if canonical_first_h2 is None:
    canonical_first_h2 = len(lines)

  if add_start != canonical_first_h2:
    if not fix_location:
      raise SystemExit(
        "error: '## Addendum' exists but is not the first section after 'Links:'; "
        "move it manually or re-run with --fix-location: "
        f"{path}"
      )
    preserved = lines[add_start:add_end]
    del lines[add_start:add_end]

    links_idx = next((i for i, line in enumerate(lines) if line.strip() == "Links:"), None)
    if links_idx is None:
      raise SystemExit(f"error: cannot find 'Links:' section after edits in {path}")

    insertion_idx = first_h2_after(links_idx)
    if insertion_idx is None:
      insertion_idx = len(lines)

    if preserved and preserved[-1].strip() != "":
      preserved.append("")
    if insertion_idx > 0 and lines[insertion_idx - 1].strip() != "":
      preserved.insert(0, "")

    lines[insertion_idx:insertion_idx] = preserved

addendum_range = section_range("## Addendum")
if addendum_range is None:
  insertion_idx = first_h2_after(links_idx)
  if insertion_idx is None:
    insertion_idx = len(lines)

  block = ["## Addendum", "", "- None", ""]
  if insertion_idx > 0 and lines[insertion_idx - 1].strip() != "":
    block.insert(0, "")
  lines[insertion_idx:insertion_idx] = block

addendum_range = section_range("## Addendum")
if addendum_range is None:
  raise SystemExit(f"error: internal: failed to ensure '## Addendum' exists in {path}")

add_start, add_end = addendum_range

def update_header_updated():
  row = lines[status_row_idx]
  parts = [p.strip() for p in row.strip().strip("|").split("|")]
  if len(parts) != 3:
    raise SystemExit(f"error: internal: cannot parse status row for update: {path}")
  parts[2] = date_iso
  lines[status_row_idx] = f"| {parts[0]} | {parts[1]} | {parts[2]} |"

if ensure_only:
  new_text = "\n".join(lines) + "\n"
  if new_text != original_text:
    with open(path, "w", encoding="utf-8") as f:
      f.write(new_text)
  raise SystemExit(0)

if add_start + 1 >= len(lines) or lines[add_start + 1].strip() != "":
  lines.insert(add_start + 1, "")
  add_end += 1

i = add_start + 1
while i < add_end and lines[i].strip() == "":
  i += 1
if i < add_end and lines[i].strip() == "- None":
  del lines[i]
  add_end -= 1
  if i < add_end and lines[i].strip() == "":
    del lines[i]
    add_end -= 1

date_heading = f"### {date_iso}"
date_idx = None
for i in range(add_start + 1, add_end):
  if lines[i].strip() == date_heading:
    date_idx = i
    break

bullet_block = [
  "- Change: TBD",
  "- Reason: TBD",
  "- Impact: TBD",
  "- Links: TBD",
]

if followup_progress:
  rel = os.path.relpath(followup_progress, start=os.path.dirname(path) or ".")
  label = os.path.basename(followup_progress)
  bullet_block[-1] = f"- Links: [Progress: {label}]({rel})"

if date_idx is not None:
  insert_at = date_idx + 1
  if insert_at >= len(lines) or lines[insert_at].strip() != "":
    lines.insert(insert_at, "")
    add_end += 1
    insert_at += 1
  lines[insert_at:insert_at] = bullet_block + [""]
else:
  insert_at = add_start + 2
  block = [date_heading, "", *bullet_block, ""]
  lines[insert_at:insert_at] = block

update_header_updated()

new_text = "\n".join(lines) + "\n"
if new_text != original_text:
  with open(path, "w", encoding="utf-8") as f:
    f.write(new_text)
PY

echo "$file"
