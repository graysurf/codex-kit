#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $CODEX_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh [--skill-dir <path>] [--help]

Validates that each tracked skill directory contains only the allowed top-level
entries:
  - SKILL.md
  - scripts/    (optional)
  - bin/        (optional)
  - references/ (optional)
  - assets/     (optional)
  - tests/      (required)

With `--skill-dir`, audits a single skill directory on disk (useful for
validating a newly-created, not-yet-tracked skill skeleton).

Also enforces:
  - Markdown files with TEMPLATE in the filename must live under `references/`
    or `assets/templates/` within the skill directory.

Notes:
  - Default mode: checks tracked skills (`git ls-files skills/**/SKILL.md`) and
    tracked files only.
  - With `--skill-dir`: checks that directory on disk (including untracked
    files), but ignores common untracked junk at the skill top level.
USAGE
}

skill_dir_arg=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --skill-dir)
      if [[ $# -lt 2 ]]; then
        echo "error: --skill-dir requires a path" >&2
        usage >&2
        exit 2
      fi
      skill_dir_arg="${2:-}"
      shift 2
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

python3 - "$skill_dir_arg" <<'PY'
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ALLOWED_TOP_LEVEL = {"SKILL.md", "scripts", "bin", "references", "assets", "tests"}
ALLOWED_TEMPLATE_PREFIXES = (("references",), ("assets", "templates"))
IGNORED_UNTRACKED_TOP_LEVEL = {".DS_Store", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache"}


def git_ls_files(*patterns: str) -> list[str]:
    cmd = ["git", "ls-files", "--"]
    cmd.extend(patterns)
    out = subprocess.check_output(cmd, text=True)
    return [line for line in out.splitlines() if line.strip()]

def normalize_skill_dir_arg(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        raise ValueError("empty --skill-dir")

    p = Path(raw)
    if p.is_absolute():
        try:
            p = p.resolve().relative_to(Path.cwd())
        except ValueError as exc:
            raise ValueError(f"--skill-dir must be under repo root: {raw}") from exc

    # Normalize and keep it repo-relative.
    normalized = p.as_posix().lstrip("./")
    if ".." in Path(normalized).parts:
        raise ValueError(f"--skill-dir must not contain '..': {raw}")
    if not normalized.startswith("skills/"):
        raise ValueError(f"--skill-dir must start with skills/: {raw}")
    return normalized.rstrip("/")


skill_dir_arg = sys.argv[1].strip() if len(sys.argv) > 1 else ""

skill_md_paths: list[str]
skill_dirs: list[str]
tracked_skill_files: list[str]

if skill_dir_arg:
    skill_dir = normalize_skill_dir_arg(skill_dir_arg)
    root = Path(skill_dir)
    if not root.is_dir():
        print(f"error: {skill_dir}: skill dir not found", file=sys.stderr)
        raise SystemExit(1)
    if not (root / "SKILL.md").is_file():
        print(f"error: {skill_dir}: missing SKILL.md", file=sys.stderr)
        raise SystemExit(1)
    skill_dirs = [skill_dir]

    # File-system scan (not tracked) for a single dir.
    tracked_skill_files = [p.as_posix() for p in root.rglob("*") if p.is_file()]
else:
    skill_md_paths = sorted(git_ls_files("skills/**/SKILL.md"))
    if not skill_md_paths:
        print("ok: 0 tracked skills (nothing to audit)")
        raise SystemExit(0)

    skill_dirs = sorted({str(Path(p).parent) for p in skill_md_paths})
    tracked_skill_files = sorted(git_ls_files("skills/**"))

skill_dir_set = {Path(p) for p in skill_dirs}

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

    top = rel.parts[0]
    if skill_dir_arg and top in IGNORED_UNTRACKED_TOP_LEVEL:
        continue
    top_level_by_skill.setdefault(owner, set()).add(top)

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
    missing = []
    if "SKILL.md" not in tops:
        missing.append("SKILL.md")
    if "tests" not in tops:
        missing.append("tests/")

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

if skill_dir_arg:
    print(f"ok: 1 skill audited: {skill_dirs[0]}")
else:
    print(f"ok: {len(skill_dirs)} tracked skills audited")
PY
