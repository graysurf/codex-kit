#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_dir="$(cd "${script_dir}/.." && pwd -P)"
repo_root_default="$(cd "${skill_dir}/../../.." && pwd -P)"
agent_home="${AGENT_HOME:-$repo_root_default}"

issue_delivery_script="${repo_root_default}/skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh"
if [[ ! -x "$issue_delivery_script" ]]; then
  issue_delivery_script="${agent_home%/}/skills/automation/issue-delivery-loop/scripts/manage_issue_delivery_loop.sh"
fi

issue_lifecycle_script="${repo_root_default}/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh"
if [[ ! -x "$issue_lifecycle_script" ]]; then
  issue_lifecycle_script="${agent_home%/}/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh"
fi

issue_lifecycle_template="${repo_root_default}/skills/workflows/issue/issue-lifecycle/references/ISSUE_TEMPLATE.md"
if [[ ! -f "$issue_lifecycle_template" ]]; then
  issue_lifecycle_template="${agent_home%/}/skills/workflows/issue/issue-lifecycle/references/ISSUE_TEMPLATE.md"
fi

issue_subagent_script="${repo_root_default}/skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh"
if [[ ! -x "$issue_subagent_script" ]]; then
  issue_subagent_script="${agent_home%/}/skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh"
fi

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="${1:-}"
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
}

is_positive_int() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

is_valid_pr_grouping() {
  case "${1:-}" in
    per-sprint|per-spring|group)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_pr_grouping_args() {
  local mode="${1:-}"
  local mapping_count="${2:-0}"
  [[ -n "$mode" ]] || die "--pr-grouping is required (per-sprint|group)"
  is_valid_pr_grouping "$mode" || die "--pr-grouping must be one of: per-sprint, group"
  if [[ "$mode" == "group" && "$mapping_count" -eq 0 ]]; then
    die "--pr-grouping group requires at least one --pr-group <task-or-plan-id>=<group> entry"
  fi
  if [[ "$mode" != "group" && "$mapping_count" -gt 0 ]]; then
    die "--pr-group can only be used when --pr-grouping group"
  fi
}

join_lines() {
  local joined=''
  local item=''
  for item in "$@"; do
    if [[ -n "$joined" ]]; then
      joined+=$'\n'
    fi
    joined+="$item"
  done
  printf '%s' "$joined"
}

print_cmd() {
  local out=''
  local arg=''
  for arg in "$@"; do
    out+=" $(printf '%q' "$arg")"
  done
  printf '%s\n' "${out# }"
}

ensure_entrypoints() {
  [[ -x "$issue_delivery_script" ]] || die "missing executable: $issue_delivery_script"
  [[ -x "$issue_lifecycle_script" ]] || die "missing executable: $issue_lifecycle_script"
  [[ -x "$issue_subagent_script" ]] || die "missing executable: $issue_subagent_script"
  [[ -f "$issue_lifecycle_template" ]] || die "missing file: $issue_lifecycle_template"
}

validate_plan() {
  local plan_file="${1:-}"
  [[ -n "$plan_file" ]] || die "plan file path is required"
  [[ -f "$plan_file" ]] || die "plan file not found: $plan_file"
  require_cmd plan-tooling
  plan-tooling validate --file "$plan_file" >/dev/null
}

validate_approval_comment_url_format() {
  local url="${1:-}"
  python3 - "$url" <<'PY'
import re
import sys

url = sys.argv[1].strip()
pat = re.compile(r"^https://github\.com/[^/]+/[^/]+/(issues|pull)/\d+#issuecomment-\d+$")
if not pat.match(url):
    raise SystemExit("error: invalid approval comment URL format")
print(url)
PY
}

plan_summary_tsv() {
  local plan_file="${1:-}"
  python3 - "$plan_file" <<'PY'
import json
import pathlib
import subprocess
import sys

plan = pathlib.Path(sys.argv[1])
if not plan.is_file():
    raise SystemExit(f"error: plan file not found: {plan}")

parsed = subprocess.run(
    ["plan-tooling", "to-json", "--file", str(plan)],
    check=True,
    capture_output=True,
    text=True,
)
data = json.loads(parsed.stdout)

plan_title = (data.get("title") or plan.stem).strip() or plan.stem
total_tasks = 0
max_sprint = 0
for sprint in data.get("sprints", []):
    num = int(sprint.get("number", 0))
    max_sprint = max(max_sprint, num)
    total_tasks += len(sprint.get("tasks", []))

print(f"{plan_title}\t{max_sprint}\t{total_tasks}")
PY
}

plan_sprint_meta_tsv() {
  local plan_file="${1:-}"
  local sprint="${2:-}"
  python3 - "$plan_file" "$sprint" <<'PY'
import json
import pathlib
import subprocess
import sys

plan = pathlib.Path(sys.argv[1])
sprint_raw = sys.argv[2].strip()

if not plan.is_file():
    raise SystemExit(f"error: plan file not found: {plan}")
if not sprint_raw.isdigit() or int(sprint_raw) <= 0:
    raise SystemExit(f"error: sprint must be a positive integer (got: {sprint_raw})")

sprint_num = int(sprint_raw)
parsed = subprocess.run(
    ["plan-tooling", "to-json", "--file", str(plan)],
    check=True,
    capture_output=True,
    text=True,
)
data = json.loads(parsed.stdout)

max_sprint = 0
target = None
for sprint in data.get("sprints", []):
    number = int(sprint.get("number", 0))
    max_sprint = max(max_sprint, number)
    if number == sprint_num:
        target = sprint

if target is None:
    raise SystemExit(f"error: sprint {sprint_num} not found (max sprint: {max_sprint})")

name = (target.get("name") or "").strip() or f"Sprint {sprint_num}"
task_count = len(target.get("tasks", []))
print(f"{name}\t{task_count}\t{max_sprint}")
PY
}

default_plan_task_spec_path() {
  local plan_file="${1:-}"
  local plan_base plan_stem
  plan_base="$(basename "$plan_file")"
  plan_stem="${plan_base%.md}"
  printf '%s/out/plan-issue-delivery-loop/%s-plan-tasks.tsv\n' \
    "${agent_home%/}" \
    "$plan_stem"
}

default_plan_issue_body_path() {
  local plan_file="${1:-}"
  local plan_base plan_stem
  plan_base="$(basename "$plan_file")"
  plan_stem="${plan_base%.md}"
  printf '%s/out/plan-issue-delivery-loop/%s-plan-issue-body.md\n' \
    "${agent_home%/}" \
    "$plan_stem"
}

default_sprint_task_spec_path() {
  local plan_file="${1:-}"
  local sprint="${2:-}"
  local plan_base plan_stem
  plan_base="$(basename "$plan_file")"
  plan_stem="${plan_base%.md}"
  printf '%s/out/plan-issue-delivery-loop/%s-sprint-%s-tasks.tsv\n' \
    "${agent_home%/}" \
    "$plan_stem" \
    "$sprint"
}

default_dry_run_issue_number() {
  printf 'DRY_RUN_PLAN_ISSUE\n'
}

issue_read_body_cmd() {
  local issue_number="${1:-}"
  local out_file="${2:-}"
  local repo_arg="${3:-}"
  [[ -n "$issue_number" ]] || die "issue number is required"
  [[ -n "$out_file" ]] || die "output file path is required"

  require_cmd gh
  local cmd=(gh issue view "$issue_number")
  if [[ -n "$repo_arg" ]]; then
    cmd+=(-R "$repo_arg")
  fi
  cmd+=(--json body -q .body)
  "${cmd[@]}" >"$out_file"
}

cleanup_plan_issue_worktrees() {
  local issue_number="${1:-}"
  local repo_arg="${2:-}"
  local dry_run="${3:-0}"
  local body_file_override="${4:-}"

  require_cmd git
  require_cmd python3

  local body_file=''
  local cleanup_body_file='0'
  if [[ -n "$body_file_override" ]]; then
    [[ -f "$body_file_override" ]] || die "body file not found: $body_file_override"
    body_file="$body_file_override"
  else
    [[ -n "$issue_number" ]] || die "--issue is required for worktree cleanup"
    body_file="$(mktemp)"
    cleanup_body_file='1'
    issue_read_body_cmd "$issue_number" "$body_file" "$repo_arg"
  fi

  set +e
  python3 - "$body_file" "$dry_run" <<'PY'
import os
import pathlib
import subprocess
import sys

body_file = pathlib.Path(sys.argv[1])
dry_run = sys.argv[2].strip() == "1"


def is_placeholder(value: str) -> bool:
    token = (value or "").strip().lower()
    if token in {"", "-", "tbd", "none", "n/a", "na", "..."}:
        return True
    if token.startswith("<") and token.endswith(">"):
        return True
    if "task ids" in token:
        return True
    return False


def parse_row(line: str) -> list[str]:
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return []
    return [cell.strip() for cell in s[1:-1].split("|")]


def section_bounds(lines: list[str], heading: str) -> tuple[int, int]:
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == heading:
            start = idx + 1
            break
    if start is None:
        raise SystemExit(f"error: missing required heading: {heading}")
    end = len(lines)
    for idx in range(start, len(lines)):
        if lines[idx].startswith("## "):
            end = idx
            break
    return start, end


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, capture_output=True, text=True)


def list_worktrees() -> list[tuple[str, str]]:
    output = run(["git", "worktree", "list", "--porcelain"]).stdout.splitlines()
    rows: list[tuple[str, str]] = []
    current_path = ""
    current_branch = ""
    for line in output + [""]:
        if not line.strip():
            if current_path:
                rows.append((current_path, current_branch))
            current_path = ""
            current_branch = ""
            continue
        if line.startswith("worktree "):
            current_path = line[len("worktree ") :].strip()
            continue
        if line.startswith("branch "):
            ref = line[len("branch ") :].strip()
            if ref.startswith("refs/heads/"):
                ref = ref[len("refs/heads/") :]
            current_branch = ref
    return rows


text = body_file.read_text(encoding="utf-8")
lines = text.splitlines()
start, end = section_bounds(lines, "## Task Decomposition")
table_lines = [line for line in lines[start:end] if line.strip().startswith("|")]
if len(table_lines) < 3:
    raise SystemExit("error: Task Decomposition must contain a markdown table with at least one task row")

headers = parse_row(table_lines[0])
required_columns = ["Task", "Branch", "Worktree"]
missing = [col for col in required_columns if col not in headers]
if missing:
    raise SystemExit("error: missing Task Decomposition columns: " + ", ".join(missing))

