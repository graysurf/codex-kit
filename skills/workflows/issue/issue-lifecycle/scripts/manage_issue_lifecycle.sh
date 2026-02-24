#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
skill_issue_template="${skill_dir}/references/ISSUE_TEMPLATE.md"

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="${1:-}"
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
}

print_cmd() {
  local out=''
  local arg=''
  for arg in "$@"; do
    out+=" $(printf '%q' "$arg")"
  done
  printf '%s\n' "${out# }"
}

run_cmd() {
  if [[ "${dry_run}" == "1" ]]; then
    echo "dry-run: $(print_cmd "$@")" >&2
    return 0
  fi
  "$@"
}

resolve_skill_issue_template() {
  [[ -f "$skill_issue_template" ]] || die "required skill template not found: $skill_issue_template"
  printf '%s\n' "$skill_issue_template"
}

usage() {
  cat <<'USAGE'
Usage:
  manage_issue_lifecycle.sh <open|update|decompose|validate|sync|comment|close|reopen> [options]

Subcommands:
  open       Create a new issue owned by the main agent
  update     Update title/body/labels/assignees/projects for an issue
  decompose  Render task split markdown from a TSV and optionally comment on issue
  validate   Validate issue body Task Decomposition consistency
  sync       Normalize Task Decomposition (and strip legacy Subagent PRs section)
  comment    Add an issue progress comment
  close      Close an issue with optional completion comment
  reopen     Reopen an issue with optional comment

Common options:
  --repo <owner/repo>    Target repository (passed to gh with -R)
  --dry-run              Print actions without calling gh

open options:
  --title <text>                 Issue title (required)
  --body <text>                  Inline issue body
  --body-file <path>             Issue body file path
  --use-template                 Use the built-in skill template when body is not set
  --skip-consistency-check       Skip template consistency validation for this open operation
  --label <name>                 Repeatable label flag
  --assignee <login>             Repeatable assignee flag
  --project <title>              Repeatable project title flag
  --milestone <name>             Milestone title

update options:
  --issue <number>               Issue number (required)
  --title <text>                 New title
  --body <text>                  New body
  --body-file <path>             New body file
  --skip-consistency-check       Skip template consistency validation for this update operation
  --add-label <name>             Repeatable add-label flag
  --remove-label <name>          Repeatable remove-label flag
  --add-assignee <login>         Repeatable add-assignee flag
  --remove-assignee <login>      Repeatable remove-assignee flag
  --add-project <title>          Repeatable add-project flag
  --remove-project <title>       Repeatable remove-project flag

Decompose options:
  --issue <number>               Issue number (required)
  --spec <path>                  TSV spec with task split (required)
  --header <text>                Heading text (default: "Task Decomposition")
  --comment                      Post decomposition to issue (default: print only)

Validate options:
  --body-file <path>             Local issue body markdown file
  --issue <number>               Issue number to validate via gh issue view

Sync options:
  --body-file <path>             Local issue body markdown file to sync
  --issue <number>               Issue number to sync via gh issue edit
  --write                        Write synced body back to --body-file (default: print to stdout)

Comment options:
  --issue <number>               Issue number (required)
  --body <text>                  Comment body
  --body-file <path>             Comment body file

Close/Reopen options:
  --issue <number>               Issue number (required)
  --reason <completed|not planned>
                                Close reason (close only, default: completed)
  --comment <text>               Comment text for close/reopen
  --comment-file <path>          Comment body file for close/reopen
USAGE
}

render_decompose_markdown() {
  local spec_path="${1:-}"
  local header="${2:-Task Decomposition}"

  python3 - "$spec_path" "$header" <<'PY'
import csv
import pathlib
import sys

spec_path = pathlib.Path(sys.argv[1])
header = sys.argv[2]

if not spec_path.is_file():
    raise SystemExit(f"error: spec file not found: {spec_path}")

rows = []
with spec_path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle, delimiter="\t")
    for line_no, row in enumerate(reader, start=1):
        if not row:
            continue
        if row[0].strip().startswith("#"):
            continue
        if len(row) < 4:
            raise SystemExit(
                f"error: invalid spec line {line_no}: expected at least 4 tab-separated fields "
                "(task_id, summary, branch, worktree[, owner][, notes])"
            )
        task_id = row[0].strip()
        summary = row[1].strip()
        branch = row[2].strip()
        worktree = row[3].strip()
        owner = row[4].strip() if len(row) >= 5 else "TBD"
        notes = row[5].strip() if len(row) >= 6 else ""

        if not task_id or not summary or not branch or not worktree:
            raise SystemExit(
                f"error: invalid spec line {line_no}: task_id, summary, branch, and worktree must be non-empty"
            )

        rows.append((task_id, summary, branch, worktree, owner, notes))

