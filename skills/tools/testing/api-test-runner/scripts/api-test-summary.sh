#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  api-test-summary.sh [--in <results.json>] [options]

Options:
  --in <path>         Input results JSON file (default: stdin)
  --out <path>        Write Markdown summary to a file (optional)
  --slow <n>          Show slowest N executed cases (default: 5)
  --hide-skipped      Do not show skipped cases list (default: on)
  --max-failed <n>    Max failed cases to print (default: 50)
  --max-skipped <n>   Max skipped cases to print (default: 50)
  --no-github-summary Do not write to $GITHUB_STEP_SUMMARY
  -h, --help          Show help

Notes:
  - This script is intentionally independent from api-test.sh; it only consumes its results JSON.
  - In GitHub Actions, it appends a Markdown summary to $GITHUB_STEP_SUMMARY when available.
EOF
}

in_file=""
out_file=""
slow_n="5"
show_skipped="1"
max_failed="50"
max_skipped="50"
write_github_summary="1"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --in)
      in_file="${2:-}"
      [[ -n "$in_file" ]] || { echo "error: --in requires a path" >&2; usage; exit 1; }
      shift 2
      ;;
    --out)
      out_file="${2:-}"
      [[ -n "$out_file" ]] || { echo "error: --out requires a path" >&2; usage; exit 1; }
      shift 2
      ;;
    --slow)
      slow_n="${2:-}"
      [[ -n "$slow_n" ]] || { echo "error: --slow requires a number" >&2; usage; exit 1; }
      shift 2
      ;;
    --hide-skipped)
      show_skipped="0"
      shift
      ;;
    --max-failed)
      max_failed="${2:-}"
      [[ -n "$max_failed" ]] || { echo "error: --max-failed requires a number" >&2; usage; exit 1; }
      shift 2
      ;;
    --max-skipped)
      max_skipped="${2:-}"
      [[ -n "$max_skipped" ]] || { echo "error: --max-skipped requires a number" >&2; usage; exit 1; }
      shift 2
      ;;
    --no-github-summary)
      write_github_summary="0"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1}" >&2
      usage
      exit 1
      ;;
  esac
done

summary_tmp="$(mktemp 2>/dev/null || mktemp -t api-test-summary.md)"

cleanup() {
  rm -f "$summary_tmp" >/dev/null 2>&1 || true
}
trap cleanup EXIT

python3 - "$in_file" "$slow_n" "$show_skipped" "$max_failed" "$max_skipped" >"$summary_tmp" <<'PY'
import json
import os
import sys
import html
from typing import Any, Dict, List

in_path = sys.argv[1].strip()
slow_n_raw = sys.argv[2].strip()
show_skipped_raw = sys.argv[3].strip()
max_failed_raw = sys.argv[4].strip()
max_skipped_raw = sys.argv[5].strip()

def safe_int(value: str, default: int) -> int:
  try:
    n = int(value)
    return n if n >= 0 else default
  except Exception:
    return default

slow_n = safe_int(slow_n_raw, 5)
show_skipped = show_skipped_raw == "1"
max_failed = safe_int(max_failed_raw, 50)
max_skipped = safe_int(max_skipped_raw, 50)

SKIP_HINTS: Dict[str, str] = {
  "write_cases_disabled": "Enable writes with API_TEST_ALLOW_WRITES_ENABLED=true (or --allow-writes) to run allowWrite cases.",
  "not_selected": "Case not selected (check --only filter).",
  "skipped_by_id": "Case skipped by id (check --skip filter).",
  "tag_mismatch": "Case tags did not match selected --tag filters.",
}

def read_input() -> str:
  if in_path:
    try:
      with open(in_path, "r", encoding="utf-8") as f:
        return f.read()
    except FileNotFoundError:
      return ""
  return sys.stdin.read()

raw = read_input()

def emit_error(message: str) -> None:
  print("## API test summary")
  print("")
  print(f"- {message}")

if not raw.strip():
  if in_path:
    emit_error(f"results file not found or empty: `{in_path}`")
  else:
    emit_error("no input provided (stdin is empty)")
  raise SystemExit(0)

try:
  results: Dict[str, Any] = json.loads(raw)
except Exception:
  if in_path:
    emit_error(f"invalid JSON in: `{in_path}`")
  else:
    emit_error("invalid JSON from stdin")
  raise SystemExit(0)

suite = str(results.get("suite") or "suite")
run_id = str(results.get("runId") or "")
suite_file = str(results.get("suiteFile") or "")
output_dir = str(results.get("outputDir") or "")
started_at = str(results.get("startedAt") or "")
finished_at = str(results.get("finishedAt") or "")

summary = results.get("summary") or {}
total = int(summary.get("total") or 0)
passed = int(summary.get("passed") or 0)
failed = int(summary.get("failed") or 0)
skipped = int(summary.get("skipped") or 0)

cases: List[Dict[str, Any]] = results.get("cases") or []

def sanitize_one_line(value: Any) -> str:
  s = str(value or "").strip()
  return " ".join(s.split())

def md_escape_cell(value: Any) -> str:
  s = sanitize_one_line(value)
  return s.replace("|", "\\|")

def md_code(value: Any) -> str:
  s = md_escape_cell(value)
  if not s:
    return ""
  if "`" not in s:
    return f"`{s}`"
  # Fallback for rare backtick-containing values; avoid breaking Markdown tables.
  return f"<code>{html.escape(s)}</code>"