records: list[tuple[str, str, str]] = []
for raw in table_lines[2:]:
    cells = parse_row(raw)
    if not cells:
        continue
    if len(cells) != len(headers):
        raise SystemExit("error: malformed Task Decomposition row")
    row = {headers[idx]: cells[idx] for idx in range(len(headers))}
    task = row.get("Task", "").strip()
    if not task:
        continue
    records.append((task, row.get("Branch", "").strip(), row.get("Worktree", "").strip()))

if not records:
    raise SystemExit("error: Task Decomposition table must include at least one task row")

repo_root = pathlib.Path(run(["git", "rev-parse", "--show-toplevel"]).stdout.strip()).resolve()
main_worktree = str(repo_root)
default_worktrees_root = (repo_root / ".." / ".worktrees" / repo_root.name / "issue").resolve()

expected_branches: set[str] = set()
expected_worktree_names: set[str] = set()
expected_paths: set[str] = set()

for _task, branch, worktree in records:
    if not is_placeholder(branch):
        expected_branches.add(branch)
    if is_placeholder(worktree):
        continue
    token = worktree.strip()
    expected_worktree_names.add(pathlib.Path(token).name)
    token_path = pathlib.Path(token)
    if token_path.is_absolute():
        expected_paths.add(str(token_path.resolve()))
    else:
        if "/" in token or token.startswith("."):
            expected_paths.add(str((repo_root / token).resolve()))
        expected_paths.add(str((default_worktrees_root / token).resolve()))

if not expected_branches and not expected_worktree_names and not expected_paths:
    print("WORKTREE_CLEANUP_STATUS=SKIP_NO_TARGETS")
    raise SystemExit(0)

targets: dict[str, list[str]] = {}
for path_raw, branch in list_worktrees():
    path = str(pathlib.Path(path_raw).resolve())
    if path == main_worktree:
        continue
    reasons: list[str] = []
    if branch and branch in expected_branches:
        reasons.append(f"branch:{branch}")
    if path in expected_paths:
        reasons.append("path")
    if pathlib.Path(path).name in expected_worktree_names:
        reasons.append(f"name:{pathlib.Path(path).name}")
    if reasons:
        targets[path] = sorted(set(reasons))

errors: list[str] = []
removed = 0

for path in sorted(targets):
    reason_text = ",".join(targets[path])
    if dry_run:
        print(f"DRY_RUN_WORKTREE_REMOVE={path} ({reason_text})")
        continue
    proc = subprocess.run(["git", "worktree", "remove", "--force", path], capture_output=True, text=True)
    if proc.returncode != 0:
        message = (proc.stderr or proc.stdout or "").strip() or f"exit {proc.returncode}"
        errors.append(f"{path}: {message}")
    else:
        removed += 1
        print(f"WORKTREE_REMOVED={path} ({reason_text})")

if dry_run:
    print(f"WORKTREE_CLEANUP_DRY_RUN_TARGETS={len(targets)}")
    raise SystemExit(0)

prune_proc = subprocess.run(["git", "worktree", "prune"], capture_output=True, text=True)
if prune_proc.returncode != 0:
    message = (prune_proc.stderr or prune_proc.stdout or "").strip() or f"exit {prune_proc.returncode}"
    errors.append(f"git worktree prune failed: {message}")

remaining: list[str] = []
for path_raw, branch in list_worktrees():
    path = str(pathlib.Path(path_raw).resolve())
    if path == main_worktree:
        continue
    reasons: list[str] = []
    if branch and branch in expected_branches:
        reasons.append(f"branch:{branch}")
    if path in expected_paths:
        reasons.append("path")
    if pathlib.Path(path).name in expected_worktree_names:
        reasons.append(f"name:{pathlib.Path(path).name}")
    if reasons:
        remaining.append(f"{path} ({','.join(sorted(set(reasons)))})")

lingering_paths = []
for path in sorted(expected_paths):
    if path != main_worktree and os.path.exists(path):
        lingering_paths.append(path)

for message in errors:
    print(f"error: worktree cleanup remove failed: {message}", file=sys.stderr)
for message in remaining:
    print(f"error: worktree cleanup residual git worktree: {message}", file=sys.stderr)
for path in lingering_paths:
    print(f"error: worktree cleanup residual path exists: {path}", file=sys.stderr)

if errors or remaining or lingering_paths:
    raise SystemExit(1)

print(f"WORKTREE_CLEANUP_REMOVED={removed}")
print("WORKTREE_CLEANUP_STATUS=PASS")
PY
  local cleanup_rc=$?
  set -e

  if [[ "$cleanup_body_file" == '1' ]]; then
    rm -f "$body_file"
  fi
  return "$cleanup_rc"
}

render_plan_issue_body_from_task_spec() {
  local template_file="${1:-}"
  local plan_file="${2:-}"
  local plan_title="${3:-}"
  local task_spec_file="${4:-}"
  local out_file="${5:-}"

  python3 - "$template_file" "$plan_file" "$plan_title" "$task_spec_file" "$out_file" <<'PY'
import csv
import pathlib
import sys

template_path = pathlib.Path(sys.argv[1])
plan_file = sys.argv[2].strip()
plan_title = sys.argv[3].strip() or pathlib.Path(plan_file).stem
task_spec_path = pathlib.Path(sys.argv[4])
out_path = pathlib.Path(sys.argv[5])

if not template_path.is_file():
    raise SystemExit(f"error: template file not found: {template_path}")
if not task_spec_path.is_file():
    raise SystemExit(f"error: task spec file not found: {task_spec_path}")

rows = []
with task_spec_path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle, delimiter="\t")
    for raw in reader:
        if not raw:
            continue
        if raw[0].strip().startswith("#"):
            continue
        if len(raw) < 6:
            raise SystemExit("error: malformed task spec row")
        task_id = raw[0].strip()
        summary = raw[1].strip()
        branch = raw[2].strip()
        worktree = raw[3].strip()
        owner = raw[4].strip()
        notes = raw[5].strip() if len(raw) >= 6 else ""
        rows.append((task_id, summary, owner, branch, worktree, notes))

if not rows:
    raise SystemExit("error: task spec contains no rows")

text = template_path.read_text(encoding="utf-8")
lines = text.splitlines()

if lines and lines[0].startswith("# "):
    lines[0] = f"# {plan_title}"


def replace_section(heading: str, body_lines: list[str]) -> None:
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == heading:
            start = idx
            break
    if start is None:
        raise SystemExit(f"error: missing heading in template: {heading}")
    end = len(lines)
    for idx in range(start + 1, len(lines)):
        if lines[idx].startswith("## "):
            end = idx
            break
    new_block = [lines[start], ""] + body_lines + [""]
    lines[:] = lines[:start] + new_block + lines[end:]


goal_lines = [
    f"- Execute plan `{plan_file}` end-to-end using one GitHub issue and subagent-owned PRs.",
    f"- Track sprint progress via issue comments while keeping task/PR state in the issue body.",
]
acceptance_lines = [
    "- All in-scope plan tasks are implemented via subagent PRs and linked in the issue task table.",
    "- Final plan review approval comment URL is recorded.",
    "- The single plan issue closes after close-gate checks pass.",
]
scope_lines = [
    f"- In-scope: tasks defined in `{plan_file}`",
    "- Out-of-scope: work not represented in the plan task list",
]
risk_lines = [
    "- Sprint approvals may be recorded before final close; issue stays open until final plan acceptance.",
    "- Close gate fails if task statuses or PR merge states in the issue body are incomplete.",
]
evidence_lines = [
    f"- Plan source: `{plan_file}`",
    "- Sprint approvals: issue comments (one comment per accepted sprint)",
    "- Final approval: issue/pull comment URL passed to `close-plan`",
]

task_table_lines = [
    "| Task | Summary | Owner | Branch | Worktree | Execution Mode | PR | Status | Notes |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
]
for task_id, summary, owner, branch, worktree, notes in rows:
    note_val = notes if notes else "-"
    task_table_lines.append(
        f"| {task_id} | {summary} | TBD | TBD | TBD | TBD | TBD | planned | {note_val} |"
    )

replace_section("## Goal", goal_lines)
replace_section("## Acceptance Criteria", acceptance_lines)
replace_section("## Scope", scope_lines)
replace_section("## Task Decomposition", task_table_lines)
replace_section("## Risks / Uncertainties", risk_lines)
replace_section("## Evidence", evidence_lines)

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(out_path)
PY
}