if not rows:
    raise SystemExit("error: no task rows found in spec")

print(f"## {header}")
print("")
print("| Task | Summary | Owner | Branch | Worktree | Execution Mode | PR | Status | Notes |")
print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
for task_id, summary, branch, worktree, owner, notes in rows:
    notes_value = notes if notes else "-"
    print(
        f"| {task_id} | {summary} | {owner} | `{branch}` | `{worktree}` | per-task | TBD | planned | {notes_value} |"
    )

print("")
print("## Subagent Dispatch")
print("")
for task_id, summary, branch, worktree, owner, notes in rows:
    notes_value = notes if notes else "none"
    print(f"- [ ] {task_id}: {summary}")
    print(f"  - owner: {owner}")
    print(f"  - branch: `{branch}`")
    print(f"  - worktree: `{worktree}`")
    print(f"  - notes: {notes_value}")
PY
}

issue_body_consistency_tool() {
  local mode="${1:-}"
  local body_path="${2:-}"

  python3 - "$mode" "$body_path" <<'PY'
import pathlib
import re
import sys

mode = sys.argv[1]
body_path = pathlib.Path(sys.argv[2])

if mode not in {"validate", "sync"}:
    raise SystemExit(f"error: unsupported mode: {mode}")
if not body_path.is_file():
    raise SystemExit(f"error: issue body file not found: {body_path}")

text = body_path.read_text(encoding="utf-8")
lines = text.splitlines()

required_columns = ["Task", "Summary", "Owner", "Branch", "Worktree", "PR", "Status", "Notes"]
canonical_columns = [
    "Task",
    "Summary",
    "Owner",
    "Branch",
    "Worktree",
    "Execution Mode",
    "PR",
    "Status",
    "Notes",
]
allowed_statuses = {"planned", "in-progress", "blocked", "done"}
allowed_execution_modes = {"per-task", "per-sprint", "single-pr"}
placeholder_pr = {"", "-", "tbd", "none", "n/a", "na"}
placeholder_tokens = {"", "-", "tbd", "none", "n/a", "na"}


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
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        return []
    return [cell.strip() for cell in stripped[1:-1].split("|")]


def parse_task_rows() -> tuple[list[dict[str, str]], list[str], tuple[int, int, int, int]]:
    start, end = section_bounds("## Task Decomposition")
    section = lines[start:end]

    table_rel_idx = [idx for idx, line in enumerate(section) if line.strip().startswith("|")]
    table_lines = [section[idx] for idx in table_rel_idx]
    if len(table_lines) < 3:
        raise SystemExit("error: Task Decomposition must contain a markdown table with at least one row")

    headers = parse_row(table_lines[0])
    if not headers:
        raise SystemExit("error: malformed Task Decomposition table header")

    missing = [col for col in required_columns if col not in headers]
    if missing:
        raise SystemExit("error: missing Task Decomposition columns: " + ", ".join(missing))

    rows: list[dict[str, str]] = []
    for line_no, raw in enumerate(table_lines[2:], start=3):
        cells = parse_row(raw)
        if not cells:
            continue
        if len(cells) != len(headers):
            raise SystemExit(
                "error: malformed Task Decomposition row "
                f"(expected {len(headers)} columns, got {len(cells)} at table row {line_no})"
            )
        row = {header: cells[idx] for idx, header in enumerate(headers)}
        if not any(cell.strip() for cell in cells):
            continue
        if "Execution Mode" not in row:
            row["Execution Mode"] = "TBD"
        rows.append(row)

    if not rows:
        raise SystemExit("error: Task Decomposition table must include at least one task row")

    first_table_abs = start + table_rel_idx[0]
    last_table_abs = start + table_rel_idx[-1]
    return rows, headers, (start, end, first_table_abs, last_table_abs)


def maybe_section_bounds(heading: str) -> tuple[int, int] | None:
    try:
        return section_bounds(heading)
    except SystemExit as exc:
        if "missing required heading" in str(exc):
            return None
        raise


def normalize_pr(value: str) -> str:
    current = value.strip()
    link_match = re.fullmatch(r"\[[^\]]+\]\(([^)]+)\)", current)
    if link_match:
        current = link_match.group(1).strip()
    if current.startswith("`") and current.endswith("`") and len(current) >= 2:
        current = current[1:-1].strip()

    lowered = current.lower()
    if lowered in placeholder_pr:
        return "TBD"

    for pattern in (
        r"^#(\d+)$",
        r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#(\d+)$",
        r"^PR\s*#(\d+)$",
        r"^https://github\.com/[^/\s]+/[^/\s]+/pull/(\d+)(?:[/?#].*)?$",
    ):
        match = re.match(pattern, current, flags=re.IGNORECASE)
        if match:
            return f"#{match.group(1)}"

    return current


def is_pr_placeholder(value: str) -> bool:
    return normalize_pr(value) == "TBD"


def normalize_placeholder(value: str) -> str:
    current = value.strip()
    if current.lower() in placeholder_tokens:
        return "TBD"
    return current


def normalize_owner_token(value: str) -> str:
    lowered = value.strip().lower()
    lowered = lowered.replace("_", " ").replace("-", " ")
    return "".join(lowered.split())


def is_main_agent_owner(value: str) -> bool:
    lowered = value.strip().lower()
    token = normalize_owner_token(value)

    if token in {"mainagent", "main", "codex", "orchestrator", "leadagent"}:
        return True
    if "main-agent" in lowered or "main agent" in lowered:
        return True
    return False


def normalize_execution_mode(value: str) -> str:
    raw = value.strip()
    if not raw:
        return "TBD"
    lowered = raw.lower().replace("_", "-").replace(" ", "-")
    if lowered in placeholder_tokens:
        return "TBD"
    if lowered in allowed_execution_modes:
        return lowered
    if lowered == "single":
        return "single-pr"
    if lowered == "persprint":
        return "per-sprint"
    if lowered == "pertask":
        return "per-task"
    return raw


task_rows, task_headers, task_table_meta = parse_task_rows()

if mode == "sync":
    _start, _end, first_table_abs, last_table_abs = task_table_meta
    normalized_table = [
        "| Task | Summary | Owner | Branch | Worktree | Execution Mode | PR | Status | Notes |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in task_rows:
        cells = []
        for col in canonical_columns:
            if col == "Execution Mode":
                value = normalize_execution_mode(row.get(col, ""))
            elif col == "PR":
                value = normalize_pr(row.get(col, ""))
            elif col in {"Owner", "Branch", "Worktree"}:
                value = normalize_placeholder(row.get(col, ""))
            else:
                value = (row.get(col, "") or "").strip()
            if col in {"Owner", "Branch", "Worktree", "Execution Mode", "PR"}:
                cells.append(value or "TBD")
            else:
                cells.append(value)
        normalized_table.append("| " + " | ".join(cells) + " |")

    new_lines = lines[:first_table_abs] + normalized_table + lines[last_table_abs + 1 :]
    legacy_bounds = maybe_section_bounds("## Subagent PRs")
    if legacy_bounds is not None:
        sub_start, sub_end = legacy_bounds
        heading_index = sub_start - 1
        if heading_index > 0 and new_lines[heading_index - 1].strip() == "":
            heading_index -= 1
        new_lines = new_lines[:heading_index] + new_lines[sub_end:]

    output = "\n".join(new_lines).rstrip("\n") + "\n"
    sys.stdout.write(output)
    raise SystemExit(0)

errors: list[str] = []

seen_branch_per_task: dict[str, str] = {}
seen_worktree_per_task: dict[str, str] = {}

for idx, row in enumerate(task_rows, start=1):
    task_id = row.get("Task", "").strip()
    owner = normalize_placeholder(row.get("Owner", ""))
    branch = normalize_placeholder(row.get("Branch", ""))
    worktree = normalize_placeholder(row.get("Worktree", ""))
    exec_mode_raw = row.get("Execution Mode", "")
    exec_mode = normalize_execution_mode(exec_mode_raw)
    pr_value = row.get("PR", "").strip() or "TBD"
    status = row.get("Status", "").strip().lower()

    if not task_id:
        errors.append(f"Task Decomposition row {idx} has empty Task id")
        continue

    if owner and owner != "TBD":
        owner_lower = owner.lower()
        owner_token = normalize_owner_token(owner)
        if owner_lower in placeholder_tokens or owner_token in placeholder_tokens:
            owner = "TBD"
        elif is_main_agent_owner(owner):
            errors.append(f"{task_id}: Owner must not be main-agent (main-agent is orchestration/review-only)")
        elif "subagent" not in owner_lower:
            errors.append(f"{task_id}: Owner must reference a subagent identity (must include 'subagent')")

    if status not in allowed_statuses:
        errors.append(f"{task_id}: Status must be one of {sorted(allowed_statuses)} (got: {row.get('Status', '').strip()})")
    if exec_mode != "TBD" and exec_mode not in allowed_execution_modes:
        errors.append(
            f"{task_id}: Execution Mode must be one of {sorted(allowed_execution_modes)} or TBD "
            f"(got: {exec_mode_raw.strip() or '<empty>'})"
        )
    if status in {"in-progress", "done"} and is_pr_placeholder(pr_value):
        errors.append(f"{task_id}: PR must not be TBD when Status is {status}")
    if status in {"in-progress", "done"}:
        if owner == "TBD":
            errors.append(f"{task_id}: Owner must not be TBD when Status is {status}")
        if branch == "TBD":
            errors.append(f"{task_id}: Branch must not be TBD when Status is {status}")
        if worktree == "TBD":
            errors.append(f"{task_id}: Worktree must not be TBD when Status is {status}")
        if exec_mode == "TBD":
            errors.append(f"{task_id}: Execution Mode must not be TBD when Status is {status}")

    if exec_mode == "per-task":
        if branch and branch != "TBD":
            if branch in seen_branch_per_task:
                errors.append(f"{task_id}: Branch duplicates {seen_branch_per_task[branch]} ({branch}) under per-task mode")
            else:
                seen_branch_per_task[branch] = task_id
        if worktree and worktree != "TBD":
            if worktree in seen_worktree_per_task:
                errors.append(f"{task_id}: Worktree duplicates {seen_worktree_per_task[worktree]} ({worktree}) under per-task mode")
            else:
                seen_worktree_per_task[worktree] = task_id

if errors:
    for message in errors:
        print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)

print(f"ok: issue body consistency passed ({len(task_rows)} tasks)")
PY
}

