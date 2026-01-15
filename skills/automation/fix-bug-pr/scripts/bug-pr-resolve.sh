#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  bug-pr-resolve.sh [--pr <number>] [--limit <n>] [--label <name>]...

Purpose:
  Resolve a bug-type PR (Issues Found table) and extract unresolved bug items.

Behavior:
  - With --pr: parse that PR and output structured JSON (even if all items are fixed).
  - Without --pr: scan open PRs and select one that has unresolved bug items.
  - Bug items are rows whose ID matches (case-insensitive): PR-<number>-bug-<n> (or PR-<number>-bug-<n> placeholder).

Exit:
  0: resolved successfully (prints JSON to stdout)
  2: no matching bug PR found (no stdout)
USAGE
}

die() {
  echo "bug-pr-resolve: $1" >&2
  exit 2
}

pr_number=""
limit="50"
labels=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --pr)
      pr_number="${2:-}"
      shift 2
      ;;
    --limit)
      limit="${2:-}"
      shift 2
      ;;
    --label)
      labels+=("${2:-}")
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

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  die "invalid --limit (expected integer): $limit"
fi

if [[ ${#labels[@]} -eq 0 ]]; then
  labels=("bug" "type: bug")
fi

for cmd in gh python3 mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "missing required command: $cmd"
  fi
done

pr_json=""
mode="list"
if [[ -n "$pr_number" ]]; then
  mode="single"
  pr_json="$(gh pr view "$pr_number" --json number,title,url,body,headRefName,baseRefName,labels,updatedAt)"
else
  pr_json="$(gh pr list --state open --limit "$limit" --json number,title,url,body,headRefName,baseRefName,labels,updatedAt)"
fi

tmp_json="$(mktemp)"
trap 'rm -f "$tmp_json"' EXIT
printf '%s' "$pr_json" >"$tmp_json"

python3 - "$mode" "${labels[@]}" "$tmp_json" <<'PY'
import datetime
import json
import re
import sys
from pathlib import Path
from typing import Any

mode = sys.argv[1]
labels_filter = [s.strip().lower() for s in sys.argv[2:-1] if s.strip()]
json_path = Path(sys.argv[-1])

raw = json_path.read_text("utf-8", errors="replace")
data = json.loads(raw) if raw.strip() else None

bug_id_re = re.compile(r"^PR-(?:\\d+|<number>)-bug-\\d+$", re.IGNORECASE)

severity_rank = {"critical": 4, "high": 3, "medium": 2, "low": 1}


def norm_cell(value: str) -> str:
  v = value.strip()
  if v.startswith("`") and v.endswith("`") and len(v) >= 2:
    v = v[1:-1].strip()
  return v


def norm_status(value: str) -> str:
  return norm_cell(value).lower()


def parse_updated_at(ts: str | None) -> float:
  if not ts:
    return 0.0
  try:
    if ts.endswith("Z"):
      ts = ts[:-1] + "+00:00"
    return datetime.datetime.fromisoformat(ts).timestamp()
  except ValueError:
    return 0.0


def issues_found_block(body: str) -> list[str]:
  lines = body.splitlines()
  start = None
  for i, line in enumerate(lines):
    if line.strip() == "## Issues Found":
      start = i
      break
  if start is None:
    return []
  end = len(lines)
  for j in range(start + 1, len(lines)):
    if lines[j].startswith("## ") and lines[j].strip() != "## Issues Found":
      end = j
      break
  return lines[start:end]


def parse_bug_rows(body: str) -> list[dict[str, str]]:
  block = issues_found_block(body)
  if not block:
    return []

  header_idx = None
  for i, line in enumerate(block):
    if not line.lstrip().startswith("|"):
      continue
    if re.search(r"\\|\\s*ID\\s*\\|", line, re.IGNORECASE) and re.search(
      r"\\|\\s*Status\\s*\\|", line, re.IGNORECASE
    ):
      header_idx = i
      break

  if header_idx is None or header_idx + 2 >= len(block):
    return []

  headers = [h.strip() for h in block[header_idx].strip().strip("|").split("|")]
  if not headers:
    return []

  try:
    id_col = next(i for i, h in enumerate(headers) if h.strip().lower() == "id")
    status_col = next(i for i, h in enumerate(headers) if h.strip().lower() == "status")
  except StopIteration:
    return []

  rows: list[dict[str, str]] = []
  for line in block[header_idx + 2 :]:
    if not line.lstrip().startswith("|"):
      break
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    if len(parts) < max(id_col, status_col) + 1:
      continue
    bug_id = norm_cell(parts[id_col])
    if not bug_id_re.match(bug_id):
      continue

    row: dict[str, str] = {"id": bug_id, "status": norm_status(parts[status_col])}
    for idx, header in enumerate(headers):
      if idx >= len(parts):
        continue
      key = header.strip().lower().replace(" ", "_")
      if key in {"id", "status"}:
        continue
      row[key] = norm_cell(parts[idx])
    rows.append(row)

  return rows


def max_open_severity(rows: list[dict[str, str]]) -> int:
  best = 0
  for r in rows:
    if r.get("status") == "fixed":
      continue
    sev = (r.get("severity") or "").strip().lower()
    best = max(best, severity_rank.get(sev, 0))
  return best


def pick_next_bug_id(rows: list[dict[str, str]]) -> str | None:
  open_rows = [r for r in rows if r.get("status") != "fixed"]
  if not open_rows:
    return None

  def sort_key(r: dict[str, str]) -> tuple[int, int]:
    sev = (r.get("severity") or "").strip().lower()
    return (severity_rank.get(sev, 0), -open_rows.index(r))

  best = sorted(open_rows, key=sort_key, reverse=True)[0]
  return best.get("id") or None


def label_names(pr: dict[str, Any]) -> list[str]:
  labels = pr.get("labels")
  if not isinstance(labels, list):
    return []
  out: list[str] = []
  for item in labels:
    if isinstance(item, dict) and isinstance(item.get("name"), str):
      out.append(item["name"])
  return out


def as_payload(pr: dict[str, Any], rows: list[dict[str, str]]) -> dict[str, Any]:
  open_rows = [r for r in rows if r.get("status") != "fixed"]
  overall_status = "fixed" if rows and not open_rows else "open"
  payload: dict[str, Any] = {
    "pr_number": pr.get("number"),
    "pr_url": pr.get("url"),
    "pr_title": pr.get("title"),
    "head_ref": pr.get("headRefName"),
    "base_ref": pr.get("baseRefName"),
    "updated_at": pr.get("updatedAt"),
    "labels": label_names(pr),
    "overall_status": overall_status,
    "bugs": rows,
    "open_bugs": open_rows,
  }
  next_id = pick_next_bug_id(rows)
  if next_id:
    payload["next_bug_id"] = next_id
  return payload


def matches_labels(pr: dict[str, Any]) -> bool:
  if not labels_filter:
    return False
  names = [n.lower() for n in label_names(pr)]
  return any(n in labels_filter for n in names)


def die_no_match(msg: str) -> None:
  print(f"bug-pr-resolve: {msg}", file=sys.stderr)
  raise SystemExit(2)


if mode == "single":
  if not isinstance(data, dict):
    die_no_match("gh returned non-object JSON for pr view")
  body = data.get("body") if isinstance(data.get("body"), str) else ""
  rows = parse_bug_rows(body)
  if not rows:
    die_no_match("PR is not a bug-type PR (missing Issues Found bug table)")
  print(json.dumps(as_payload(data, rows), ensure_ascii=False) + "\n")
  raise SystemExit(0)

if mode != "list":
  die_no_match(f"invalid mode: {mode!r}")

if not isinstance(data, list):
  die_no_match("gh returned non-array JSON for pr list")

candidates: list[tuple[int, float, int, dict[str, Any]]] = []

for pr in data:
  if not isinstance(pr, dict):
    continue
  body = pr.get("body") if isinstance(pr.get("body"), str) else ""
  rows = parse_bug_rows(body)
  if not rows:
    continue

  open_rows = [r for r in rows if r.get("status") != "fixed"]
  if not open_rows:
    continue

  sev = max_open_severity(rows)
  updated = parse_updated_at(pr.get("updatedAt") if isinstance(pr.get("updatedAt"), str) else None)
  number = pr.get("number") if isinstance(pr.get("number"), int) else 0
  label_ok = matches_labels(pr)
  # Prefer label-matched PRs, but allow body-only matches.
  label_rank = 1 if label_ok else 0
  candidates.append((label_rank, updated, sev, as_payload(pr, rows)))

if not candidates:
  die_no_match("no open bug PR found with unresolved bug items")

# Sort: label match desc, severity desc, updated_at desc, then PR number asc.
candidates.sort(
  key=lambda t: (-t[0], -t[2], -t[1], int(t[3].get("pr_number") or 0))
)

print(json.dumps(candidates[0][3], ensure_ascii=False) + "\n")
PY
