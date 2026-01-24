#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  validate_plans.sh [--file <path>]...

Purpose:
  Lint plan markdown files under docs/plans/ against Plan Format v1.

Options:
  --file <path>  Validate a specific plan file (may be repeated)
  -h, --help     Show help

Defaults:
  With no --file args, validates tracked `docs/plans/*-plan.md` files.

Exit:
  0: all validated files are compliant
  1: validation errors found
  2: usage error
USAGE
}

die() {
  echo "validate_plans: $1" >&2
  exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_root="$(cd "${script_dir}/.." && pwd -P)"
codex_home="${CODEX_HOME:-}"
if [[ -z "$codex_home" || ! -d "$codex_home" ]]; then
  codex_home="$(cd "${skill_root}/../../../.." && pwd -P)"
fi
export CODEX_HOME="$codex_home"
repo_root="$codex_home"
cd "$repo_root"
plan_to_json_script="${script_dir%/}/plan_to_json.sh"

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
    echo "validate_plans: error: $cmd is required" >&2
    exit 1
  fi
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "validate_plans: error: must run inside a git work tree" >&2
  exit 1
}

if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git ls-files -- 'docs/plans/*-plan.md' | LC_ALL=C sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(find docs/plans -maxdepth 1 -type f -name '*-plan.md' 2>/dev/null | LC_ALL=C sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  exit 0
fi

python3 - "$plan_to_json_script" "${files[@]}" <<'PY'
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


TASK_ID_RE = re.compile(r"^Task [0-9]+\.[0-9]+$")
PLACEHOLDER_RE = re.compile(r"(<[^>]+>|\\bTBD\\b|\\bTODO\\b)", re.IGNORECASE)


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


plan_to_json = Path(sys.argv[1])


def run_plan_to_json(plan_path: Path) -> tuple[int, str, str]:
    proc = subprocess.run(
        [str(plan_to_json), "--file", str(plan_path)],
        text=True,
        capture_output=True,
        check=False,
    )
    return (proc.returncode, proc.stdout, proc.stderr)


def has_placeholder(value: str) -> bool:
    return bool(PLACEHOLDER_RE.search(value))


def is_non_empty_list(value: object) -> bool:
    return isinstance(value, list) and any(isinstance(x, str) and x.strip() for x in value)


def validate_task(plan: Path, task: dict[str, object], all_task_ids: set[str]) -> list[str]:
    errs: list[str] = []
    task_id = str(task.get("id") or "").strip()
    prefix = f"{plan}:{task_id}" if task_id else f"{plan}:<unknown task>"

    if not task_id or not TASK_ID_RE.match(task_id):
        errs.append(f"{prefix}: invalid or missing task id")

    location = task.get("location")
    if not is_non_empty_list(location):
        errs.append(f"{prefix}: missing Location (must be a non-empty list)")
    else:
        for loc in location:  # type: ignore[assignment]
            if not isinstance(loc, str) or not loc.strip():
                continue
            if loc.strip().startswith("/"):
                errs.append(f"{prefix}: Location must be repo-relative (no leading '/'): {loc!r}")
            if loc.strip().endswith("/"):
                errs.append(f"{prefix}: Location must be a file path (not a directory): {loc!r}")
            if any(ch in loc for ch in ["*", "?", "{", "}"]):
                errs.append(f"{prefix}: Location must not use globs/braces: {loc!r}")
            if has_placeholder(loc):
                errs.append(f"{prefix}: Location contains placeholder: {loc!r}")

    desc = task.get("description")
    if not isinstance(desc, str) or not desc.strip():
        errs.append(f"{prefix}: missing Description")
    elif has_placeholder(desc):
        errs.append(f"{prefix}: Description contains placeholder: {desc!r}")

    deps = task.get("dependencies")
    if deps is None:
        errs.append(f"{prefix}: missing Dependencies (use 'none' or list task IDs)")
    elif not isinstance(deps, list):
        errs.append(f"{prefix}: Dependencies must be a list (or 'none')")
    else:
        for dep in deps:
            if not isinstance(dep, str) or not dep.strip():
                continue
            if not TASK_ID_RE.match(dep.strip()):
                errs.append(f"{prefix}: invalid dependency (expected 'Task N.M'): {dep!r}")
            elif dep.strip() not in all_task_ids:
                errs.append(f"{prefix}: unknown dependency (not found in plan): {dep.strip()!r}")

    complexity = task.get("complexity")
    if complexity is not None:
        if not isinstance(complexity, int):
            errs.append(f"{prefix}: Complexity must be an int (1-10)")
        elif complexity < 1 or complexity > 10:
            errs.append(f"{prefix}: Complexity out of range (1-10): {complexity}")

    ac = task.get("acceptance_criteria")
    if not is_non_empty_list(ac):
        errs.append(f"{prefix}: missing Acceptance criteria (must be a non-empty list)")
    else:
        for item in ac:  # type: ignore[assignment]
            if isinstance(item, str) and has_placeholder(item):
                errs.append(f"{prefix}: Acceptance criteria contains placeholder: {item!r}")

    val = task.get("validation")
    if not is_non_empty_list(val):
        errs.append(f"{prefix}: missing Validation (must be a non-empty list)")
    else:
        for cmd in val:  # type: ignore[assignment]
            if isinstance(cmd, str) and has_placeholder(cmd):
                errs.append(f"{prefix}: Validation contains placeholder: {cmd!r}")

    return errs


def validate_plan(plan_path: Path) -> list[str]:
    rc, out, err = run_plan_to_json(plan_path)
    if rc != 0:
        # plan_to_json already prints error: lines; keep output but normalize the prefix.
        raw = [line for line in err.splitlines() if line.strip()]
        if not raw:
            return [f"{plan_path}: failed to parse plan (exit={rc})"]
        return [f"{plan_path}: {line}" if not line.startswith("error:") else f"{plan_path}: {line}" for line in raw]

    try:
        data = json.loads(out)
    except Exception as exc:
        return [f"{plan_path}: plan_to_json emitted invalid JSON: {exc}"]

    sprints = data.get("sprints")
    if not isinstance(sprints, list) or not sprints:
        return [f"{plan_path}: missing sprints (expected '## Sprint N: ...' headings)"]

    tasks: list[dict[str, object]] = []
    for sprint in sprints:
        if not isinstance(sprint, dict):
            continue
        sprint_tasks = sprint.get("tasks")
        if isinstance(sprint_tasks, list):
            for t in sprint_tasks:
                if isinstance(t, dict):
                    tasks.append(t)

    if not tasks:
        return [f"{plan_path}: no tasks found (expected '### Task N.M: ...' headings)"]

    all_task_ids = {str(t.get("id")).strip() for t in tasks if isinstance(t.get("id"), str)}
    errs: list[str] = []
    for task in tasks:
        errs.extend(validate_task(plan_path, task, all_task_ids))
    return errs


paths = [Path(p) for p in sys.argv[2:]]
if not paths:
    eprint("validate_plans: error: no files provided")
    raise SystemExit(1)

errors: list[str] = []
for path in paths:
    if not path.is_file():
        errors.append(f"{path}: file not found")
        continue
    errors.extend(validate_plan(path))

if errors:
    for err in errors:
        eprint(f"error: {err}")
    raise SystemExit(1)
PY
