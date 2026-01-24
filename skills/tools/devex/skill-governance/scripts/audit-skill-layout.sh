#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-skill-layout.sh [--help]

Validates that each tracked skill directory contains only the allowed top-level
entries:
  - SKILL.md
  - scripts/    (optional)
  - references/ (optional)
  - assets/     (optional)

Also enforces:
  - Markdown files with TEMPLATE in the filename must live under `references/`
    or `assets/templates/` within the skill directory.

Notes:
  - Only checks tracked skills (`git ls-files skills/**/SKILL.md`).
  - Only checks tracked files (ignores untracked junk like .DS_Store).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
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

python3 - <<'PY'
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ALLOWED_TOP_LEVEL = {"SKILL.md", "scripts", "references", "assets"}
ALLOWED_TEMPLATE_PREFIXES = (("references",), ("assets", "templates"))


def git_ls_files(*patterns: str) -> list[str]:
    cmd = ["git", "ls-files", "--"]
    cmd.extend(patterns)
    out = subprocess.check_output(cmd, text=True)
    return [line for line in out.splitlines() if line.strip()]


skill_md_paths = sorted(git_ls_files("skills/**/SKILL.md"))
if not skill_md_paths:
    print("ok: 0 tracked skills (nothing to audit)")
    raise SystemExit(0)

skill_dirs = sorted({str(Path(p).parent) for p in skill_md_paths})
skill_dir_set = {Path(p) for p in skill_dirs}

tracked_skill_files = sorted(git_ls_files("skills/**"))

errors: list[str] = []
top_level_by_skill: dict[Path, set[str]] = {Path(p): set() for p in skill_dirs}

for raw in tracked_skill_files:
    path = Path(raw)
    if path.is_dir():
        continue

    owner: Path | None = None
    for parent in (path.parent, *path.parents):
        if parent in skill_dir_set:
            owner = parent
            break

    if owner is None:
        continue

    try:
        rel = path.relative_to(owner)
    except ValueError:
        continue

    if not rel.parts:
        continue

    top_level_by_skill.setdefault(owner, set()).add(rel.parts[0])

    if path.suffix.lower() == ".md" and "template" in path.name.lower():
        allowed = any(tuple(rel.parts[: len(prefix)]) == prefix for prefix in ALLOWED_TEMPLATE_PREFIXES)
        if not allowed:
            errors.append(
                f"{owner}: template markdown must live under references/ or assets/templates/: {rel.as_posix()}"
            )
for skill_dir_str in skill_dirs:
    skill_dir = Path(skill_dir_str)
    tops = top_level_by_skill.get(skill_dir, set())
    unexpected = sorted([t for t in tops if t not in ALLOWED_TOP_LEVEL])
    missing = [] if "SKILL.md" in tops else ["SKILL.md"]

    if missing:
        errors.append(f"{skill_dir}: missing tracked {', '.join(missing)}")
    if unexpected:
        allowed = ", ".join(sorted(ALLOWED_TOP_LEVEL))
        errors.append(
            f"{skill_dir}: unexpected top-level entries: {', '.join(unexpected)} (allowed: {allowed})"
        )

if errors:
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    raise SystemExit(1)

print(f"ok: {len(skill_dirs)} tracked skills audited")
PY