render_task_spec_from_plan_scope() {
  local plan_file="${1:-}"
  local scope_kind="${2:-}"   # plan | sprint
  local scope_value="${3:-}"  # ignored for plan
  local task_spec_out="${4:-}"
  local owner_prefix="${5:-subagent}"
  local branch_prefix="${6:-issue}"
  local worktree_prefix="${7:-issue__}"
  local pr_grouping="${8:-}"
  local pr_group_entries="${9:-}"

  python3 - "$plan_file" "$scope_kind" "$scope_value" "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_entries" <<'PY'
import json
import pathlib
import re
import subprocess
import sys

plan = pathlib.Path(sys.argv[1])
scope_kind = sys.argv[2].strip()
scope_value = sys.argv[3].strip()
output_path = pathlib.Path(sys.argv[4])
owner_prefix = sys.argv[5].strip() or "subagent"
branch_prefix = sys.argv[6].strip() or "issue"
worktree_prefix = sys.argv[7].strip() or "issue__"
pr_grouping = sys.argv[8].strip()
pr_group_entries_raw = sys.argv[9]
if pr_grouping == "per-spring":
    pr_grouping = "per-sprint"

if not plan.is_file():
    raise SystemExit(f"error: plan file not found: {plan}")
if scope_kind not in {"plan", "sprint"}:
    raise SystemExit(f"error: unsupported scope_kind: {scope_kind}")
if scope_kind == "sprint" and (not scope_value.isdigit() or int(scope_value) <= 0):
    raise SystemExit(f"error: sprint must be a positive integer (got: {scope_value})")
if pr_grouping not in {"per-sprint", "group"}:
    raise SystemExit(f"error: unsupported pr-grouping mode: {pr_grouping}")

parsed = subprocess.run(
    ["plan-tooling", "to-json", "--file", str(plan)],
    check=True,
    capture_output=True,
    text=True,
)
data = json.loads(parsed.stdout)
sprints = data.get("sprints", [])

selected = []
if scope_kind == "plan":
    selected = [s for s in sprints if s.get("tasks")]
    if not selected:
        raise SystemExit("error: plan has no tasks")
else:
    sprint_num = int(scope_value)
    for sprint in sprints:
        if int(sprint.get("number", 0)) == sprint_num:
            selected = [sprint]
            break
    if not selected:
        raise SystemExit(f"error: sprint {sprint_num} not found")
    if not selected[0].get("tasks"):
        raise SystemExit(f"error: sprint {sprint_num} has no tasks")


def slugify(value: str, fallback: str) -> str:
    text = value.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    if not text:
        text = fallback
    return text[:48]


def normalize_group_key(value: str, fallback: str) -> str:
    token = re.sub(r"[^a-z0-9]+", "-", (value or "").strip().lower()).strip("-")
    if not token:
        token = fallback
    return token[:48]


def is_placeholder(value: str) -> bool:
    token = (value or "").strip().lower()
    if token in {"", "-", "none", "n/a", "na"}:
        return True
    if token.startswith("<") and token.endswith(">"):
        return True
    if token == "...":
        return True
    if "task ids" in token:
        return True
    return False

normalized_owner_prefix = owner_prefix
if "subagent" not in normalized_owner_prefix.lower():
    normalized_owner_prefix = f"subagent-{normalized_owner_prefix}"

branch_prefix_norm = branch_prefix.rstrip("/") or "issue"
worktree_prefix_norm = worktree_prefix.rstrip("-_") or "issue"

task_records = []
for sprint in selected:
    sprint_num = int(sprint.get("number", 0))
    tasks = sprint.get("tasks", []) or []
    for idx, task in enumerate(tasks, start=1):
        task_id = f"S{sprint_num}T{idx}"
        plan_task_id = (task.get("id") or "").strip()
        task_name = (task.get("name") or task.get("id") or f"task-{idx}").strip()
        summary = re.sub(r"\s+", " ", task_name).strip() or f"sprint-{sprint_num}-task-{idx}"
        slug = slugify(summary, f"task-{idx}")

        branch = f"{branch_prefix_norm}/s{sprint_num}-t{idx}-{slug}"
        worktree = f"{worktree_prefix_norm}-s{sprint_num}-t{idx}"
        owner = f"{normalized_owner_prefix}-s{sprint_num}-t{idx}"

        deps = []
        for dep in task.get("dependencies", []) or []:
            dep_text = str(dep).strip()
            if not is_placeholder(dep_text):
                deps.append(dep_text)

        validations = []
        for item in task.get("validation", []) or []:
            text = str(item).strip()
            if not is_placeholder(text):
                validations.append(text)

        notes_parts = [f"sprint=S{sprint_num}", f"plan-task:{plan_task_id or task_id}"]
        if deps:
            notes_parts.append("deps=" + ",".join(deps))
        if validations:
            notes_parts.append("validate=" + validations[0])

        task_records.append(
            {
                "task_id": task_id,
                "plan_task_id": plan_task_id,
                "sprint_num": sprint_num,
                "summary": summary,
                "branch": branch,
                "worktree": worktree,
                "owner": owner,
                "dependencies": deps,
                "notes_parts": notes_parts,
            }
        )

if not task_records:
    raise SystemExit("error: selected scope has no tasks")

group_assignments = {}
assignment_sources = []
for raw_line in pr_group_entries_raw.splitlines():
    entry = raw_line.strip()
    if not entry:
        continue
    if "=" not in entry:
        raise SystemExit("error: --pr-group must use <task-or-plan-id>=<group> format")
    raw_key, raw_group = entry.split("=", 1)
    key = raw_key.strip()
    group_key = normalize_group_key(raw_group, "")
    if not key or not group_key:
        raise SystemExit("error: --pr-group must include both task key and group")
    assignment_sources.append(key)
    group_assignments[key] = group_key
    group_assignments[key.casefold()] = group_key

if pr_grouping == "group" and not group_assignments:
    raise SystemExit("error: --pr-grouping group requires at least one --pr-group entry")
if pr_grouping != "group" and group_assignments:
    raise SystemExit("error: --pr-group can only be used when --pr-grouping group")

if pr_grouping == "group":
    known_keys = set()
    for rec in task_records:
        known_keys.add(rec["task_id"].casefold())
        if rec["plan_task_id"]:
            known_keys.add(rec["plan_task_id"].casefold())
    unknown = [key for key in assignment_sources if key.casefold() not in known_keys]
    if unknown:
        preview = ", ".join(unknown[:5])
        raise SystemExit(f"error: --pr-group references unknown task keys: {preview}")

if pr_grouping == "group":
    missing = []
    for idx, rec in enumerate(task_records):
        group_key = ""
        for key in (rec["task_id"], rec["plan_task_id"]):
            if not key:
                continue
            group_key = group_assignments.get(key) or group_assignments.get(key.casefold(), "")
            if group_key:
                break
        if not group_key:
            missing.append(rec["task_id"])
            continue
        rec["pr_group"] = group_key
    if missing:
        preview = ", ".join(missing[:8])
        raise SystemExit(
            "error: --pr-grouping group requires explicit mapping for every task; missing: "
            + preview
        )
else:
    for rec in task_records:
        sprint_num = rec["sprint_num"]
        rec["pr_group"] = normalize_group_key(f"s{sprint_num}", f"sprint-{sprint_num}")

group_sizes = {}
group_anchor = {}
for rec in task_records:
    group_key = rec["pr_group"]
    group_sizes[group_key] = group_sizes.get(group_key, 0) + 1
    if group_key not in group_anchor:
        group_anchor[group_key] = rec

output_path.parent.mkdir(parents=True, exist_ok=True)
lines = ["# task_id\tsummary\tbranch\tworktree\towner\tnotes\tpr_group"]

for rec in task_records:
    notes_parts = list(rec["notes_parts"])
    notes_parts.append(f"pr-grouping={pr_grouping}")
    notes_parts.append(f"pr-group={rec['pr_group']}")
    if group_sizes[rec["pr_group"]] > 1:
        notes_parts.append(f"shared-pr-anchor={group_anchor[rec['pr_group']]['task_id']}")
    notes = "; ".join(notes_parts)
    row = [
        rec["task_id"].replace("\t", " "),
        rec["summary"].replace("\t", " "),
        rec["branch"].replace("\t", " "),
        rec["worktree"].replace("\t", " "),
        rec["owner"].replace("\t", " "),
        notes.replace("\t", " "),
        rec["pr_group"].replace("\t", " "),
    ]
    lines.append("\t".join(row))

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(output_path)
PY
}

run_issue_delivery() {
  local dry_run="${1:-0}"
  local repo_arg="${2:-}"
  shift 2

  local cmd=("$issue_delivery_script" "$@")
  if [[ -n "$repo_arg" ]]; then
    cmd+=(--repo "$repo_arg")
  fi
  if [[ "$dry_run" == "1" ]]; then
    cmd+=(--dry-run)
  fi
  "${cmd[@]}"
}

run_issue_lifecycle() {
  local dry_run="${1:-0}"
  local repo_arg="${2:-}"
  shift 2

  local cmd=("$issue_lifecycle_script" "$@")
  if [[ -n "$repo_arg" ]]; then
    cmd+=(--repo "$repo_arg")
  fi
  if [[ "$dry_run" == "1" ]]; then
    cmd+=(--dry-run)
  fi
  "${cmd[@]}"
}

read_optional_text() {
  local inline_text="${1:-}"
  local file_path="${2:-}"
  if [[ -n "$inline_text" && -n "$file_path" ]]; then
    die "use either inline text or file path, not both"
  fi
  if [[ -n "$file_path" ]]; then
    [[ -f "$file_path" ]] || die "file not found: $file_path"
    cat "$file_path"
    return 0
  fi
  printf '%s' "$inline_text"
}

emit_dispatch_hints() {
  local task_spec_file="${1:-}"
  local issue_number="${2:-}"
  local issue_subagent_entrypoint="${3:-}"

  python3 - "$task_spec_file" "$issue_number" "$issue_subagent_entrypoint" <<'PY'
import csv
import pathlib
import shlex
import sys

spec_path = pathlib.Path(sys.argv[1])
issue_number = sys.argv[2].strip()
subagent_entrypoint = sys.argv[3].strip()

if not spec_path.is_file():
    raise SystemExit(f"error: task spec file not found: {spec_path}")

rows = []
with spec_path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle, delimiter="\t")
    for raw in reader:
        if not raw:
            continue
        if raw[0].strip().startswith("#"):
            continue
        if len(raw) < 5:
            raise SystemExit("error: malformed task spec row")
        task_id = raw[0].strip()
        summary = raw[1].strip() if len(raw) >= 2 else ""
        branch = raw[2].strip() if len(raw) >= 3 else ""
        worktree = raw[3].strip() if len(raw) >= 4 else ""
        owner = raw[4].strip() if len(raw) >= 5 else "subagent"
        pr_group = raw[6].strip() if len(raw) >= 7 else task_id
        rows.append(
            {
                "task_id": task_id,
                "summary": summary,
                "branch": branch,
                "worktree": worktree,
                "owner": owner,
                "pr_group": pr_group or task_id,
            }
        )

groups = {}
group_order = []
for row in rows:
    key = row["pr_group"] or row["task_id"]
    if key not in groups:
        groups[key] = []
        group_order.append(key)
    groups[key].append(row)

print("DISPATCH_HINTS_BEGIN")
for group_key in group_order:
    group_rows = groups[group_key]
    leader = group_rows[0]
    summary = leader["summary"] or leader["task_id"]
    if len(group_rows) > 1:
        summary = f"{summary} (+{len(group_rows) - 1} tasks)"
    pr_title = f"feat: {summary}"
    open_cmd = (
        f"{shlex.quote(subagent_entrypoint)} open-pr "
        f"--issue {shlex.quote(issue_number or '<issue-number>')} "
        f"--title {shlex.quote(pr_title)} "
        f"--head {shlex.quote(leader['branch'])} --use-template"
    )
    task_list = ",".join(row["task_id"] for row in group_rows)
    print(f"PR_GROUP={group_key} HEAD={leader['branch']} TASK_COUNT={len(group_rows)} TASKS={task_list}")
    for idx, row in enumerate(group_rows):
        create_cmd = (
            f"{shlex.quote(subagent_entrypoint)} create-worktree "
            f"--branch {shlex.quote(row['branch'])} --base main --worktree-name {shlex.quote(row['worktree'])}"
        )
        print(f"TASK={row['task_id']} OWNER={row['owner']} PR_GROUP={group_key}")
        print(f"CREATE_WORKTREE_CMD={create_cmd}")
        if idx == 0:
            print(f"OPEN_PR_CMD={open_cmd}")
        else:
            print("OPEN_PR_CMD=SHARED_WITH_GROUP")