def md_table(headers: List[str], rows: List[List[str]]) -> None:
  print("| " + " | ".join(headers) + " |")
  print("| " + " | ".join(["---"] * len(headers)) + " |")
  for row in rows:
    padded = row + [""] * (len(headers) - len(row))
    print("| " + " | ".join(padded[: len(headers)]) + " |")

def dur_ms(case: Dict[str, Any]) -> int:
  try:
    return int(case.get("durationMs") or 0)
  except Exception:
    return 0

failed_cases = [c for c in cases if (c.get("status") == "failed")]
skipped_cases = [c for c in cases if (c.get("status") == "skipped")]
executed_cases = [c for c in cases if (c.get("status") in ("passed", "failed"))]

slow_cases = sorted(executed_cases, key=dur_ms, reverse=True)[:slow_n] if slow_n > 0 else []

print(f"## API test summary: {suite}")
print("")

print("### Totals")
md_table(
  headers=["total", "passed", "failed", "skipped"],
  rows=[[str(total), str(passed), str(failed), str(skipped)]],
)

print("")
print("### Run info")
info_rows: List[List[str]] = []
if run_id:
  info_rows.append(["runId", md_code(run_id)])
if started_at:
  info_rows.append(["startedAt", md_code(started_at)])
if finished_at:
  info_rows.append(["finishedAt", md_code(finished_at)])
if suite_file:
  info_rows.append(["suiteFile", md_code(suite_file)])
if output_dir:
  info_rows.append(["outputDir", md_code(output_dir)])
if info_rows:
  md_table(headers=["field", "value"], rows=info_rows)
else:
  md_table(headers=["field", "value"], rows=[["(none)", ""]])

def case_row_full(case: Dict[str, Any]) -> List[str]:
  return [
    md_code(case.get("id") or ""),
    md_escape_cell(case.get("type") or ""),
    md_escape_cell(case.get("status") or ""),
    str(dur_ms(case)),
    md_escape_cell(case.get("message") or ""),
    md_code(case.get("stdoutFile") or ""),
    md_code(case.get("stderrFile") or ""),
  ]

print("")
print(f"### Failed ({len(failed_cases)})")
if not failed_cases:
  md_table(headers=["id", "type", "status", "durationMs", "message", "stdout", "stderr"], rows=[["(none)"]])
else:
  shown = failed_cases[:max_failed] if max_failed > 0 else failed_cases
  md_table(
    headers=["id", "type", "status", "durationMs", "message", "stdout", "stderr"],
    rows=[case_row_full(c) for c in shown],
  )
  if max_failed > 0 and len(failed_cases) > max_failed:
    print("")
    print(f"_…and {len(failed_cases) - max_failed} more failed cases_")

print("")
print(f"### Slowest (Top {slow_n})")
if not slow_cases:
  md_table(headers=["id", "type", "status", "durationMs", "message", "stdout", "stderr"], rows=[["(none)"]])
else:
  md_table(
    headers=["id", "type", "status", "durationMs", "message", "stdout", "stderr"],
    rows=[case_row_full(c) for c in slow_cases],
  )

if show_skipped:
  print("")
  print(f"### Skipped ({len(skipped_cases)})")
  if not skipped_cases:
    md_table(headers=["id", "type", "message"], rows=[["(none)"]])
  else:
    reasons: Dict[str, int] = {}
    for c in skipped_cases:
      reason = sanitize_one_line(c.get("message") or "")
      reason = reason or "(none)"
      reasons[reason] = reasons.get(reason, 0) + 1

    md_table(
      headers=["reason", "count", "hint"],
      rows=[
        [
          md_code(reason),
          str(count),
          md_escape_cell(SKIP_HINTS.get(reason, "")),
        ]
        for reason, count in sorted(reasons.items(), key=lambda kv: (-kv[1], kv[0]))
      ],
    )

    print("")
    if max_skipped > 0:
      print(f"#### Cases (max {max_skipped})")
    else:
      print("#### Cases (all)")
    shown = skipped_cases[:max_skipped] if max_skipped > 0 else skipped_cases
    md_table(
      headers=["id", "type", "message"],
      rows=[
        [
          md_code(c.get("id") or ""),
          md_escape_cell(c.get("type") or ""),
          md_escape_cell(c.get("message") or ""),
        ]
        for c in shown
      ],
    )
    if max_skipped > 0 and len(skipped_cases) > max_skipped:
      print("")
      print(f"_…and {len(skipped_cases) - max_skipped} more skipped cases_")

print("")
print(f"### Executed cases ({len(executed_cases)})")
if not executed_cases:
  md_table(headers=["id", "status", "durationMs"], rows=[["(none)"]])
else:
  md_table(
    headers=["id", "status", "durationMs"],
    rows=[
      [
        md_code(c.get("id") or ""),
        md_escape_cell(c.get("status") or ""),
        str(dur_ms(c)),
      ]
      for c in executed_cases
    ],
  )
PY

cat "$summary_tmp"

if [[ -n "$out_file" ]]; then
  mkdir -p "$(dirname "$out_file")"
  cp "$summary_tmp" "$out_file"
fi

if [[ "$write_github_summary" == "1" && -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo ""
    cat "$summary_tmp"
    echo ""
  } >>"$GITHUB_STEP_SUMMARY" 2>/dev/null || true
fi
