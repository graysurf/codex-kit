#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  plan_to_json.sh --file <plan.md> [--sprint <n>] [--pretty]

Purpose:
  Parse a plan markdown file (Plan Format v1) into a stable JSON schema.

Options:
  --file <path>   Plan file to parse (required)
  --sprint <n>    Only include a single sprint number (optional)
  --pretty        Pretty-print JSON (indent=2)
  -h, --help      Show help

Exit:
  0: parsed successfully (JSON on stdout)
  1: parse error (prints error: lines to stderr)
  2: usage error
USAGE
}

die() {
  echo "plan_to_json: $1" >&2
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

file=""
sprint=""
pretty="0"

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
    --pretty)
      pretty="1"
      shift
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

if [[ -z "$file" ]]; then
  usage
  exit 2
fi

python_bin="${repo_root}/.venv/bin/python"
if [[ ! -x "$python_bin" ]]; then
  python_bin="$(command -v python3 || true)"
fi
if [[ -z "$python_bin" ]]; then
  echo "plan_to_json: error: python3 not found" >&2
  exit 1
fi

"$python_bin" - "$file" "$sprint" "$pretty" <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path


SPRINT_RE = re.compile(r"^## Sprint (?P<num>[0-9]+):\s*(?P<name>.+?)\s*$")
TASK_RE = re.compile(r"^### Task (?P<sprint>[0-9]+)\.(?P<seq>[0-9]+):\s*(?P<name>.+?)\s*$")
FIELD_RE = re.compile(
    r"^\s*-\s+\*\*(?P<field>Location|Description|Dependencies|Complexity|Acceptance criteria|Validation)\*\*:\s*(?P<rest>.*)\s*$"
)
BULLET_RE = re.compile(r"^(?P<indent>\s*)-\s+(?P<text>.*)\s*$")


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def strip_inline_code(text: str) -> str:
    t = text.strip()
    if len(t) >= 2 and t.startswith("`") and t.endswith("`"):
        t = t[1:-1]
    return t.strip()


def normalize_task_id(sprint_num: int, seq_num: int) -> str:
    return f"Task {sprint_num}.{seq_num}"


@dataclass
class Task:
    id: str
    name: str
    sprint: int
    start_line: int
    location: list[str]
    description: str | None
    dependencies: list[str] | None
    complexity: int | None
    acceptance_criteria: list[str]
    validation: list[str]


@dataclass
class Sprint:
    number: int
    name: str
    start_line: int
    tasks: list[Task]


def parse_list_block(lines: list[str], start_idx: int, base_indent: int) -> tuple[list[str], int]:
    items: list[str] = []
    i = start_idx
    while i < len(lines):
        raw = lines[i]
        if not raw.strip():
            i += 1
            continue

        m = BULLET_RE.match(raw)
        if not m:
            break

        indent = len(m.group("indent"))
        if indent <= base_indent:
            break

        items.append(strip_inline_code(m.group("text")))
        i += 1

    return items, i


