#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $CODEX_HOME/skills/tools/skill-management/remove-skill/scripts/remove_skill.sh \
    --skill-dir <skills/.../skill-name> \
    [--dry-run] \
    [--yes] \
    [--help]

Deletes a skill directory and purges repo references (excluding
`docs/progress/archived/**`).

Notes:
  - This is a breaking change tool. It does not create compatibility shims.
  - Writes to the working tree and index (uses `git rm`); does not commit.
USAGE
}

skill_dir_raw=""
dry_run="0"
assume_yes="0"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --skill-dir)
      if [[ $# -lt 2 ]]; then
        echo "error: --skill-dir requires a path" >&2
        usage >&2
        exit 2
      fi
      skill_dir_raw="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run="1"
      shift
      ;;
    --yes)
      assume_yes="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$skill_dir_raw" ]]; then
  echo "error: --skill-dir is required" >&2
  usage >&2
  exit 2
fi

for cmd in git python3 rg; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required" >&2
    exit 1
  fi
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "error: must run inside a git work tree" >&2
  exit 1
fi

cd "$repo_root"

skill_dir="$(
  python3 - "$repo_root" "$skill_dir_raw" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
raw = sys.argv[2].strip()

if not raw:
    print("error: empty --skill-dir", file=sys.stderr)
    raise SystemExit(2)

p = Path(raw)
if p.is_absolute():
    try:
        p = p.resolve().relative_to(repo_root)
    except ValueError:
        print(f"error: --skill-dir must be under repo root: {raw}", file=sys.stderr)
        raise SystemExit(2)

normalized = p.as_posix().lstrip("./").rstrip("/")
if ".." in Path(normalized).parts:
    print(f"error: --skill-dir must not contain '..': {raw}", file=sys.stderr)
    raise SystemExit(2)
if not normalized.startswith("skills/"):
    print(f"error: --skill-dir must start with skills/: {raw}", file=sys.stderr)
    raise SystemExit(2)

print(normalized)
PY
)"

if [[ ! -d "$skill_dir" ]]; then
  echo "error: skill dir not found: $skill_dir" >&2
  exit 1
fi
if [[ ! -f "$skill_dir/SKILL.md" ]]; then
  echo "error: missing SKILL.md: $skill_dir" >&2
  exit 1
fi

mapfile -t skill_scripts < <(find "$skill_dir/scripts" -type f 2>/dev/null | LC_ALL=C sort || true)
spec_files=()
for s in "${skill_scripts[@]}"; do
  rel="${s#"$repo_root/"}"
  rel="${rel#./}"
  spec="tests/script_specs/${rel}.json"
  if [[ -f "$spec" ]]; then
    spec_files+=("$spec")
  fi
done

if [[ "$assume_yes" != "1" ]]; then
  echo "About to remove:" >&2
  echo "  - $skill_dir" >&2
  for spec in "${spec_files[@]}"; do
    echo "  - $spec" >&2
  done
  echo "This will also edit tracked Markdown files (excluding docs/progress/archived/**) to remove references." >&2
  echo -n "Proceed? (y/N): " >&2
  read -r reply
  case "${reply:-}" in
    y|Y|yes|YES) ;;
    *) echo "cancelled" >&2; exit 1 ;;
  esac
fi

if [[ "$dry_run" == "1" ]]; then
  echo "dry-run: would git rm + delete $skill_dir and ${#spec_files[@]} spec file(s)" >&2
else
  for spec in "${spec_files[@]}"; do
    git rm --ignore-unmatch -- "$spec" >/dev/null 2>&1 || true
    rm -f -- "$spec" >/dev/null 2>&1 || true
  done

  git rm -r --ignore-unmatch -- "$skill_dir" >/dev/null 2>&1 || true
  rm -rf -- "$skill_dir" >/dev/null 2>&1 || true
fi

python3 - "$skill_dir" "$dry_run" <<'PY'
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

skill_dir = sys.argv[1]
dry_run = sys.argv[2] == "1"

EXCLUDED_PREFIXES = (
    "docs/progress/archived/",
    "out/",
    "tmp/",
)

patterns = (
    f"$CODEX_HOME/{skill_dir}",
    f"./{skill_dir}",
    f"{skill_dir}/",
    f"{skill_dir}",
)

tracked = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
md_files = [p for p in tracked if p.endswith(".md") and not any(p.startswith(x) for x in EXCLUDED_PREFIXES)]

edited: list[str] = []
for rel in md_files:
    path = Path(rel)
    try:
        raw = path.read_text("utf-8")
    except UnicodeDecodeError:
        continue
    if not any(p in raw for p in patterns):
        continue

    lines = raw.splitlines(keepends=True)
    kept = [line for line in lines if not any(p in line for p in patterns)]
    if kept == lines:
        continue
    if dry_run:
        edited.append(rel)
        continue
    path.write_text("".join(kept).rstrip("\n") + "\n", "utf-8")
    edited.append(rel)

if edited:
    msg = "dry-run: would edit" if dry_run else "edited"
    print(f"{msg}: {len(edited)} markdown file(s)", file=sys.stderr)
PY

if [[ "$dry_run" == "1" ]]; then
  echo "dry-run: ok"
  exit 0
fi

python3 - "$skill_dir" <<'PY'
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

skill_dir = sys.argv[1]

EXCLUDED_PREFIXES = (
    "docs/progress/archived/",
    "out/",
    "tmp/",
)

patterns = (
    f"$CODEX_HOME/{skill_dir}",
    f"./{skill_dir}",
    f"{skill_dir}/",
    f"{skill_dir}",
)

tracked = subprocess.check_output(["git", "ls-files"], text=True).splitlines()

remaining: list[tuple[str, str]] = []
for rel in tracked:
    if any(rel.startswith(x) for x in EXCLUDED_PREFIXES):
        continue
    p = Path(rel)
    if not p.is_file():
        continue
    if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif", ".pdf"}:
        continue
    try:
        raw = p.read_text("utf-8")
    except UnicodeDecodeError:
        continue
    for pat in patterns:
        if pat in raw:
            remaining.append((rel, pat))
            break

if remaining:
    for rel, pat in remaining:
        print(f"error: remaining reference ({pat}): {rel}", file=sys.stderr)
    raise SystemExit(1)
PY

echo "ok: removed $skill_dir"
