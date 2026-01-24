#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  plan_batches.sh --file <plan.md> --sprint <n> [--format json|text]

Purpose:
  Compute dependency layers (parallel batches) for a sprint within a plan file.

Options:
  --file <path>     Plan file to parse (required)
  --sprint <n>      Sprint number to batch (required)
  --format <fmt>    json (default) or text
  -h, --help        Show help

Exit:
  0: success
  1: parse or cycle error
  2: usage error
USAGE
}

die() {
  echo "plan_batches: $1" >&2
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

file=""
sprint=""
format="json"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --file)
      file="${2:-}"
      [[ -n "$file" ]] || die "missing value for --file"
      shift 2
      ;;
    --sprint)
      sprint="${2:-}"
      [[ -n "$sprint" ]] || die "missing value for --sprint"
      shift 2
      ;;
    --format)
      format="${2:-}"
      [[ -n "$format" ]] || die "missing value for --format"
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

if [[ -z "$file" || -z "$sprint" ]]; then
  usage
  exit 2
fi

case "$format" in
  json|text) ;;
  *) die "invalid --format (expected json|text): $format" ;;
esac

python3 - "$plan_to_json_script" "$file" "$sprint" "$format" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict, deque
from pathlib import Path


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


plan_to_json = Path(sys.argv[1])


def run_plan_to_json(plan_path: Path) -> dict[str, object]:
    proc = subprocess.run(
        [str(plan_to_json), "--file", str(plan_path)],
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.strip() or f"plan_to_json failed (exit={proc.returncode})"
        raise RuntimeError(stderr)
    return json.loads(proc.stdout)


def topo_batches(nodes: list[str], edges: dict[str, set[str]]) -> list[list[str]]:
    # edges: node -> set(deps) (incoming dependencies)
    in_deg: dict[str, int] = {n: 0 for n in nodes}
    rev: dict[str, set[str]] = {n: set() for n in nodes}
    for n in nodes:
        for dep in edges.get(n, set()):
            if dep not in in_deg:
                continue
            in_deg[n] += 1
            rev[dep].add(n)

    q = deque(sorted([n for n in nodes if in_deg[n] == 0]))
    batches: list[list[str]] = []
    remaining = set(nodes)

    while remaining:
        batch = sorted([n for n in list(q)])
        q.clear()
        if not batch:
            # Cycle.
            cycle_hint = sorted(list(remaining))[:10]
            raise RuntimeError(f"dependency cycle detected (remaining: {cycle_hint})")

        batches.append(batch)
        for n in batch:
            if n not in remaining:
                continue
            remaining.remove(n)
            for m in sorted(rev.get(n, set())):
                in_deg[m] -= 1
                if in_deg[m] == 0:
                    q.append(m)

    return batches


def main() -> int:
    plan_file = Path(sys.argv[2])
    try:
        sprint_num = int(sys.argv[3])
    except ValueError:
        eprint(f"error: invalid --sprint (expected int): {sys.argv[3]!r}")
        return 2
    fmt = sys.argv[4]

    if not plan_file.is_file():
        eprint(f"error: plan file not found: {plan_file}")
        return 1

    try:
        data = run_plan_to_json(plan_file)
    except Exception as exc:
        eprint(f"error: {plan_file}: {exc}")
        return 1

    sprints = data.get("sprints") or []
    sprint = None
    for s in sprints:
        if isinstance(s, dict) and s.get("number") == sprint_num:
            sprint = s
            break
    if not sprint:
        eprint(f"error: {plan_file}: sprint not found: {sprint_num}")
        return 1

    tasks_raw = sprint.get("tasks") if isinstance(sprint, dict) else None
    if not isinstance(tasks_raw, list) or not tasks_raw:
        eprint(f"error: {plan_file}: sprint {sprint_num}: no tasks found")
        return 1

    tasks: dict[str, dict[str, object]] = {}
    for t in tasks_raw:
        if not isinstance(t, dict):
            continue
        tid = t.get("id")
        if isinstance(tid, str) and tid.strip():
            tasks[tid.strip()] = t

    if not tasks:
        eprint(f"error: {plan_file}: sprint {sprint_num}: no valid task IDs found")
        return 1

    task_ids = sorted(tasks.keys())
    internal_deps: dict[str, set[str]] = {tid: set() for tid in task_ids}
    external_deps: dict[str, list[str]] = {}

    for tid in task_ids:
        deps = tasks[tid].get("dependencies")
        deps_list: list[str] = []
        if isinstance(deps, list):
            deps_list = [d.strip() for d in deps if isinstance(d, str) and d.strip()]
        in_sprint = sorted([d for d in deps_list if d in tasks])
        out_sprint = sorted([d for d in deps_list if d not in tasks])
        internal_deps[tid] = set(in_sprint)
        if out_sprint:
            external_deps[tid] = out_sprint

    try:
        batches = topo_batches(task_ids, internal_deps)
    except Exception as exc:
        eprint(f"error: {plan_file}: sprint {sprint_num}: {exc}")
        return 1

    # Conflict risk: if multiple tasks in a batch list the same Location path.
    conflict_risk: list[dict[str, object]] = []
    for idx, batch in enumerate(batches):
        path_to_tasks: dict[str, list[str]] = defaultdict(list)
        for tid in batch:
            loc = tasks[tid].get("location")
            if not isinstance(loc, list):
                continue
            for p in loc:
                if isinstance(p, str) and p.strip():
                    path_to_tasks[p.strip()].append(tid)
        overlaps = sorted([p for p, owners in path_to_tasks.items() if len(set(owners)) > 1])
        if overlaps:
            conflict_risk.append({"batch": idx + 1, "overlap": overlaps})

    result: dict[str, object] = {
        "file": str(data.get("file") or plan_file.as_posix()),
        "sprint": sprint_num,
        "batches": batches,
        "blocked_by_external": external_deps,
        "conflict_risk": conflict_risk,
    }

    if fmt == "json":
        sys.stdout.write(json.dumps(result, ensure_ascii=False))
        sys.stdout.write("\n")
        return 0

    # text
    sys.stdout.write(f"Plan: {result['file']}\n")
    sys.stdout.write(f"Sprint: {sprint_num}\n")
    for i, batch in enumerate(batches, start=1):
        sys.stdout.write(f"\nBatch {i}:\n")
        for tid in batch:
            sys.stdout.write(f"- {tid}\n")
    if external_deps:
        sys.stdout.write("\nExternal blockers:\n")
        for tid, deps in sorted(external_deps.items()):
            sys.stdout.write(f"- {tid}: {', '.join(deps)}\n")
    if conflict_risk:
        sys.stdout.write("\nConflict risk (overlapping Location paths):\n")
        for item in conflict_risk:
            sys.stdout.write(f"- Batch {item['batch']}: {', '.join(item['overlap'])}\n")
    return 0


raise SystemExit(main())
PY