print("DISPATCH_HINTS_END")
PY
}

sync_issue_sprint_task_rows() {
  local issue_number="${1:-}"
  local task_spec_file="${2:-}"
  local repo_arg="${3:-}"
  local dry_run="${4:-0}"

  [[ -n "$issue_number" ]] || die "issue number is required for sprint task sync"
  [[ -f "$task_spec_file" ]] || die "task spec file not found: $task_spec_file"
  if [[ "$dry_run" == '1' ]]; then
    return 0
  fi

  local issue_body_file=''
  issue_body_file="$(mktemp)"
  issue_read_body_cmd "$issue_number" "$issue_body_file" "$repo_arg"

  local synced_body_file=''
  synced_body_file="$(mktemp)"

  python3 - "$issue_body_file" "$task_spec_file" "$synced_body_file" <<'PY'
import csv
import pathlib
import re
import sys

body_path = pathlib.Path(sys.argv[1])
task_spec_path = pathlib.Path(sys.argv[2])
output_path = pathlib.Path(sys.argv[3])

if not body_path.is_file():
    raise SystemExit(f"error: issue body file not found: {body_path}")
if not task_spec_path.is_file():
    raise SystemExit(f"error: task spec file not found: {task_spec_path}")

lines = body_path.read_text(encoding="utf-8").splitlines()


def section_bounds(heading: str) -> tuple[int, int]:
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == heading:
            start = idx + 1
            break
    if start is None:
        raise SystemExit(f"error: missing required heading: {heading}")
    end = len(lines)
    for idx in range(start, len(lines)):
        if lines[idx].startswith("## "):
            end = idx
            break
    return start, end


def parse_row(line: str) -> list[str]:
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return []
    return [cell.strip() for cell in s[1:-1].split("|")]


def is_placeholder(value: str) -> bool:
    token = (value or "").strip().lower().strip("`")
    if token in {"", "-", "tbd", "none", "n/a", "na", "..."}:
        return True
    if token.startswith("tbd"):
        return True
    if token.startswith("<") and token.endswith(">"):
        return True
    if "task ids" in token:
        return True
    return False


def normalize_pr_display(value: str) -> str:
    token = (value or "").strip()
    if is_placeholder(token):
        return "TBD"
    if m := re.fullmatch(r"PR#(\d+)", token, flags=re.IGNORECASE):
        return f"#{m.group(1)}"
    if m := re.fullmatch(r"#(\d+)", token):
        return f"#{m.group(1)}"
    if m := re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#(\d+)", token):
        return f"#{m.group(1)}"
    if m := re.fullmatch(
        r"https://github\.com/[^/\s]+/[^/\s]+/pull/(\d+)(?:[/?#].*)?",
        token,
        flags=re.IGNORECASE,
    ):
        return f"#{m.group(1)}"
    return token


def extract_note_value(notes: str, key: str) -> str:
    prefix = f"{key}="
    for part in notes.split(";"):
        token = part.strip()
        if token.lower().startswith(prefix):
            return token[len(prefix) :].strip()
    return ""


spec_rows: dict[str, dict[str, str]] = {}
group_sizes: dict[str, int] = {}
group_anchor: dict[str, dict[str, str]] = {}
with task_spec_path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle, delimiter="\t")
    for raw in reader:
        if not raw:
            continue
        if raw[0].strip().startswith("#"):
            continue
        if len(raw) < 7:
            raise SystemExit("error: malformed task spec row")
        task_id = raw[0].strip()
        summary = raw[1].strip()
        branch = raw[2].strip()
        worktree = raw[3].strip()
        owner = raw[4].strip()
        notes = raw[5].strip()
        pr_group = raw[6].strip() or task_id
        grouping_mode = extract_note_value(notes, "pr-grouping").lower()
        if not task_id:
            continue
        spec_rows[task_id] = {
            "summary": summary,
            "branch": branch,
            "worktree": worktree,
            "owner": owner,
            "notes": notes,
            "pr_group": pr_group,
            "grouping_mode": grouping_mode,
        }
        group_sizes[pr_group] = group_sizes.get(pr_group, 0) + 1
        if pr_group not in group_anchor:
            group_anchor[pr_group] = {
                "branch": branch,
                "worktree": worktree,
                "owner": owner,
            }

if not spec_rows:
    raise SystemExit("error: sprint task spec has no rows")

start, end = section_bounds("## Task Decomposition")
table_rows = [idx for idx in range(start, end) if lines[idx].strip().startswith("|")]
if len(table_rows) < 3:
    raise SystemExit("error: Task Decomposition must contain a markdown table with at least one task row")

header_line_index = table_rows[0]
headers = parse_row(lines[header_line_index])
required_columns = ["Task", "Owner", "Branch", "Worktree", "Execution Mode", "PR", "Status", "Notes"]
missing = [name for name in required_columns if name not in headers]
if missing:
    raise SystemExit("error: missing Task Decomposition columns: " + ", ".join(missing))
header_index = {name: idx for idx, name in enumerate(headers)}

for idx in table_rows[2:]:
    cells = parse_row(lines[idx])
    if not cells or len(cells) != len(headers):
        continue
    row_changed = False
    existing_pr = cells[header_index["PR"]]
    normalized_pr = normalize_pr_display(existing_pr)
    if existing_pr.strip() != normalized_pr:
        cells[header_index["PR"]] = normalized_pr
        row_changed = True

    task_id = cells[header_index["Task"]].strip()
    spec = spec_rows.get(task_id)
    if spec is not None:
        pr_group = spec["pr_group"]
        grouping_mode = spec.get("grouping_mode", "")
        if grouping_mode == "per-sprint":
            mode = "per-sprint"
            execution_source = group_anchor.get(pr_group, spec)
        elif grouping_mode == "group":
            mode = "single-pr"
            execution_source = group_anchor.get(pr_group, spec)
        else:
            mode = "single-pr"
            execution_source = group_anchor.get(pr_group, spec)

        cells[header_index["Owner"]] = execution_source["owner"] or cells[header_index["Owner"]]
        cells[header_index["Branch"]] = f"`{execution_source['branch']}`"
        cells[header_index["Worktree"]] = f"`{execution_source['worktree']}`"
        cells[header_index["Execution Mode"]] = mode
        if spec["notes"]:
            cells[header_index["Notes"]] = spec["notes"]
        row_changed = True

    if row_changed:
        lines[idx] = "| " + " | ".join(cells) + " |"

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(output_path)
PY

  run_issue_lifecycle "$dry_run" "$repo_arg" update --issue "$issue_number" --body-file "$synced_body_file" >/dev/null
  rm -f "$issue_body_file" "$synced_body_file"
}

render_sprint_comment_body() {
  local mode="${1:-}"   # start|ready|accepted
  local plan_file="${2:-}"
  local issue_number="${3:-}"
  local sprint="${4:-}"
  local sprint_name="${5:-}"
  local task_spec_file="${6:-}"
  local note_text="${7:-}"
  local approval_comment_url="${8:-}"
  local issue_body_file="${9:-}"

  python3 - "$mode" "$plan_file" "$issue_number" "$sprint" "$sprint_name" "$task_spec_file" "$note_text" "$approval_comment_url" "$issue_body_file" <<'PY'
import csv
import pathlib
import re
import sys

mode = sys.argv[1].strip()
plan_file = sys.argv[2].strip()
issue_number = sys.argv[3].strip()
sprint = sys.argv[4].strip()
sprint_name = sys.argv[5].strip()
spec_path = pathlib.Path(sys.argv[6])
note_text = sys.argv[7]
approval_url = sys.argv[8].strip()
issue_body_path_raw = sys.argv[9].strip()
issue_body_path = pathlib.Path(issue_body_path_raw) if issue_body_path_raw else None

if mode not in {"start", "ready", "accepted"}:
    raise SystemExit(f"error: unsupported sprint comment mode: {mode}")
if not spec_path.is_file():
    raise SystemExit(f"error: task spec file not found: {spec_path}")


def is_placeholder(value: str) -> bool:
    token = (value or "").strip().lower()
    if token in {"", "-", "tbd", "none", "n/a", "na", "..."}:
        return True
    if token.startswith("tbd"):
        return True
    if token.startswith("<") and token.endswith(">"):
        return True
    if "task ids" in token:
        return True
    return False


def normalize_pr_display(value: str) -> str:
    token = (value or "").strip()
    if is_placeholder(token):
        return ""
    if m := re.fullmatch(r"PR#(\d+)", token, flags=re.IGNORECASE):
        return f"#{m.group(1)}"
    if m := re.fullmatch(r"#(\d+)", token):
        return f"#{m.group(1)}"
    if m := re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#(\d+)", token):
        return f"#{m.group(1)}"
    if m := re.fullmatch(
        r"https://github\.com/[^/\s]+/[^/\s]+/pull/(\d+)(?:[/?#].*)?",
        token,
        flags=re.IGNORECASE,
    ):
        return f"#{m.group(1)}"
    return token


def parse_row(line: str) -> list[str]:
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return []
    return [cell.strip() for cell in s[1:-1].split("|")]


def extract_sprint_section(plan_path: pathlib.Path, sprint_number: str) -> str:
    if not plan_path.is_file():
        raise SystemExit(f"error: plan file not found: {plan_path}")

    lines = plan_path.read_text(encoding="utf-8").splitlines()
    target_re = re.compile(rf"^##\s+Sprint\s+{re.escape(sprint_number)}\b")

    start = None
    for idx, line in enumerate(lines):
        if target_re.match(line.strip()):
            start = idx
            break

    if start is None:
        return ""

    end = len(lines)
    for idx in range(start + 1, len(lines)):
        if lines[idx].startswith("## "):
            end = idx
            break

    return "\n".join(lines[start:end]).strip()


def section_bounds(lines: list[str], heading: str) -> tuple[int, int]:
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == heading:
            start = idx + 1
            break
    if start is None:
        raise SystemExit(f"error: missing required heading: {heading}")
    end = len(lines)
    for idx in range(start, len(lines)):
        if lines[idx].startswith("## "):
            end = idx
            break
    return start, end


def load_issue_pr_values(path: pathlib.Path | None) -> dict[str, str]:
    if path is None or not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    try:
        start, end = section_bounds(lines, "## Task Decomposition")
    except SystemExit:
        return {}
    table_lines = [line for line in lines[start:end] if line.strip().startswith("|")]
    if len(table_lines) < 3:
        return {}
    headers = parse_row(table_lines[0])
    if "Task" not in headers or "PR" not in headers:
        return {}

    pr_map: dict[str, str] = {}
    for raw in table_lines[2:]:
        cells = parse_row(raw)
        if not cells or len(cells) != len(headers):
            continue
        row = {headers[idx]: cells[idx] for idx in range(len(headers))}
        task = row.get("Task", "").strip()
        pr_value = row.get("PR", "").strip()
        if not task or is_placeholder(pr_value):
            continue
        pr_map[task] = pr_value
    return pr_map


def extract_note_value(notes: str, key: str) -> str:
    prefix = f"{key}="
    for part in notes.split(";"):
        token = part.strip()
        if token.lower().startswith(prefix):
            return token[len(prefix) :].strip()
    return ""

rows = []
with spec_path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle, delimiter="\t")
    for raw in reader:
        if not raw:
            continue
        if raw[0].strip().startswith("#"):
            continue
        if len(raw) < 5:
            raise SystemExit("error: malformed task spec row")
        task_id = raw[0].strip()
        summary = raw[1].strip() if len(raw) >= 2 else ""
        pr_group = raw[6].strip() if len(raw) >= 7 else task_id
        notes = raw[5].strip() if len(raw) >= 6 else ""
        grouping_mode = extract_note_value(notes, "pr-grouping").lower()
        rows.append((task_id, summary, pr_group or task_id, notes, grouping_mode))