validate_issue_body_file() {
  local body_file="${1:-}"
  [[ -n "$body_file" ]] || die "validate_issue_body_file requires body file path"
  issue_body_consistency_tool validate "$body_file"
}

sync_issue_body_file() {
  local body_file="${1:-}"
  [[ -n "$body_file" ]] || die "sync_issue_body_file requires body file path"
  issue_body_consistency_tool sync "$body_file"
}

maybe_validate_issue_body_file() {
  local body_file="${1:-}"
  [[ -f "$body_file" ]] || die "body file not found: $body_file"
  if grep -Eq '^## Task Decomposition$' "$body_file"; then
    validate_issue_body_file "$body_file" >/dev/null
  fi
}

subcommand="${1:-}"
if [[ -z "$subcommand" ]]; then
  usage >&2
  exit 1
fi
shift || true

dry_run="0"
repo_arg=""

case "$subcommand" in
  open)
    title=""
    body=""
    body_file=""
    use_template="0"
    skip_consistency_check="0"
    milestone=""
    labels=()
    assignees=()
    projects=()

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --title)
          title="${2:-}"
          shift 2
          ;;
        --body)
          body="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --use-template)
          use_template="1"
          shift
          ;;
        --skip-consistency-check)
          skip_consistency_check="1"
          shift
          ;;
        --label)
          labels+=("${2:-}")
          shift 2
          ;;
        --assignee)
          assignees+=("${2:-}")
          shift 2
          ;;
        --project)
          projects+=("${2:-}")
          shift 2
          ;;
        --milestone)
          milestone="${2:-}"
          shift 2
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for open: $1"
          ;;
      esac
    done

    [[ -n "$title" ]] || die "--title is required for open"

    if [[ -n "$body" && -n "$body_file" ]]; then
      die "use either --body or --body-file, not both"
    fi

    if [[ "$use_template" == "1" && -z "$body" && -z "$body_file" ]]; then
      body_file="$(resolve_skill_issue_template)"
    fi

    if [[ -z "$body" && -z "$body_file" ]]; then
      body_file="$(resolve_skill_issue_template)"
    fi

    if [[ -n "$body_file" && ! -f "$body_file" ]]; then
      die "body file not found: $body_file"
    fi

    if [[ "$skip_consistency_check" != "1" ]]; then
      if [[ -n "$body" ]]; then
        tmp_validate="$(mktemp)"
        printf '%s\n' "$body" >"$tmp_validate"
        maybe_validate_issue_body_file "$tmp_validate"
        rm -f "$tmp_validate"
      else
        maybe_validate_issue_body_file "$body_file"
      fi
    fi

    require_cmd gh

    cmd=(gh issue create --title "$title")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi
    if [[ -n "$body" ]]; then
      cmd+=(--body "$body")
    else
      cmd+=(--body-file "$body_file")
    fi

    for item in "${labels[@]+"${labels[@]}"}"; do
      cmd+=(--label "$item")
    done
    for item in "${assignees[@]+"${assignees[@]}"}"; do
      cmd+=(--assignee "$item")
    done
    for item in "${projects[@]+"${projects[@]}"}"; do
      cmd+=(--project "$item")
    done
    if [[ -n "$milestone" ]]; then
      cmd+=(--milestone "$milestone")
    fi

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${cmd[@]}"
      echo "DRY-RUN-ISSUE-URL"
      exit 0
    fi

    run_cmd "${cmd[@]}"
    ;;

  update)
    issue_number=""
    title=""
    body=""
    body_file=""
    skip_consistency_check="0"
    add_labels=()
    remove_labels=()
    add_assignees=()
    remove_assignees=()
    add_projects=()
    remove_projects=()

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --title)
          title="${2:-}"
          shift 2
          ;;
        --body)
          body="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --skip-consistency-check)
          skip_consistency_check="1"
          shift
          ;;
        --add-label)
          add_labels+=("${2:-}")
          shift 2
          ;;
        --remove-label)
          remove_labels+=("${2:-}")
          shift 2
          ;;
        --add-assignee)
          add_assignees+=("${2:-}")
          shift 2
          ;;
        --remove-assignee)
          remove_assignees+=("${2:-}")
          shift 2
          ;;
        --add-project)
          add_projects+=("${2:-}")
          shift 2
          ;;
        --remove-project)
          remove_projects+=("${2:-}")
          shift 2
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for update: $1"
          ;;
      esac
    done

    [[ -n "$issue_number" ]] || die "--issue is required for update"

    if [[ -n "$body" && -n "$body_file" ]]; then
      die "use either --body or --body-file, not both"
    fi

    if [[ -n "$body_file" && ! -f "$body_file" ]]; then
      die "body file not found: $body_file"
    fi

    if [[ "$skip_consistency_check" != "1" ]]; then
      if [[ -n "$body" ]]; then
        tmp_validate="$(mktemp)"
        printf '%s\n' "$body" >"$tmp_validate"
        maybe_validate_issue_body_file "$tmp_validate"
        rm -f "$tmp_validate"
      elif [[ -n "$body_file" ]]; then
        maybe_validate_issue_body_file "$body_file"
      fi
    fi

    if [[ -z "$title" && -z "$body" && -z "$body_file" && ${#add_labels[@]} -eq 0 && ${#remove_labels[@]} -eq 0 && ${#add_assignees[@]} -eq 0 && ${#remove_assignees[@]} -eq 0 && ${#add_projects[@]} -eq 0 && ${#remove_projects[@]} -eq 0 ]]; then
      die "update requires at least one edit flag"
    fi

    require_cmd gh

    cmd=(gh issue edit "$issue_number")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi
    if [[ -n "$title" ]]; then
      cmd+=(--title "$title")
    fi
    if [[ -n "$body" ]]; then
      cmd+=(--body "$body")
    elif [[ -n "$body_file" ]]; then
      cmd+=(--body-file "$body_file")
    fi

    for item in "${add_labels[@]+"${add_labels[@]}"}"; do
      cmd+=(--add-label "$item")
    done
    for item in "${remove_labels[@]+"${remove_labels[@]}"}"; do
      cmd+=(--remove-label "$item")
    done
    for item in "${add_assignees[@]+"${add_assignees[@]}"}"; do
      cmd+=(--add-assignee "$item")
    done
    for item in "${remove_assignees[@]+"${remove_assignees[@]}"}"; do
      cmd+=(--remove-assignee "$item")
    done
    for item in "${add_projects[@]+"${add_projects[@]}"}"; do
      cmd+=(--add-project "$item")
    done
    for item in "${remove_projects[@]+"${remove_projects[@]}"}"; do
      cmd+=(--remove-project "$item")
    done

    run_cmd "${cmd[@]}"
    ;;

  decompose)
    issue_number=""
    spec_file=""
    header="Task Decomposition"
    post_comment="0"

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --spec)
          spec_file="${2:-}"
          shift 2
          ;;
        --header)
          header="${2:-}"
          shift 2
          ;;
        --comment)
          post_comment="1"
          shift
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for decompose: $1"
          ;;
      esac
    done

    [[ -n "$issue_number" ]] || die "--issue is required for decompose"
    [[ -n "$spec_file" ]] || die "--spec is required for decompose"
    [[ -f "$spec_file" ]] || die "spec file not found: $spec_file"

    require_cmd python3

    tmp_body="$(mktemp)"
    render_decompose_markdown "$spec_file" "$header" >"$tmp_body"

    if [[ "$post_comment" == "0" ]]; then
      cat "$tmp_body"
      rm -f "$tmp_body"
      exit 0
    fi

    require_cmd gh
    cmd=(gh issue comment "$issue_number")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi
    cmd+=(--body-file "$tmp_body")

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${cmd[@]}"
      cat "$tmp_body"
      rm -f "$tmp_body"
      exit 0
    fi

    run_cmd "${cmd[@]}"
    rm -f "$tmp_body"
    ;;

  validate)
    issue_number=""
    body_file=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for validate: $1"
          ;;
      esac
    done

    if [[ -n "$issue_number" && -n "$body_file" ]]; then
      die "use either --issue or --body-file, not both"
    fi
    if [[ -z "$issue_number" && -z "$body_file" ]]; then
      die "validate requires --issue or --body-file"
    fi

    require_cmd python3

    if [[ -n "$issue_number" ]]; then
      require_cmd gh
      tmp_body="$(mktemp)"
      view_cmd=(gh issue view "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        view_cmd+=(-R "$repo_arg")
      fi
      view_cmd+=(--json body -q .body)

      if [[ "$dry_run" == "1" ]]; then
        echo "dry-run: $(print_cmd "${view_cmd[@]}")" >&2
        echo "DRY-RUN-VALIDATION-SKIPPED"
        rm -f "$tmp_body"
        exit 0
      fi

      "${view_cmd[@]}" >"$tmp_body"
      validate_issue_body_file "$tmp_body"
      rm -f "$tmp_body"
      exit 0
    fi

    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    validate_issue_body_file "$body_file"
    ;;

  sync)
    issue_number=""
    body_file=""
    write_back="0"

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --write)
          write_back="1"
          shift
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for sync: $1"
          ;;
      esac
    done

    if [[ -n "$issue_number" && -n "$body_file" ]]; then
      die "use either --issue or --body-file, not both"
    fi
    if [[ -z "$issue_number" && -z "$body_file" ]]; then
      die "sync requires --issue or --body-file"
    fi

    require_cmd python3

    if [[ -n "$issue_number" ]]; then
      require_cmd gh
      tmp_body="$(mktemp)"
      tmp_synced="$(mktemp)"

      view_cmd=(gh issue view "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        view_cmd+=(-R "$repo_arg")
      fi
      view_cmd+=(--json body -q .body)
      "${view_cmd[@]}" >"$tmp_body"

      sync_issue_body_file "$tmp_body" >"$tmp_synced"
      validate_issue_body_file "$tmp_synced" >/dev/null

      edit_cmd=(gh issue edit "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        edit_cmd+=(-R "$repo_arg")
      fi
      edit_cmd+=(--body-file "$tmp_synced")

      if [[ "$dry_run" == "1" ]]; then
        echo "dry-run: $(print_cmd "${edit_cmd[@]}")" >&2
        cat "$tmp_synced"
        rm -f "$tmp_body" "$tmp_synced"
        exit 0
      fi

      run_cmd "${edit_cmd[@]}"
      rm -f "$tmp_body" "$tmp_synced"
      echo "ok: normalized issue #${issue_number} Task Decomposition"
      exit 0
    fi

    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    tmp_synced="$(mktemp)"
    sync_issue_body_file "$body_file" >"$tmp_synced"
    validate_issue_body_file "$tmp_synced" >/dev/null

    if [[ "$write_back" == "1" ]]; then
      if [[ "$dry_run" == "1" ]]; then
        echo "dry-run: $(print_cmd cp "$tmp_synced" "$body_file")" >&2
        cat "$tmp_synced"
        rm -f "$tmp_synced"
        exit 0
      fi
      cp "$tmp_synced" "$body_file"
      rm -f "$tmp_synced"
      echo "ok: normalized $body_file"
      exit 0
    fi

    cat "$tmp_synced"
    rm -f "$tmp_synced"
    ;;

  comment)
    issue_number=""
    body=""
    body_file=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --body)
          body="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for comment: $1"
          ;;
      esac
    done

    [[ -n "$issue_number" ]] || die "--issue is required for comment"

    if [[ -n "$body" && -n "$body_file" ]]; then
      die "use either --body or --body-file, not both"
    fi

    if [[ -z "$body" && -z "$body_file" ]]; then
      die "comment body is required"
    fi

    if [[ -n "$body_file" && ! -f "$body_file" ]]; then
      die "body file not found: $body_file"
    fi

    require_cmd gh

    cmd=(gh issue comment "$issue_number")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi
    if [[ -n "$body" ]]; then
      cmd+=(--body "$body")
    else
      cmd+=(--body-file "$body_file")
    fi

    run_cmd "${cmd[@]}"
    ;;

  close)
    issue_number=""
    reason="completed"
    comment=""
    comment_file=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --reason)
          reason="${2:-}"
          shift 2
          ;;
        --comment)
          comment="${2:-}"
          shift 2
          ;;
        --comment-file)
          comment_file="${2:-}"
          shift 2
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for close: $1"
          ;;
      esac
    done

    [[ -n "$issue_number" ]] || die "--issue is required for close"

    if [[ "$reason" != "completed" && "$reason" != "not planned" ]]; then
      die "--reason must be one of: completed, not planned"
    fi

    if [[ -n "$comment" && -n "$comment_file" ]]; then
      die "use either --comment or --comment-file, not both"
    fi

    if [[ -n "$comment_file" && ! -f "$comment_file" ]]; then
      die "comment file not found: $comment_file"
    fi

    require_cmd gh

    cmd=(gh issue close "$issue_number")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi
    cmd+=(--reason "$reason")

    if [[ -n "$comment" ]]; then
      cmd+=(--comment "$comment")
    elif [[ -n "$comment_file" ]]; then
      comment_text="$(cat "$comment_file")"
      cmd+=(--comment "$comment_text")
    fi

    run_cmd "${cmd[@]}"
    ;;

  reopen)
    issue_number=""
    comment=""
    comment_file=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --comment)
          comment="${2:-}"
          shift 2
          ;;
        --comment-file)
          comment_file="${2:-}"
          shift 2
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for reopen: $1"
          ;;
      esac
    done

    [[ -n "$issue_number" ]] || die "--issue is required for reopen"

    if [[ -n "$comment" && -n "$comment_file" ]]; then
      die "use either --comment or --comment-file, not both"
    fi

    if [[ -n "$comment_file" && ! -f "$comment_file" ]]; then
      die "comment file not found: $comment_file"
    fi

    require_cmd gh

    cmd=(gh issue reopen "$issue_number")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi

    if [[ -n "$comment" ]]; then
      cmd+=(--comment "$comment")
    elif [[ -n "$comment_file" ]]; then
      comment_text="$(cat "$comment_file")"
      cmd+=(--comment "$comment_text")
    fi

    run_cmd "${cmd[@]}"
    ;;

  -h|--help)
    usage
    ;;

  *)
    die "unknown subcommand: $subcommand"
    ;;
esac
