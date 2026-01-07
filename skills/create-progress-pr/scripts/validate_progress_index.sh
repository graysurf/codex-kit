#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate_progress_index.sh [--file <path>]

Validates:
  - `docs/progress/README.md` index tables use a consistent PR link format:
    - `TBD`, OR
    - `[#<number>](https://github.com/<owner>/<repo>/pull/<number>)`

Notes:
  - Run inside the target git repo.
USAGE
}

index_path="docs/progress/README.md"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --file)
      index_path="${2:-}"
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

if [[ ! -f "$index_path" ]]; then
  echo "error: index file not found: ${repo_root}/${index_path}" >&2
  exit 1
fi

python3 - "$index_path" <<'PY'
import re
import sys

index_path = sys.argv[1]

with open(index_path, "r", encoding="utf-8") as f:
  lines = f.readlines()

def find_heading(heading):
  for i, line in enumerate(lines):
    if line.strip() == heading:
      return i
  return None

def find_table_sep(start, end):
  for i in range(start, end):
    if lines[i].startswith("| ---"):
      return i
  return None

def iter_table_rows(sep_line_idx: int, end: int):
  for i in range(sep_line_idx + 1, end):
    line = lines[i]
    if not line.startswith("|"):
      break
    if line.startswith("| ---"):
      continue
    yield i, line

errors = []

in_progress_idx = find_heading("## In progress")
archived_idx = find_heading("## Archived")

if in_progress_idx is None:
  errors.append("missing heading: ## In progress")
if archived_idx is None:
  errors.append("missing heading: ## Archived")

if errors:
  for e in errors:
    print(f"error: {e}", file=sys.stderr)
  raise SystemExit(1)

in_sep = find_table_sep(in_progress_idx, archived_idx)
arch_sep = find_table_sep(archived_idx, len(lines))

if in_sep is None:
  errors.append("cannot find table separator under ## In progress")
if arch_sep is None:
  errors.append("cannot find table separator under ## Archived")

if errors:
  for e in errors:
    print(f"error: {e}", file=sys.stderr)
  raise SystemExit(1)

pr_link_re = re.compile(r"^\[#(?P<num>\d+)\]\((?P<url>https://github\.com/[^/]+/[^/]+/pull/(?P<num2>\d+))\)$")

def validate_row(line_no: int, raw_line: str):
  parts = [p.strip() for p in raw_line.strip().strip("|").split("|")]
  if len(parts) != 3:
    errors.append(f"{index_path}:{line_no+1}: expected 3 columns, got {len(parts)}: {raw_line.rstrip()}")
    return
  pr_cell = parts[2].strip()
  if pr_cell == "TBD":
    return
  m = pr_link_re.fullmatch(pr_cell)
  if not m:
    errors.append(
      f"{index_path}:{line_no+1}: invalid PR cell (expected TBD or [#n](https://github.com/<owner>/<repo>/pull/n)): {pr_cell!r}"
    )
    return
  if m.group("num") != m.group("num2"):
    errors.append(
      f"{index_path}:{line_no+1}: PR number mismatch between label and URL: {pr_cell!r}"
    )

for i, line in iter_table_rows(in_sep, archived_idx):
  validate_row(i, line)

for i, line in iter_table_rows(arch_sep, len(lines)):
  validate_row(i, line)

if errors:
  for e in errors:
    print(f"error: {e}", file=sys.stderr)
  raise SystemExit(1)
PY
