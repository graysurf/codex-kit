#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  bug-pr-patch.sh --pr <number> [--mark-fixed <bug_id>]... [--set <bug_id>=<status>]...

Purpose:
  Patch a bug-type PR body so the Issues Found table reflects latest Status values.

Behavior:
  - Fetches PR body via `gh pr view`.
  - Updates the Issues Found table Status cell for requested bug IDs.
  - Recomputes overall Issues Found `Status: open|fixed` from the table after patching.
  - Applies the updated body via `gh pr edit --body-file`.

Exit:
  0: PR body updated (prints JSON summary to stdout)
  2: no changes needed OR PR is not a bug-type PR
USAGE
}

die() {
  echo "bug-pr-patch: $1" >&2
  exit 2
}

pr_number=""
updates=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --pr)
      pr_number="${2:-}"
      shift 2
      ;;
    --mark-fixed)
      updates+=("${2:-}=fixed")
      shift 2
      ;;
    --set)
      updates+=("${2:-}")
      shift 2
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

if [[ -z "$pr_number" ]]; then
  die "--pr is required"
fi

for cmd in gh python3 mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "missing required command: $cmd"
  fi
done

tmp_file="$(mktemp)"

pr_body="$(gh pr view "$pr_number" --json body -q .body)"
printf '%s' "$pr_body" >"$tmp_file"

set +e
summary_json="$(
  python3 - "$tmp_file" "$pr_number" "${updates[@]}" <<'PY'
import json
import re
import sys
from pathlib import Path

body_path = Path(sys.argv[1])
pr_number = sys.argv[2]
updates_raw = sys.argv[3:]

updates: dict[str, str] = {}
for item in updates_raw:
  if "=" not in item:
    raise SystemExit(f"error: invalid --set value (expected bug_id=status): {item!r}")
  bug_id, status = item.split("=", 1)
  bug_id = bug_id.strip()
  status = status.strip().lower()
  if not bug_id:
    raise SystemExit("error: empty bug_id in --set")
  if not status:
    raise SystemExit(f"error: empty status for bug_id {bug_id!r}")
  updates[bug_id] = status

original = body_path.read_text("utf-8", errors="replace")
lines = original.splitlines()

bug_id_re = re.compile(r"^PR-(?:\\d+|<number>)-bug-\\d+$", re.IGNORECASE)

start = None
for i, line in enumerate(lines):
  if line.strip() == "## Issues Found":
    start = i
    break

if start is None:
  print("bug-pr-patch: missing '## Issues Found' section", file=sys.stderr)
  raise SystemExit(2)

end = len(lines)
for j in range(start + 1, len(lines)):
  if lines[j].startswith("## ") and lines[j].strip() != "## Issues Found":
    end = j
    break

header = None
for i in range(start + 1, end):
  line = lines[i]
  if not line.lstrip().startswith("|"):
    continue
  if re.search(r"\\|\\s*ID\\s*\\|", line, re.IGNORECASE) and re.search(
    r"\\|\\s*Status\\s*\\|", line, re.IGNORECASE
  ):
    header = i
    break

if header is None or header + 2 >= end:
  print("bug-pr-patch: missing Issues Found table with ID/Status columns", file=sys.stderr)
  raise SystemExit(2)

headers = [h.strip() for h in lines[header].strip().strip("|").split("|")]
if not headers:
  print("bug-pr-patch: invalid table header row", file=sys.stderr)
  raise SystemExit(2)

try:
  id_col = next(i for i, h in enumerate(headers) if h.strip().lower() == "id")
  status_col = next(i for i, h in enumerate(headers) if h.strip().lower() == "status")
except StopIteration:
  print("bug-pr-patch: table missing ID/Status columns", file=sys.stderr)
  raise SystemExit(2)

rows_start = header + 2
rows_end = rows_start
while rows_end < end and lines[rows_end].lstrip().startswith("|"):
  rows_end += 1

bug_rows: list[dict[str, object]] = []
found_ids: set[str] = set()
patched_ids: list[str] = []

def norm_cell(value: str) -> str:
  v = value.strip()
  if v.startswith("`") and v.endswith("`") and len(v) >= 2:
    v = v[1:-1].strip()
  return v

def norm_status(value: str) -> str:
  return norm_cell(value).lower()

for idx in range(rows_start, rows_end):
  raw_line = lines[idx]
  parts = [p.strip() for p in raw_line.strip().strip("|").split("|")]
  if len(parts) < max(id_col, status_col) + 1:
    continue

  bug_id = norm_cell(parts[id_col])
  if not bug_id_re.match(bug_id):
    continue

  current_status = norm_status(parts[status_col])
  desired_status = updates.get(bug_id)
  if desired_status is not None:
    found_ids.add(bug_id)
    if current_status != desired_status:
      parts[status_col] = desired_status
      lines[idx] = "| " + " | ".join(parts) + " |"
      patched_ids.append(bug_id)
      current_status = desired_status

  bug_rows.append({"id": bug_id, "status": current_status})

if not bug_rows:
  print("bug-pr-patch: no bug rows found in Issues Found table", file=sys.stderr)
  raise SystemExit(2)

missing = sorted(set(updates.keys()) - found_ids)
if missing:
  for m in missing:
    print(f"bug-pr-patch: bug_id not found in table: {m}", file=sys.stderr)
  raise SystemExit(1)

open_bug_ids = sorted([r["id"] for r in bug_rows if r["status"] != "fixed"])
overall_status = "fixed" if not open_bug_ids else "open"

status_line_idx = None
for i in range(start + 1, end):
  s = lines[i].strip()
  if s.startswith("Status:") and not s.startswith("|"):
    status_line_idx = i
    break

status_line = f"Status: {overall_status}"
insert_after = start
for i in range(start + 1, end):
  if lines[i].strip().startswith("Confidence:"):
    insert_after = i
    break
  if lines[i].strip().startswith("Severity:"):
    insert_after = i

if status_line_idx is not None:
  if lines[status_line_idx].strip() != status_line:
    lines[status_line_idx] = status_line
else:
  lines.insert(insert_after + 1, status_line)
  end += 1

updated = "\n".join(lines).rstrip() + "\n"
changed = updated != original
body_path.write_text(updated, "utf-8")

payload = {
  "pr_number": int(pr_number) if pr_number.isdigit() else pr_number,
  "overall_status": overall_status,
  "patched_bug_ids": patched_ids,
  "open_bug_ids": open_bug_ids,
}

print(json.dumps(payload, ensure_ascii=False) + "\n")
raise SystemExit(0 if changed else 2)
PY
)"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  gh pr edit "$pr_number" --body-file "$tmp_file" >/dev/null 2>&1
  rm -f "$tmp_file"
  printf '%s\n' "$summary_json"
  exit 0
fi

rm -f "$tmp_file"
exit "$rc"
