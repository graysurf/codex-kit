#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  audit-skill-paths.sh [--file <path>]...

Purpose:
  Validate `$CODEX_HOME/...` path references inside tracked `skills/**/SKILL.md`.

Rules:
  - `$CODEX_HOME/...` paths must exist relative to the repo root.
  - `$CODEX_HOME/...$CODEX_HOME/...` (duplicated segments) is not allowed.

Options:
  --file <path>  Validate a specific SKILL.md file (may be repeated)
  -h, --help     Show help

Defaults:
  With no --file args, validates tracked `skills/**/SKILL.md` files.

Exit:
  0: all validated files are compliant
  1: validation errors found
  2: usage error
USAGE
}

die() {
  echo "audit-skill-paths: $1" >&2
  exit 2
}

files=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --file)
      if [[ $# -lt 2 ]]; then
        die "--file requires a path"
      fi
      files+=("${2:-}")
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

for cmd in git python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "audit-skill-paths: error: $cmd is required" >&2
    exit 1
  fi
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "audit-skill-paths: error: must run inside a git work tree" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git ls-files -- 'skills/**/SKILL.md' | LC_ALL=C sort)
fi

python3 - "$repo_root" "${files[@]}" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
paths = [Path(p) for p in sys.argv[2:]]

CODEX_RE = re.compile(r"\$CODEX_HOME/[^\s`\"')>]+")

errors: list[str] = []

def e(msg: str) -> None:
    errors.append(msg)

for raw_path in paths:
    path = raw_path
    if not path.is_absolute():
        path = (repo_root / path).resolve()

    if not path.is_file():
        e(f"{raw_path}: file not found")
        continue

    text = path.read_text("utf-8", errors="replace")
    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in CODEX_RE.finditer(line):
            token = m.group(0)

            if token.count("$CODEX_HOME") > 1:
                e(f"{raw_path}:{lineno}: duplicated $CODEX_HOME segment: {token!r}")
                continue

            rel = token[len("$CODEX_HOME/") :]
            candidate = repo_root / rel
            if not candidate.exists():
                e(f"{raw_path}:{lineno}: path not found: {token!r}")

if errors:
    for msg in errors:
        print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)
PY
