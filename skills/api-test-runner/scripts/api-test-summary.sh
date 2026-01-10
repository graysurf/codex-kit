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
  --show-skipped      Include skipped cases list (default: off)
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
show_skipped="0"
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
    --show-skipped)
      show_skipped="1"
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

meta = []
if run_id:
  meta.append(f"runId=`{sanitize_one_line(run_id)}`")
meta.append(f"total={total} passed={passed} failed={failed} skipped={skipped}")
print(f"- {' '.join(meta)}")
if started_at or finished_at:
  print(f"- time: `{sanitize_one_line(started_at)}` → `{sanitize_one_line(finished_at)}`")
if suite_file:
  print(f"- suiteFile: `{sanitize_one_line(suite_file)}`")
if output_dir:
  print(f"- outputDir: `{sanitize_one_line(output_dir)}`")

def render_case_line(case: Dict[str, Any]) -> str:
  case_id = sanitize_one_line(case.get("id") or "")
  case_type = sanitize_one_line(case.get("type") or "")
  status = sanitize_one_line(case.get("status") or "")
  d = dur_ms(case)
  message = sanitize_one_line(case.get("message") or "")
  stdout_file = sanitize_one_line(case.get("stdoutFile") or "")
  stderr_file = sanitize_one_line(case.get("stderrFile") or "")

  parts = [f"`{case_id}`", f"({case_type}, {d}ms)"]
  if status:
    parts.append(f"status={status}")
  if message:
    parts.append(f"message={message}")
  if stdout_file:
    parts.append(f"stdout=`{stdout_file}`")
  if stderr_file:
    parts.append(f"stderr=`{stderr_file}`")
  return " - " + " ".join(parts)

print("")
print(f"### Failed ({len(failed_cases)})")
if not failed_cases:
  print("- none")
else:
  shown = failed_cases[:max_failed] if max_failed > 0 else failed_cases
  for c in shown:
    print(render_case_line(c))
  if max_failed > 0 and len(failed_cases) > max_failed:
    print(f"- …and {len(failed_cases) - max_failed} more failed cases")

print("")
print(f"### Slowest (Top {slow_n})")
if not slow_cases:
  print("- none")
else:
  for c in slow_cases:
    print(render_case_line(c))

if show_skipped:
  print("")
  print(f"### Skipped ({len(skipped_cases)})")
  if not skipped_cases:
    print("- none")
  else:
    shown = skipped_cases[:max_skipped] if max_skipped > 0 else skipped_cases
    for c in shown:
      print(render_case_line(c))
    if max_skipped > 0 and len(skipped_cases) > max_skipped:
      print(f"- …and {len(skipped_cases) - max_skipped} more skipped cases")
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