group_sizes = {}
for _task_id, _summary, pr_group, _notes, _grouping_mode in rows:
    group_sizes[pr_group] = group_sizes.get(pr_group, 0) + 1
issue_pr_values = load_issue_pr_values(issue_body_path)
plan_path = pathlib.Path(plan_file)

if mode == "start":
    heading = f"## Sprint {sprint} Start"
    lead = "Main-agent starts this sprint on the plan issue and dispatches implementation to subagents."
elif mode == "ready":
    heading = f"## Sprint {sprint} Ready for Review"
    lead = "Main-agent requests sprint-level review/acceptance on the plan issue (the issue remains open)."
else:
    heading = f"## Sprint {sprint} Accepted"
    lead = "Main-agent records sprint acceptance on the plan issue and keeps the plan issue open for remaining sprints."

print(heading)
print("")
print(f"- Sprint: {sprint} ({sprint_name})")
print(f"- Tasks in sprint: {len(rows)}")
print(f"- Note: {lead}")
if mode == "start":
    print("- Execution Mode comes from current Task Decomposition for each sprint task.")
else:
    print("- PR values come from current Task Decomposition; unresolved tasks remain `TBD` until PRs are linked.")
if approval_url:
    print(f"- Approval comment URL: {approval_url}")
print("")
if mode == "start":
    print("| Task | Summary | Execution Mode |")
    print("| --- | --- | --- |")
    for task_id, summary, _pr_group, _notes, grouping_mode in rows:
        if grouping_mode == "per-sprint":
            execution_mode = "per-sprint"
        else:
            execution_mode = "single-pr"
        print(f"| {task_id} | {summary or '-'} | {execution_mode} |")
else:
    print("| Task | Summary | PR |")
    print("| --- | --- | --- |")
    for task_id, summary, pr_group, _notes, grouping_mode in rows:
        pr_value = normalize_pr_display(issue_pr_values.get(task_id, ""))
        if is_placeholder(pr_value):
            if grouping_mode == "per-sprint":
                pr_value = "TBD (per-sprint)"
            elif grouping_mode == "group":
                pr_value = f"TBD (group:{pr_group})"
            elif group_sizes.get(pr_group, 0) > 1:
                pr_value = f"TBD (shared:{pr_group})"
            else:
                pr_value = "TBD"
        print(f"| {task_id} | {summary or '-'} | {pr_value} |")

if mode == "start":
    sprint_section = extract_sprint_section(plan_path, sprint)
    if sprint_section:
        print("")
        print(sprint_section)

if note_text.strip():
    print("")
    print("## Main-Agent Notes")
    print("")
    print(note_text.strip())
PY
}

usage() {
  cat <<'USAGE'
Usage:
  plan-issue-delivery-loop.sh <subcommand> [options]

Subcommands:
  build-task-spec       Build sprint-scoped task-spec TSV from a plan
  build-plan-task-spec  Build plan-scoped task-spec TSV (all sprints) for the single plan issue
  start-plan            Open one plan issue with all plan tasks in Task Decomposition
  status-plan           Wrapper of issue-delivery-loop status for the plan issue
  ready-plan            Wrapper of issue-delivery-loop ready-for-review for final plan review
  close-plan            Close the single plan issue after final approval + merged PR gates, then enforce worktree cleanup
  cleanup-worktrees     Enforce cleanup of all issue-assigned task worktrees
  start-sprint          Post sprint-start comment on the plan issue and emit subagent dispatch hints
  ready-sprint          Post sprint-ready comment on the plan issue (issue stays open)
  accept-sprint         Post sprint-accepted comment on the plan issue (issue stays open)
  multi-sprint-guide    Print the full repeated command flow for a plan (1 plan = 1 issue)

Main-agent role boundary:
  - main-agent is orchestration/review-only
  - implementation must be subagent-owned PR work
  - the plan issue closes only after the final plan acceptance gate

Common options:
  --repo <owner/repo>  Pass-through repository target for GitHub operations
  --dry-run            Print write actions without mutating GitHub state

build-task-spec options (sprint scope):
  --plan <path>                  Plan markdown path (required)
  --sprint <number>              Sprint number (required)
  --task-spec-out <path>         Output TSV path (default: $AGENT_HOME/out/plan-issue-delivery-loop/...)
  --owner-prefix <text>          Default: subagent
  --branch-prefix <text>         Default: issue
  --worktree-prefix <text>       Default: issue__
  --pr-grouping <mode>           per-sprint | group (required; `per-spring` alias accepted)
  --pr-group <task=group>        Repeatable; group mode only; task can be SxTy or plan task id

build-plan-task-spec options:
  --plan <path>                  Plan markdown path (required)
  --task-spec-out <path>         Output TSV path (default: $AGENT_HOME/out/plan-issue-delivery-loop/...)
  --owner-prefix <text>          Default: subagent
  --branch-prefix <text>         Default: issue
  --worktree-prefix <text>       Default: issue__
  --pr-grouping <mode>           per-sprint | group (required; `per-spring` alias accepted)
  --pr-group <task=group>        Repeatable; group mode only; task can be SxTy or plan task id

start-plan options:
  --plan <path>                  Plan markdown path (required)
  --title <text>                 Override plan issue title
  --task-spec-out <path>         Plan task-spec output path override
  --issue-body-out <path>        Rendered plan issue body output path override
  --owner-prefix <text>          Default: subagent
  --branch-prefix <text>         Default: issue
  --worktree-prefix <text>       Default: issue__
  --pr-grouping <mode>           per-sprint | group (required; `per-spring` alias accepted)
  --pr-group <task=group>        Repeatable; group mode only; task can be SxTy or plan task id
  --label <name>                 Repeatable; default labels: issue, plan

status-plan options:
  --issue <number>               Plan issue number (required unless --body-file)
  --body-file <path>             Offline issue body
  --comment | --no-comment

ready-plan options:
  --issue <number>               Plan issue number (required unless --body-file)
  --body-file <path>             Offline issue body
  --summary <text> | --summary-file <path>
  --label <name>                 Review label (default: needs-review)
  --remove-label <name>          Repeatable
  --comment | --no-comment
  --no-label-update

close-plan options:
  --issue <number>               Plan issue number (required unless --body-file in --dry-run mode)
  --body-file <path>             Local issue body (dry-run only; no GitHub dependency)
  --approved-comment-url <url>   Final approval comment URL (required)
  --reason <completed|not planned>
  --comment <text> | --comment-file <path>
  --allow-not-done
  Note: after close gate succeeds, close-plan always runs strict worktree cleanup for issue task rows.

cleanup-worktrees options:
  --issue <number>               Plan issue number (required)
  --repo <owner/repo>            Optional repository override
  --dry-run                      Print matching worktrees without removing

start-sprint / ready-sprint / accept-sprint options:
  --plan <path>                  Plan markdown path (required)
  --issue <number>               Plan issue number (required)
  --sprint <number>              Sprint number (required)
  --task-spec-out <path>         Sprint task-spec output path override
  --owner-prefix <text>          Default: subagent
  --branch-prefix <text>         Default: issue
  --worktree-prefix <text>       Default: issue__
  --pr-grouping <mode>           per-sprint | group (required; `per-spring` alias accepted)
  --pr-group <task=group>        Repeatable; group mode only; task can be SxTy or plan task id
  --summary <text> | --summary-file <path>
  --comment | --no-comment       Default: comment when --issue is provided
  --approved-comment-url <url>   accept-sprint only (required)

multi-sprint-guide options:
  --plan <path>                  Plan markdown path (required)
  --from-sprint <number>         Default: 1
  --to-sprint <number>           Default: max sprint in plan
  --dry-run                      Print a local-only rehearsal flow (no GitHub calls)
USAGE
}

build_task_spec_cmd() {
  local plan_file=''
  local sprint=''
  local task_spec_out=''
  local owner_prefix='subagent'
  local branch_prefix='issue'
  local worktree_prefix='issue__'
  local pr_grouping=''
  local pr_group_entries=()

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --sprint)
        sprint="${2:-}"
        shift 2
        ;;
      --task-spec-out)
        task_spec_out="${2:-}"
        shift 2
        ;;
      --owner-prefix)
        owner_prefix="${2:-}"
        shift 2
        ;;
      --branch-prefix)
        branch_prefix="${2:-}"
        shift 2
        ;;
      --worktree-prefix)
        worktree_prefix="${2:-}"
        shift 2
        ;;
      --pr-grouping)
        pr_grouping="${2:-}"
        shift 2
        ;;
      --pr-group)
        pr_group_entries+=("${2:-}")
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for build-task-spec: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for build-task-spec"
  [[ -n "$sprint" ]] || die "--sprint is required for build-task-spec"
  is_positive_int "$sprint" || die "--sprint must be a positive integer"
  validate_pr_grouping_args "$pr_grouping" "${#pr_group_entries[@]}"

  validate_plan "$plan_file"

  local sprint_meta sprint_name sprint_task_count max_sprint
  sprint_meta="$(plan_sprint_meta_tsv "$plan_file" "$sprint")"
  IFS=$'\t' read -r sprint_name sprint_task_count max_sprint <<<"$sprint_meta"
  [[ "$sprint_task_count" -gt 0 ]] || die "sprint ${sprint} has no tasks"

  if [[ -z "$task_spec_out" ]]; then
    task_spec_out="$(default_sprint_task_spec_path "$plan_file" "$sprint")"
  fi

  local pr_group_config=''
  pr_group_config="$(join_lines "${pr_group_entries[@]}")"
  render_task_spec_from_plan_scope "$plan_file" sprint "$sprint" "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_config" >/dev/null

  printf 'PLAN_FILE=%s\n' "$plan_file"
  printf 'SCOPE=sprint\n'
  printf 'SPRINT=%s\n' "$sprint"
  printf 'SPRINT_NAME=%s\n' "$sprint_name"
  printf 'SPRINT_TASK_COUNT=%s\n' "$sprint_task_count"
  printf 'MAX_SPRINT=%s\n' "$max_sprint"
  printf 'PR_GROUPING=%s\n' "$pr_grouping"
  printf 'TASK_SPEC_PATH=%s\n' "$task_spec_out"
}