def parse_plan(path: Path) -> tuple[dict[str, object], list[str]]:
    errors: list[str] = []
    raw_lines = path.read_text("utf-8", errors="replace").splitlines()

    plan_title = ""
    for line in raw_lines:
        if line.startswith("# "):
            plan_title = line[2:].strip()
            break

    sprints: list[Sprint] = []
    current_sprint: Sprint | None = None
    current_task: Task | None = None

    def finish_task() -> None:
        nonlocal current_task, current_sprint
        if current_task is None:
            return
        if current_sprint is None:
            errors.append(f"{path}:{current_task.start_line}: task outside of any sprint: {current_task.id}")
            current_task = None
            return
        current_sprint.tasks.append(current_task)
        current_task = None

    def finish_sprint() -> None:
        nonlocal current_sprint
        if current_sprint is None:
            return
        sprints.append(current_sprint)
        current_sprint = None

    i = 0
    while i < len(raw_lines):
        line = raw_lines[i]

        m_sprint = SPRINT_RE.match(line)
        if m_sprint:
            finish_task()
            finish_sprint()
            current_sprint = Sprint(
                number=int(m_sprint.group("num")),
                name=m_sprint.group("name").strip(),
                start_line=i + 1,
                tasks=[],
            )
            i += 1
            continue

        m_task = TASK_RE.match(line)
        if m_task:
            finish_task()
            sprint_num = int(m_task.group("sprint"))
            seq_num = int(m_task.group("seq"))
            current_task = Task(
                id=normalize_task_id(sprint_num, seq_num),
                name=m_task.group("name").strip(),
                sprint=sprint_num,
                start_line=i + 1,
                location=[],
                description=None,
                dependencies=None,
                complexity=None,
                acceptance_criteria=[],
                validation=[],
            )
            i += 1
            continue

        if current_task is None:
            i += 1
            continue

        m_field = FIELD_RE.match(line)
        if not m_field:
            i += 1
            continue

        field = m_field.group("field")
        rest = m_field.group("rest").strip()
        base_indent = len(line) - len(line.lstrip(" "))
        next_idx = i + 1

        if field == "Description":
            current_task.description = rest or ""
            i += 1
            continue

        if field == "Complexity":
            if rest:
                try:
                    current_task.complexity = int(rest)
                except ValueError:
                    errors.append(f"{path}:{i+1}: invalid Complexity (expected int): {rest!r}")
            i += 1
            continue

        if field in {"Location", "Dependencies", "Acceptance criteria", "Validation"}:
            items: list[str]
            if rest:
                items = [strip_inline_code(rest)]
                next_idx = i + 1
            else:
                items, next_idx = parse_list_block(raw_lines, i + 1, base_indent)

            if field == "Location":
                current_task.location.extend([x for x in items if x.strip()])
            elif field == "Dependencies":
                current_task.dependencies = [x for x in items if x.strip()]
            elif field == "Acceptance criteria":
                current_task.acceptance_criteria.extend([x for x in items if x.strip()])
            elif field == "Validation":
                current_task.validation.extend([x for x in items if x.strip()])

            i = next_idx
            continue

        i += 1

    finish_task()
    finish_sprint()

    # Normalize dependencies: allow "none" (case-insensitive) as empty list.
    for sprint in sprints:
        for task in sprint.tasks:
            deps = task.dependencies
            if deps is None:
                continue
            normalized: list[str] = []
            for d in deps:
                if not d:
                    continue
                if d.strip().lower() == "none":
                    continue
                parts = [p.strip() for p in d.split(",") if p.strip()]
                normalized.extend(parts)
            task.dependencies = normalized

    obj: dict[str, object] = {
        "title": plan_title,
        "file": path.as_posix(),
        "sprints": [
            {
                "number": s.number,
                "name": s.name,
                "start_line": s.start_line,
                "tasks": [
                    {
                        "id": t.id,
                        "name": t.name,
                        "sprint": t.sprint,
                        "start_line": t.start_line,
                        "location": t.location,
                        "description": t.description,
                        "dependencies": t.dependencies,
                        "complexity": t.complexity,
                        "acceptance_criteria": t.acceptance_criteria,
                        "validation": t.validation,
                    }
                    for t in s.tasks
                ],
            }
            for s in sprints
        ],
    }
    return obj, errors


def maybe_relativize(path: Path, repo_root: Path) -> Path:
    try:
        return path.resolve().relative_to(repo_root.resolve())
    except Exception:
        return path.resolve()


def main() -> int:
    file_arg = sys.argv[1]
    sprint_arg = sys.argv[2].strip() if len(sys.argv) > 2 else ""
    pretty = sys.argv[3].strip() if len(sys.argv) > 3 else "0"

    plan_path = Path(file_arg)
    if not plan_path.is_file():
        eprint(f"error: plan file not found: {plan_path}")
        return 1

    repo_root = Path(os.getcwd())
    rel_path = maybe_relativize(plan_path, repo_root)

    obj, errors = parse_plan(plan_path)
    obj["file"] = rel_path.as_posix()

    if sprint_arg:
        try:
            want = int(sprint_arg)
        except ValueError:
            eprint(f"error: invalid --sprint (expected int): {sprint_arg!r}")
            return 2
        sprints = obj.get("sprints") or []
        obj["sprints"] = [s for s in sprints if s.get("number") == want]  # type: ignore[assignment]

    if errors:
        for err in errors:
            eprint(f"error: {err}")
        return 1

    indent = 2 if pretty == "1" else None
    sys.stdout.write(json.dumps(obj, ensure_ascii=False, indent=indent))
    sys.stdout.write("\n")
    return 0


raise SystemExit(main())
PY
