#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate_skill_contracts.sh [--file <path>]...

Validates that each SKILL.md contains a `## Contract` section with the required
headings in exact order:
  Prereqs:
  Inputs:
  Outputs:
  Exit codes:
  Failure modes:

Notes:
  - By default, checks all `skills/**/SKILL.md` files in the current git repo.
  - `--file` may be repeated to validate specific files (useful for smoke tests).
  - The heading check is scoped to the `## Contract` section only (until the next `## ` heading or EOF).
USAGE
}

files=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --file)
      if [[ $# -lt 2 ]]; then
        echo "error: --file requires a path" >&2
        usage >&2
        exit 1
      fi
      files+=("${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1}" >&2
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

if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git ls-files -- 'skills/**/SKILL.md' | LC_ALL=C sort)
fi

python3 - "${files[@]}" <<'PY'
import sys
from pathlib import Path

required = ["Prereqs:", "Inputs:", "Outputs:", "Exit codes:", "Failure modes:"]

def die(msg: str) -> None:
  print(f"error: {msg}", file=sys.stderr)

def check_file(path: Path) -> list[str]:
  raw = path.read_text("utf-8", errors="replace").splitlines()

  try:
    start = next(i for i, line in enumerate(raw) if line.strip() == "## Contract")
  except StopIteration:
    return ["missing ## Contract"]

  end = len(raw)
  for i in range(start + 1, len(raw)):
    line = raw[i]
    if line.startswith("## ") and line.strip() != "## Contract":
      end = i
      break

  block = [line.strip() for line in raw[start + 1 : end]]
  problems: list[str] = []
  last_idx = -1
  for h in required:
    try:
      idx = block.index(h)
    except ValueError:
      problems.append(f"missing {h}")
      continue
    if idx <= last_idx:
      problems.append(f"out of order {h}")
    last_idx = idx
  return problems

paths = [Path(p) for p in sys.argv[1:]]
if not paths:
  die("no files to validate")
  raise SystemExit(1)

errors: list[str] = []
for p in paths:
  if not p.is_file():
    errors.append(f"{p}: file not found")
    continue

  problems = check_file(p)
  if not problems:
    continue

  missing = [x for x in problems if x.startswith("missing ")]
  order = [x for x in problems if x.startswith("out of order ")]

  if missing:
    errors.append(f"{p}: {', '.join(missing)}")
  if order:
    errors.append(
      f"{p}: headings out of order in ## Contract (expected: {', '.join(required)})"
    )

if errors:
  for e in errors:
    die(e)
  raise SystemExit(1)
PY