build_plan_task_spec_cmd() {
  local plan_file=''
  local task_spec_out=''
  local owner_prefix='subagent'
  local branch_prefix='issue'
  local worktree_prefix='issue__'
  local pr_grouping=''
  local pr_group_entries=()

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --task-spec-out)
        task_spec_out="${2:-}"
        shift 2
        ;;
      --owner-prefix)
        owner_prefix="${2:-}"
        shift 2
        ;;
      --branch-prefix)
        branch_prefix="${2:-}"
        shift 2
        ;;
      --worktree-prefix)
        worktree_prefix="${2:-}"
        shift 2
        ;;
      --pr-grouping)
        pr_grouping="${2:-}"
        shift 2
        ;;
      --pr-group)
        pr_group_entries+=("${2:-}")
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for build-plan-task-spec: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for build-plan-task-spec"
  validate_pr_grouping_args "$pr_grouping" "${#pr_group_entries[@]}"
  validate_plan "$plan_file"

  local plan_summary plan_title max_sprint total_tasks
  plan_summary="$(plan_summary_tsv "$plan_file")"
  IFS=$'\t' read -r plan_title max_sprint total_tasks <<<"$plan_summary"
  [[ "$total_tasks" -gt 0 ]] || die "plan has no tasks"

  if [[ -z "$task_spec_out" ]]; then
    task_spec_out="$(default_plan_task_spec_path "$plan_file")"
  fi

  local pr_group_config=''
  pr_group_config="$(join_lines "${pr_group_entries[@]}")"
  render_task_spec_from_plan_scope "$plan_file" plan '' "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_config" >/dev/null

  printf 'PLAN_FILE=%s\n' "$plan_file"
  printf 'SCOPE=plan\n'
  printf 'PLAN_TITLE=%s\n' "$plan_title"
  printf 'MAX_SPRINT=%s\n' "$max_sprint"
  printf 'TOTAL_TASK_COUNT=%s\n' "$total_tasks"
  printf 'PR_GROUPING=%s\n' "$pr_grouping"
  printf 'TASK_SPEC_PATH=%s\n' "$task_spec_out"
}

start_plan_cmd() {
  local plan_file=''
  local issue_title=''
  local task_spec_out=''
  local issue_body_out=''
  local owner_prefix='subagent'
  local branch_prefix='issue'
  local worktree_prefix='issue__'
  local pr_grouping=''
  local pr_group_entries=()
  local repo_arg=''
  local dry_run='0'
  local labels=()

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --title)
        issue_title="${2:-}"
        shift 2
        ;;
      --task-spec-out)
        task_spec_out="${2:-}"
        shift 2
        ;;
      --issue-body-out)
        issue_body_out="${2:-}"
        shift 2
        ;;
      --owner-prefix)
        owner_prefix="${2:-}"
        shift 2
        ;;
      --branch-prefix)
        branch_prefix="${2:-}"
        shift 2
        ;;
      --worktree-prefix)
        worktree_prefix="${2:-}"
        shift 2
        ;;
      --pr-grouping)
        pr_grouping="${2:-}"
        shift 2
        ;;
      --pr-group)
        pr_group_entries+=("${2:-}")
        shift 2
        ;;
      --label)
        labels+=("${2:-}")
        shift 2
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for start-plan: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for start-plan"
  validate_pr_grouping_args "$pr_grouping" "${#pr_group_entries[@]}"
  validate_plan "$plan_file"

  local plan_summary plan_title max_sprint total_tasks
  plan_summary="$(plan_summary_tsv "$plan_file")"
  IFS=$'\t' read -r plan_title max_sprint total_tasks <<<"$plan_summary"
  [[ "$total_tasks" -gt 0 ]] || die "plan has no tasks"

  if [[ -z "$task_spec_out" ]]; then
    task_spec_out="$(default_plan_task_spec_path "$plan_file")"
  fi
  local pr_group_config=''
  pr_group_config="$(join_lines "${pr_group_entries[@]}")"
  render_task_spec_from_plan_scope "$plan_file" plan '' "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_config" >/dev/null

  if [[ -z "$issue_body_out" ]]; then
    issue_body_out="$(default_plan_issue_body_path "$plan_file")"
  fi
  render_plan_issue_body_from_task_spec "$issue_lifecycle_template" "$plan_file" "$plan_title" "$task_spec_out" "$issue_body_out" >/dev/null

  if [[ -z "$issue_title" ]]; then
    issue_title="${plan_title}"
  fi

  if [[ ${#labels[@]} -eq 0 ]]; then
    labels=("issue" "plan")
  fi

  local start_args=(start --title "$issue_title" --body-file "$issue_body_out")
  local label=''
  for label in "${labels[@]}"; do
    start_args+=(--label "$label")
  done

  local start_output issue_number
  if [[ "$dry_run" == '1' ]]; then
    issue_number="$(default_dry_run_issue_number)"
    start_output="$(join_lines \
      "ISSUE_URL=DRY-RUN-ISSUE-URL" \
      "ISSUE_NUMBER=${issue_number}" \
      "TASK_SPEC_APPLIED=0")"
  else
    start_output="$(run_issue_delivery "$dry_run" "$repo_arg" "${start_args[@]}")"
    issue_number="$(printf '%s\n' "$start_output" | awk -F= '/^ISSUE_NUMBER=/{print $2; exit}')"
  fi
  printf '%s\n' "$start_output"

  if [[ -z "$issue_number" ]]; then
    issue_number="$(default_dry_run_issue_number)"
  fi
  printf 'PLAN_FILE=%s\n' "$plan_file"
  printf 'PLAN_ISSUE_NUMBER=%s\n' "$issue_number"
  printf 'PLAN_TITLE=%s\n' "$plan_title"
  printf 'MAX_SPRINT=%s\n' "$max_sprint"
  printf 'TOTAL_TASK_COUNT=%s\n' "$total_tasks"
  printf 'PR_GROUPING=%s\n' "$pr_grouping"
  printf 'TASK_SPEC_PATH=%s\n' "$task_spec_out"
  printf 'ISSUE_BODY_PATH=%s\n' "$issue_body_out"
  printf 'DESIGN=ONE_PLAN_ONE_ISSUE\n'
}

status_plan_cmd() {
  local repo_arg=''
  local dry_run='0'
  local passthrough=()

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --issue|--body-file)
        passthrough+=("${1:-}" "${2:-}")
        shift 2
        ;;
      --comment|--no-comment)
        passthrough+=("${1:-}")
        shift
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for status-plan: $1"
        ;;
    esac
  done

  run_issue_delivery "$dry_run" "$repo_arg" status "${passthrough[@]}"
}

ready_plan_cmd() {
  local repo_arg=''
  local dry_run='0'
  local passthrough=()
  local issue_number=''
  local body_file=''
  local summary_text=''
  local summary_file=''

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --issue|--body-file|--summary|--summary-file|--label|--remove-label)
        if [[ "${1:-}" == "--issue" ]]; then
          issue_number="${2:-}"
        fi
        if [[ "${1:-}" == "--body-file" ]]; then
          body_file="${2:-}"
        fi
        if [[ "${1:-}" == "--summary" ]]; then
          summary_text="${2:-}"
        fi
        if [[ "${1:-}" == "--summary-file" ]]; then
          summary_file="${2:-}"
        fi
        passthrough+=("${1:-}" "${2:-}")
        shift 2
        ;;
      --comment|--no-comment|--no-label-update)
        passthrough+=("${1:-}")
        shift
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for ready-plan: $1"
        ;;
    esac
  done

  if [[ "$dry_run" == '1' ]]; then
    if [[ -n "$issue_number" && -n "$body_file" ]]; then
      die "use either --issue or --body-file for ready-plan, not both"
    fi
    if [[ -z "$issue_number" && -z "$body_file" ]]; then
      die "ready-plan requires --issue or --body-file"
    fi
    [[ -n "$body_file" ]] || die "--body-file is required for ready-plan --dry-run"
    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    summary_text="$(read_optional_text "$summary_text" "$summary_file")"
    printf 'READY_PLAN_STATUS=DRY_RUN\n'
    printf 'READY_PLAN_SCOPE=LOCAL_BODY_FILE\n'
    printf 'READY_PLAN_BODY_FILE=%s\n' "$body_file"
    if [[ -n "$summary_text" ]]; then
      printf 'READY_PLAN_SUMMARY=%s\n' "$summary_text"
    fi
    return 0
  fi

  run_issue_delivery "$dry_run" "$repo_arg" ready-for-review "${passthrough[@]}"
}

close_plan_cmd() {
  local repo_arg=''
  local dry_run='0'
  local passthrough=()
  local issue_number=''
  local body_file=''
  local approved_comment_url=''

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --issue|--body-file|--approved-comment-url|--reason|--comment|--comment-file)
        if [[ "${1:-}" == "--issue" ]]; then
          issue_number="${2:-}"
        fi
        if [[ "${1:-}" == "--body-file" ]]; then
          body_file="${2:-}"
        fi
        if [[ "${1:-}" == "--approved-comment-url" ]]; then
          approved_comment_url="${2:-}"
        fi
        passthrough+=("${1:-}" "${2:-}")
        shift 2
        ;;
      --allow-not-done)
        passthrough+=("${1:-}")
        shift
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for close-plan: $1"
        ;;
    esac
  done

  [[ -n "$approved_comment_url" ]] || die "--approved-comment-url is required for close-plan"
  validate_approval_comment_url_format "$approved_comment_url" >/dev/null

  if [[ -n "$issue_number" && -n "$body_file" ]]; then
    die "use either --issue or --body-file for close-plan, not both"
  fi

  if [[ "$dry_run" == '1' ]]; then
    [[ -n "$body_file" ]] || die "--body-file is required for close-plan --dry-run"
    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    cleanup_plan_issue_worktrees '' "$repo_arg" "$dry_run" "$body_file"
    printf 'PLAN_CLOSE_STATUS=DRY_RUN\n'
    printf 'PLAN_CLOSE_SCOPE=LOCAL_BODY_FILE\n'
    printf 'PLAN_CLOSE_BODY_FILE=%s\n' "$body_file"
  else
    [[ -n "$issue_number" ]] || die "--issue is required for close-plan"
    [[ -z "$body_file" ]] || die "--body-file is only supported with --dry-run"
    run_issue_delivery "$dry_run" "$repo_arg" close-after-review "${passthrough[@]}"
    cleanup_plan_issue_worktrees "$issue_number" "$repo_arg" "$dry_run"
    printf 'PLAN_CLOSE_STATUS=SUCCESS\n'
    printf 'PLAN_ISSUE_NUMBER=%s\n' "$issue_number"
    printf 'DONE_CRITERIA=ISSUE_CLOSED_AND_WORKTREES_CLEANED\n'
  fi
}

cleanup_worktrees_cmd() {
  local issue_number=''
  local repo_arg=''
  local dry_run='0'

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --issue)
        issue_number="${2:-}"
        shift 2
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for cleanup-worktrees: $1"
        ;;
    esac
  done

  [[ -n "$issue_number" ]] || die "--issue is required for cleanup-worktrees"
  cleanup_plan_issue_worktrees "$issue_number" "$repo_arg" "$dry_run"
}

start_sprint_cmd() {
  local plan_file=''
  local issue_number=''
  local sprint=''
  local task_spec_out=''
  local owner_prefix='subagent'
  local branch_prefix='issue'
  local worktree_prefix='issue__'
  local pr_grouping=''
  local pr_group_entries=()
  local summary_text=''
  local summary_file=''
  local post_comment=''
  local repo_arg=''
  local dry_run='0'

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --issue)
        issue_number="${2:-}"
        shift 2
        ;;
      --sprint)
        sprint="${2:-}"
        shift 2
        ;;
      --task-spec-out)
        task_spec_out="${2:-}"
        shift 2
        ;;
      --owner-prefix)
        owner_prefix="${2:-}"
        shift 2
        ;;
      --branch-prefix)
        branch_prefix="${2:-}"
        shift 2
        ;;
      --worktree-prefix)
        worktree_prefix="${2:-}"
        shift 2
        ;;
      --pr-grouping)
        pr_grouping="${2:-}"
        shift 2
        ;;
      --pr-group)
        pr_group_entries+=("${2:-}")
        shift 2
        ;;
      --summary)
        summary_text="${2:-}"
        shift 2
        ;;
      --summary-file)
        summary_file="${2:-}"
        shift 2
        ;;
      --comment)
        post_comment='1'
        shift
        ;;
      --no-comment)
        post_comment='0'
        shift
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for start-sprint: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for start-sprint"
  [[ -n "$issue_number" ]] || die "--issue is required for start-sprint"
  [[ -n "$sprint" ]] || die "--sprint is required for start-sprint"
  is_positive_int "$sprint" || die "--sprint must be a positive integer"
  validate_pr_grouping_args "$pr_grouping" "${#pr_group_entries[@]}"
  summary_text="$(read_optional_text "$summary_text" "$summary_file")"

  validate_plan "$plan_file"

  local sprint_meta sprint_name sprint_task_count max_sprint
  sprint_meta="$(plan_sprint_meta_tsv "$plan_file" "$sprint")"
  IFS=$'\t' read -r sprint_name sprint_task_count max_sprint <<<"$sprint_meta"
  [[ "$sprint_task_count" -gt 0 ]] || die "sprint ${sprint} has no tasks"

  if [[ -z "$task_spec_out" ]]; then
    task_spec_out="$(default_sprint_task_spec_path "$plan_file" "$sprint")"
  fi
  local pr_group_config=''
  pr_group_config="$(join_lines "${pr_group_entries[@]}")"
  render_task_spec_from_plan_scope "$plan_file" sprint "$sprint" "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_config" >/dev/null

  if [[ -z "$post_comment" ]]; then
    if [[ "$dry_run" == '1' ]]; then
      post_comment='0'
    else
      post_comment='1'
    fi
  fi

  if (( sprint > 1 )); then
    local previous_sprint
    previous_sprint=$((sprint - 1))
    printf 'TRANSITION=SPRINT_%s_TO_%s\n' "$previous_sprint" "$sprint"
  fi

  printf 'PLAN_FILE=%s\n' "$plan_file"
  printf 'PLAN_ISSUE_NUMBER=%s\n' "$issue_number"
  printf 'SPRINT=%s\n' "$sprint"
  printf 'SPRINT_NAME=%s\n' "$sprint_name"
  printf 'SPRINT_TASK_COUNT=%s\n' "$sprint_task_count"
  printf 'PR_GROUPING=%s\n' "$pr_grouping"
  printf 'TASK_SPEC_PATH=%s\n' "$task_spec_out"

  emit_dispatch_hints "$task_spec_out" "$issue_number" "$issue_subagent_script"
  sync_issue_sprint_task_rows "$issue_number" "$task_spec_out" "$repo_arg" "$dry_run"

  local issue_body_file=''
  if [[ "$dry_run" != '1' ]]; then
    issue_body_file="$(mktemp)"
    issue_read_body_cmd "$issue_number" "$issue_body_file" "$repo_arg"
  fi

  local comment_body=''
  comment_body="$(render_sprint_comment_body start "$plan_file" "$issue_number" "$sprint" "$sprint_name" "$task_spec_out" "$summary_text" '' "$issue_body_file")"
  if [[ -n "$issue_body_file" ]]; then
    rm -f "$issue_body_file"
  fi
  printf '%s\n' "$comment_body"

  if [[ "$post_comment" == '1' ]]; then
    run_issue_lifecycle "$dry_run" "$repo_arg" comment --issue "$issue_number" --body "$comment_body" >/dev/null
    printf 'SPRINT_COMMENT_POSTED=1\n'
  else
    printf 'SPRINT_COMMENT_POSTED=0\n'
  fi
}

ready_sprint_cmd() {
  local plan_file=''
  local issue_number=''
  local sprint=''
  local task_spec_out=''
  local owner_prefix='subagent'
  local branch_prefix='issue'
  local worktree_prefix='issue__'
  local pr_grouping=''
  local pr_group_entries=()
  local summary_text=''
  local summary_file=''
  local post_comment=''
  local repo_arg=''
  local dry_run='0'

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --issue)
        issue_number="${2:-}"
        shift 2
        ;;
      --sprint)
        sprint="${2:-}"
        shift 2
        ;;
      --task-spec-out)
        task_spec_out="${2:-}"
        shift 2
        ;;
      --owner-prefix)
        owner_prefix="${2:-}"
        shift 2
        ;;
      --branch-prefix)
        branch_prefix="${2:-}"
        shift 2
        ;;
      --worktree-prefix)
        worktree_prefix="${2:-}"
        shift 2
        ;;
      --pr-grouping)
        pr_grouping="${2:-}"
        shift 2
        ;;
      --pr-group)
        pr_group_entries+=("${2:-}")
        shift 2
        ;;
      --summary)
        summary_text="${2:-}"
        shift 2
        ;;
      --summary-file)
        summary_file="${2:-}"
        shift 2
        ;;
      --comment)
        post_comment='1'
        shift
        ;;
      --no-comment)
        post_comment='0'
        shift
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for ready-sprint: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for ready-sprint"
  [[ -n "$issue_number" ]] || die "--issue is required for ready-sprint"
  [[ -n "$sprint" ]] || die "--sprint is required for ready-sprint"
  is_positive_int "$sprint" || die "--sprint must be a positive integer"
  validate_pr_grouping_args "$pr_grouping" "${#pr_group_entries[@]}"
  summary_text="$(read_optional_text "$summary_text" "$summary_file")"

  validate_plan "$plan_file"

  local sprint_meta sprint_name sprint_task_count max_sprint
  sprint_meta="$(plan_sprint_meta_tsv "$plan_file" "$sprint")"
  IFS=$'\t' read -r sprint_name sprint_task_count max_sprint <<<"$sprint_meta"
  [[ "$sprint_task_count" -gt 0 ]] || die "sprint ${sprint} has no tasks"

  if [[ -z "$task_spec_out" ]]; then
    task_spec_out="$(default_sprint_task_spec_path "$plan_file" "$sprint")"
  fi
  local pr_group_config=''
  pr_group_config="$(join_lines "${pr_group_entries[@]}")"
  render_task_spec_from_plan_scope "$plan_file" sprint "$sprint" "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_config" >/dev/null
  sync_issue_sprint_task_rows "$issue_number" "$task_spec_out" "$repo_arg" "$dry_run"

  if [[ -z "$post_comment" ]]; then
    if [[ "$dry_run" == '1' ]]; then
      post_comment='0'
    else
      post_comment='1'
    fi
  fi

  local issue_body_file=''
  if [[ "$dry_run" != '1' ]]; then
    issue_body_file="$(mktemp)"
    issue_read_body_cmd "$issue_number" "$issue_body_file" "$repo_arg"
  fi

  local comment_body=''
  comment_body="$(render_sprint_comment_body ready "$plan_file" "$issue_number" "$sprint" "$sprint_name" "$task_spec_out" "$summary_text" '' "$issue_body_file")"
  if [[ -n "$issue_body_file" ]]; then
    rm -f "$issue_body_file"
  fi
  printf '%s\n' "$comment_body"

  if [[ "$post_comment" == '1' ]]; then
    run_issue_lifecycle "$dry_run" "$repo_arg" comment --issue "$issue_number" --body "$comment_body" >/dev/null
    printf 'SPRINT_READY_COMMENT_POSTED=1\n'
  else
    printf 'SPRINT_READY_COMMENT_POSTED=0\n'
  fi
}

accept_sprint_cmd() {
  local plan_file=''
  local issue_number=''
  local sprint=''
  local task_spec_out=''
  local owner_prefix='subagent'
  local branch_prefix='issue'
  local worktree_prefix='issue__'
  local pr_grouping=''
  local pr_group_entries=()
  local summary_text=''
  local summary_file=''
  local approved_comment_url=''
  local post_comment=''
  local repo_arg=''
  local dry_run='0'

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --issue)
        issue_number="${2:-}"
        shift 2
        ;;
      --sprint)
        sprint="${2:-}"
        shift 2
        ;;
      --task-spec-out)
        task_spec_out="${2:-}"
        shift 2
        ;;
      --owner-prefix)
        owner_prefix="${2:-}"
        shift 2
        ;;
      --branch-prefix)
        branch_prefix="${2:-}"
        shift 2
        ;;
      --worktree-prefix)
        worktree_prefix="${2:-}"
        shift 2
        ;;
      --pr-grouping)
        pr_grouping="${2:-}"
        shift 2
        ;;
      --pr-group)
        pr_group_entries+=("${2:-}")
        shift 2
        ;;
      --summary)
        summary_text="${2:-}"
        shift 2
        ;;
      --summary-file)
        summary_file="${2:-}"
        shift 2
        ;;
      --approved-comment-url)
        approved_comment_url="${2:-}"
        shift 2
        ;;
      --comment)
        post_comment='1'
        shift
        ;;
      --no-comment)
        post_comment='0'
        shift
        ;;
      --repo)
        repo_arg="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for accept-sprint: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for accept-sprint"
  [[ -n "$issue_number" ]] || die "--issue is required for accept-sprint"
  [[ -n "$sprint" ]] || die "--sprint is required for accept-sprint"
  [[ -n "$approved_comment_url" ]] || die "--approved-comment-url is required for accept-sprint"
  is_positive_int "$sprint" || die "--sprint must be a positive integer"
  validate_pr_grouping_args "$pr_grouping" "${#pr_group_entries[@]}"
  summary_text="$(read_optional_text "$summary_text" "$summary_file")"
  validate_approval_comment_url_format "$approved_comment_url" >/dev/null

  validate_plan "$plan_file"

  local sprint_meta sprint_name sprint_task_count max_sprint
  sprint_meta="$(plan_sprint_meta_tsv "$plan_file" "$sprint")"
  IFS=$'\t' read -r sprint_name sprint_task_count max_sprint <<<"$sprint_meta"
  [[ "$sprint_task_count" -gt 0 ]] || die "sprint ${sprint} has no tasks"

  if [[ -z "$task_spec_out" ]]; then
    task_spec_out="$(default_sprint_task_spec_path "$plan_file" "$sprint")"
  fi
  local pr_group_config=''
  pr_group_config="$(join_lines "${pr_group_entries[@]}")"
  render_task_spec_from_plan_scope "$plan_file" sprint "$sprint" "$task_spec_out" "$owner_prefix" "$branch_prefix" "$worktree_prefix" "$pr_grouping" "$pr_group_config" >/dev/null
  sync_issue_sprint_task_rows "$issue_number" "$task_spec_out" "$repo_arg" "$dry_run"

  if [[ -z "$post_comment" ]]; then
    if [[ "$dry_run" == '1' ]]; then
      post_comment='0'
    else
      post_comment='1'
    fi
  fi

  local issue_body_file=''
  if [[ "$dry_run" != '1' ]]; then
    issue_body_file="$(mktemp)"
    issue_read_body_cmd "$issue_number" "$issue_body_file" "$repo_arg"
  fi

  local comment_body=''
  comment_body="$(render_sprint_comment_body accepted "$plan_file" "$issue_number" "$sprint" "$sprint_name" "$task_spec_out" "$summary_text" "$approved_comment_url" "$issue_body_file")"
  if [[ -n "$issue_body_file" ]]; then
    rm -f "$issue_body_file"
  fi
  printf '%s\n' "$comment_body"

  if [[ "$post_comment" == '1' ]]; then
    run_issue_lifecycle "$dry_run" "$repo_arg" comment --issue "$issue_number" --body "$comment_body" >/dev/null
    printf 'SPRINT_ACCEPT_COMMENT_POSTED=1\n'
  else
    printf 'SPRINT_ACCEPT_COMMENT_POSTED=0\n'
  fi

  printf 'PLAN_ISSUE_REMAINS_OPEN=1\n'
}

multi_sprint_guide_cmd() {
  local plan_file=''
  local from_sprint='1'
  local to_sprint=''
  local guide_dry_run='0'

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --plan)
        plan_file="${2:-}"
        shift 2
        ;;
      --from-sprint)
        from_sprint="${2:-}"
        shift 2
        ;;
      --to-sprint)
        to_sprint="${2:-}"
        shift 2
        ;;
      --dry-run)
        guide_dry_run='1'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for multi-sprint-guide: $1"
        ;;
    esac
  done

  [[ -n "$plan_file" ]] || die "--plan is required for multi-sprint-guide"
  is_positive_int "$from_sprint" || die "--from-sprint must be a positive integer"

  validate_plan "$plan_file"

  local plan_summary plan_title max_sprint total_tasks
  plan_summary="$(plan_summary_tsv "$plan_file")"
  IFS=$'\t' read -r plan_title max_sprint total_tasks <<<"$plan_summary"
  if [[ -z "$to_sprint" ]]; then
    to_sprint="$max_sprint"
  fi
  is_positive_int "$to_sprint" || die "--to-sprint must be a positive integer"
  if [[ "$from_sprint" -gt "$to_sprint" ]]; then
    die "--from-sprint must be <= --to-sprint"
  fi

  local dry_run_issue_number=''
  local dry_run_issue_body=''
  if [[ "$guide_dry_run" == '1' ]]; then
    dry_run_issue_number="$(default_dry_run_issue_number)"
    dry_run_issue_body="$(default_plan_issue_body_path "$plan_file")"
  fi

  printf 'MULTI_SPRINT_GUIDE_BEGIN\n'
  printf 'DESIGN=ONE_PLAN_ONE_ISSUE\n'
  if [[ "$guide_dry_run" == '1' ]]; then
    printf 'MODE=DRY_RUN_LOCAL\n'
  else
    printf 'MODE=LIVE\n'
  fi
  printf 'PLAN_FILE=%s\n' "$plan_file"
  printf 'PLAN_TITLE=%s\n' "$plan_title"
  printf 'FROM_SPRINT=%s\n' "$from_sprint"
  printf 'TO_SPRINT=%s\n' "$to_sprint"
  if [[ "$guide_dry_run" == '1' ]]; then
    printf 'DRY_RUN_PLAN_ISSUE=%s\n' "$dry_run_issue_number"
    printf 'DRY_RUN_ISSUE_BODY=%s\n' "$dry_run_issue_body"
    printf 'STEP_1=%s\n' "$(print_cmd "$0" start-plan --plan "$plan_file" --pr-grouping "<per-sprint|group>" --dry-run)"
    printf 'STEP_2=%s\n' "$(print_cmd "$0" start-sprint --plan "$plan_file" --issue "$dry_run_issue_number" --sprint "$from_sprint" --pr-grouping "<per-sprint|group>" --no-comment --dry-run)"
  else
    printf 'STEP_1=%s\n' "$(print_cmd "$0" start-plan --plan "$plan_file" --pr-grouping "<per-sprint|group>" --repo "<owner/repo>")"
    printf 'STEP_2=%s\n' "$(print_cmd "$0" start-sprint --plan "$plan_file" --issue "<plan-issue>" --sprint "$from_sprint" --pr-grouping "<per-sprint|group>" --repo "<owner/repo>")"
  fi

  local step_index=3
  local sprint=''
  for (( sprint=from_sprint; sprint<to_sprint; sprint++ )); do
    local next_sprint
    next_sprint=$((sprint + 1))
    if [[ "$guide_dry_run" == '1' ]]; then
      printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" accept-sprint --plan "$plan_file" --issue "$dry_run_issue_number" --sprint "$sprint" --approved-comment-url "<approval-comment-url-sprint-${sprint}>" --pr-grouping "<per-sprint|group>" --no-comment --dry-run)"
    else
      printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" accept-sprint --plan "$plan_file" --issue "<plan-issue>" --sprint "$sprint" --approved-comment-url "<approval-comment-url-sprint-${sprint}>" --pr-grouping "<per-sprint|group>" --repo "<owner/repo>")"
    fi
    step_index=$((step_index + 1))
    if [[ "$guide_dry_run" == '1' ]]; then
      printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" start-sprint --plan "$plan_file" --issue "$dry_run_issue_number" --sprint "$next_sprint" --pr-grouping "<per-sprint|group>" --no-comment --dry-run)"
    else
      printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" start-sprint --plan "$plan_file" --issue "<plan-issue>" --sprint "$next_sprint" --pr-grouping "<per-sprint|group>" --repo "<owner/repo>")"
    fi
    step_index=$((step_index + 1))
  done

  if [[ "$guide_dry_run" == '1' ]]; then
    printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" ready-plan --body-file "$dry_run_issue_body" --summary "Final plan review" --no-comment --no-label-update --dry-run)"
  else
    printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" ready-plan --issue "<plan-issue>" --summary "Final plan review" --repo "<owner/repo>")"
  fi
  step_index=$((step_index + 1))
  if [[ "$guide_dry_run" == '1' ]]; then
    printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" close-plan --body-file "$dry_run_issue_body" --approved-comment-url "<final-plan-approval-comment-url>" --dry-run)"
    printf 'NOTE_DRY_RUN=%s\n' "Dry-run guide is local-only and does not call GitHub."
  else
    printf 'STEP_%s=%s\n' "$step_index" "$(print_cmd "$0" close-plan --issue "<plan-issue>" --approved-comment-url "<final-plan-approval-comment-url>" --repo "<owner/repo>")"
  fi
  printf 'NOTE_GROUP_MODE=%s\n' "When using --pr-grouping group, pass --pr-group for every task in the selected scope."
  printf 'MULTI_SPRINT_GUIDE_END\n'
}

subcommand="${1:-}"
if [[ -z "$subcommand" ]]; then
  usage >&2
  exit 1
fi
shift || true

ensure_entrypoints

case "$subcommand" in
  build-task-spec)
    build_task_spec_cmd "$@"
    ;;
  build-plan-task-spec)
    build_plan_task_spec_cmd "$@"
    ;;
  start-plan)
    start_plan_cmd "$@"
    ;;
  status-plan|status-sprint)
    status_plan_cmd "$@"
    ;;
  ready-plan)
    ready_plan_cmd "$@"
    ;;
  close-plan)
    close_plan_cmd "$@"
    ;;
  cleanup-worktrees)
    cleanup_worktrees_cmd "$@"
    ;;
  start-sprint)
    start_sprint_cmd "$@"
    ;;
  ready-sprint)
    ready_sprint_cmd "$@"
    ;;
  accept-sprint)
    accept_sprint_cmd "$@"
    ;;
  multi-sprint-guide)
    multi_sprint_guide_cmd "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "error: unknown subcommand: ${subcommand}" >&2
    usage >&2
    exit 2
    ;;
esac

exit 0
