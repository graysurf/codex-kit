#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
default_pr_template="${skill_dir}/references/PR_BODY_TEMPLATE.md"
default_task_prompt_template="${skill_dir}/references/SUBAGENT_TASK_PROMPT_TEMPLATE.md"

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

usage() {
  cat <<'USAGE'
Usage:
  manage_issue_subagent_pr.sh <create-worktree|open-pr|respond-review|validate-pr-body|render-task-prompt> [options]

Subcommands:
  create-worktree  Create a dedicated worktree/branch for subagent implementation
  open-pr          Open a draft PR for an issue branch and sync PR URL back to issue
  respond-review   Post a PR follow-up comment referencing a main-agent review comment link
  validate-pr-body Validate a PR body (placeholders/template stubs are rejected)
  render-task-prompt Render a parameterized prompt template for a subagent task

Common options:
  --repo <owner/repo>    Target repository (passed to gh with -R)
  --dry-run              Print actions without executing commands

create-worktree options:
  --branch <name>        Branch to create (required)
  --base <ref>           Start-point reference (default: main)
  --worktree-name <name> Worktree folder name override (default from branch)
  --worktrees-root <dir> Worktrees root override (default: <repo>/../.worktrees/<repo>/issue)

open-pr options:
  --issue <number>       Issue number (required)
  --title <text>         PR title (required)
  --base <branch>        Base branch (default: main)
  --head <branch>        PR head branch (default: current branch)
  --body <text>          PR body text
  --body-file <path>     PR body file
  --use-template         Use references/PR_BODY_TEMPLATE.md when body not set
  --ready                Open non-draft PR (default: draft)
  --no-issue-comment     Do not comment the issue with PR URL

respond-review options:
  --pr <number>                  PR number (required)
  --review-comment-url <url>     Main-agent PR comment URL (required)
  --body <text>                  Additional response details
  --body-file <path>             Additional response details file
  --issue <number>               Optional issue number to mirror response status

validate-pr-body options:
  --body <text>                  PR body text
  --body-file <path>             PR body file
  --issue <number>               Expected issue number (optional, validates `## Issue` section when present)

render-task-prompt options:
  --issue <number>               Issue number (required)
  --task-id <id>                 Task id (required, e.g. T1)
  --summary <text>               Task summary from Task Decomposition (required)
  --owner <subagent-id>          Assigned subagent owner (required; must include 'subagent')
  --branch <name>                Assigned branch (required; non-TBD)
  --worktree <path>              Assigned worktree path (required; non-TBD)
  --execution-mode <mode>        per-task|per-sprint|single-pr (required)
  --pr-title <text>              PR title to use (required)
  --base <branch>                Base branch for PR/worktree (default: main)
  --notes <text>                 Task Notes column text (optional)
  --acceptance <text>            Acceptance bullet (repeatable)
  --acceptance-file <path>       Acceptance bullets file (one item per non-empty line)
  --template <path>              Prompt template file (default: references/SUBAGENT_TASK_PROMPT_TEMPLATE.md)
  --output <path>                Write rendered prompt to file (otherwise stdout)
USAGE
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || die "must run inside a git repository"
}

current_branch() {
  local branch=''
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [[ -n "$branch" ]] || die "cannot resolve current branch"
  printf '%s\n' "$branch"
}

validate_pr_body_text() {
  local body_text="${1:-}"
  local issue_number="${2:-}"
  local source_label="${3:-pr body}"

  python3 - "$issue_number" "$source_label" "$body_text" <<'PY'
import re
import sys

issue_number = (sys.argv[1] or "").strip()
source_label = (sys.argv[2] or "pr body").strip()
text = sys.argv[3]

if not text.strip():
    raise SystemExit(f"error: {source_label}: PR body must not be empty")

required_headings = ["## Summary", "## Scope", "## Testing", "## Issue"]
missing = [h for h in required_headings if h not in text]
if missing:
    raise SystemExit(f"error: {source_label}: missing required PR body sections: {', '.join(missing)}")

placeholder_patterns = [
    (r"<[^>\n]+>", "angle-bracket placeholder"),
    (r"\bTODO\b", "TODO placeholder"),
    (r"\bTBD\b", "TBD placeholder"),
    (r"#<number>", "issue-number placeholder"),
    (r"not run \(reason\)", "testing placeholder"),
    (r"<command> \(pass\)", "testing command placeholder"),
]
hits = []
for pattern, label in placeholder_patterns:
    m = re.search(pattern, text, flags=re.IGNORECASE)
    if m:
        hits.append(f"{label}: {m.group(0)}")

if issue_number:
    issue_pat = re.compile(rf"(?m)^\s*-\s*#\s*{re.escape(issue_number)}\s*$")
    if not issue_pat.search(text):
        hits.append(f"missing issue link bullet for #{issue_number} in ## Issue section")

if hits:
    joined = "; ".join(hits)
    raise SystemExit(f"error: {source_label}: invalid PR body content ({joined})")

print("ok: PR body validation passed")
PY
}

validate_pr_body_input() {
  local body_text="${1:-}"
  local body_file="${2:-}"
  local issue_number="${3:-}"
  local source_label="${4:-pr body}"

  if [[ -n "$body_text" && -n "$body_file" ]]; then
    die "use either --body or --body-file, not both"
  fi
  if [[ -n "$body_file" ]]; then
    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    validate_pr_body_text "$(cat "$body_file")" "$issue_number" "$source_label"
    return 0
  fi
  validate_pr_body_text "$body_text" "$issue_number" "$source_label"
}

to_lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

is_placeholder_value() {
  local value lowered
  value="${1:-}"
  lowered="$(to_lower "$value")"
  case "$lowered" in
    ""|"-"|tbd|none|n/a|na)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_execution_mode_value() {
  local raw lowered
  raw="${1:-}"
  lowered="$(to_lower "$raw")"
  lowered="${lowered//_/-}"
  lowered="${lowered// /-}"
  case "$lowered" in
    per-task|per-sprint|single-pr)
      printf '%s\n' "$lowered"
      ;;
    single)
      printf '%s\n' "single-pr"
      ;;
    pertask)
      printf '%s\n' "per-task"
      ;;
    persprint)
      printf '%s\n' "per-sprint"
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
}

is_main_agent_owner() {
  local owner lowered token
  owner="${1:-}"
  lowered="$(to_lower "$owner")"
  token="${lowered//_/ }"
  token="${token//-/ }"
  token="${token// /}"

  case "$token" in
    mainagent|main|codex|orchestrator|leadagent)
      return 0
      ;;
  esac
  if [[ "$lowered" == *"main-agent"* || "$lowered" == *"main agent"* ]]; then
    return 0
  fi
  return 1
}

shell_quote() {
  printf '%q' "${1:-}"
}

normalize_pr_announcement_ref() {
  local value=''
  value="$(echo "${1:-}" | tr -d '\r')"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  if [[ "$value" =~ ^#([0-9]+)$ ]]; then
    printf '#%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^PR#([0-9]+)$ ]]; then
    printf '#%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#([0-9]+)$ ]]; then
    printf '#%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^https://github\.com/[^/[:space:]]+/[^/[:space:]]+/pull/([0-9]+)([/?#].*)?$ ]]; then
    printf '#%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  printf '%s\n' "$value"
}

issue_read_body_cmd() {
  local issue_number="${1:-}"
  local out_file="${2:-}"
  local repo="${3:-}"
  [[ -n "$issue_number" ]] || die "issue number is required"
  [[ -n "$out_file" ]] || die "output file path is required"

  require_cmd gh
  local cmd=(gh issue view "$issue_number")
  if [[ -n "$repo" ]]; then
    cmd+=(-R "$repo")
  fi
  cmd+=(--json body -q .body)
  "${cmd[@]}" >"$out_file"
}

issue_update_body_cmd() {
  local issue_number="${1:-}"
  local body_file="${2:-}"
  local repo="${3:-}"
  [[ -n "$issue_number" ]] || die "issue number is required"
  [[ -f "$body_file" ]] || die "body file not found: $body_file"

  require_cmd gh
  local cmd=(gh issue edit "$issue_number" --body-file "$body_file")
  if [[ -n "$repo" ]]; then
    cmd+=(--repo "$repo")
  fi
  "${cmd[@]}" >/dev/null
}

resolve_repo_name_with_owner() {
  local repo="${1:-}"
  if [[ -n "$repo" ]]; then
    printf '%s\n' "$repo"
    return 0
  fi
  require_cmd gh
  gh repo view --json nameWithOwner -q .nameWithOwner
}

refresh_sprint_start_comments_pr_values() {
  local issue_number="${1:-}"
  local task_ids_csv="${2:-}"
  local pr_ref="${3:-}"
  local repo="${4:-}"
  local is_dry_run="${5:-0}"
  [[ -n "$issue_number" ]] || die "issue number is required for sprint comment sync"

  if [[ -z "$task_ids_csv" ]]; then
    return 0
  fi
  if [[ "$is_dry_run" == "1" ]]; then
    echo "dry-run: refresh sprint start comments PR values for issue #${issue_number}" >&2
    return 0
  fi

  local resolved_repo=''
  resolved_repo="$(resolve_repo_name_with_owner "$repo")"

  local refresh_out=''
  refresh_out="$(python3 - "$issue_number" "$task_ids_csv" "$pr_ref" "$resolved_repo" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
import tempfile

issue_number = sys.argv[1].strip()
task_ids_csv = sys.argv[2].strip()
pr_ref = sys.argv[3].strip()
repo = sys.argv[4].strip()

if not issue_number:
    raise SystemExit("error: issue number is required")
if not repo:
    raise SystemExit("error: repo is required")

target_tasks = {token.strip() for token in task_ids_csv.split(",") if token.strip()}
if not target_tasks:
    print("UPDATED_START_COMMENTS=0")
    raise SystemExit(0)


def parse_row(line: str) -> list[str]:
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return []
    return [cell.strip() for cell in s[1:-1].split("|")]


def update_start_comment_body(body: str) -> tuple[str, int]:
    lines = body.splitlines()
    changed_rows = 0

    idx = 0
    while idx < len(lines):
        if lines[idx].strip() != "| Task | Summary | PR |":
            idx += 1
            continue
        header = parse_row(lines[idx])
        if idx + 1 >= len(lines):
            break
        sep = parse_row(lines[idx + 1])
        if not header or not sep or len(header) != len(sep):
            idx += 1
            continue
        header_idx = {name: col for col, name in enumerate(header)}
        if "Task" not in header_idx or "PR" not in header_idx:
            idx += 1
            continue

        row_i = idx + 2
        while row_i < len(lines):
            row = parse_row(lines[row_i])
            if not row or len(row) != len(header):
                break
            task_id = row[header_idx["Task"]].strip()
            if task_id in target_tasks:
                if row[header_idx["PR"]].strip() != pr_ref:
                    row[header_idx["PR"]] = pr_ref
                    lines[row_i] = "| " + " | ".join(row) + " |"
                    changed_rows += 1
            row_i += 1
        idx = row_i + 1

    if changed_rows == 0:
        return body, 0
    return "\n".join(lines) + "\n", changed_rows


view_cmd = ["gh", "issue", "view", issue_number, "--repo", repo, "--json", "comments"]
view = subprocess.run(view_cmd, capture_output=True, text=True, check=True)
comments = json.loads(view.stdout).get("comments", [])

updated_comments = 0
for comment in comments:
    body = comment.get("body", "")
    new_body, changed_rows = update_start_comment_body(body)
    if changed_rows == 0:
        continue
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as tmp:
        payload_path = pathlib.Path(tmp.name)
        json.dump({"body": new_body}, tmp)
    try:
        patch_cmd = [
            "gh",
            "api",
            f"repos/{repo}/issues/comments/{comment['id']}",
            "--method",
            "PATCH",
            "--input",
            str(payload_path),
        ]
        subprocess.run(patch_cmd, capture_output=True, text=True, check=True)
        updated_comments += 1
    finally:
        payload_path.unlink(missing_ok=True)

print(f"UPDATED_START_COMMENTS={updated_comments}")
PY
)"

  if [[ -n "$refresh_out" ]]; then
    echo "$refresh_out" >&2
  fi
}

sync_issue_task_pr_by_branch() {
  local issue_number="${1:-}"
  local head_branch="${2:-}"
  local pr_ref="${3:-}"
  local repo="${4:-}"
  local is_dry_run="${5:-0}"
  [[ -n "$issue_number" ]] || die "issue number is required for task PR sync"
  [[ -n "$head_branch" ]] || die "head branch is required for task PR sync"

  if [[ "$is_dry_run" == "1" ]]; then
    echo "dry-run: sync Task Decomposition PR by branch ${head_branch} -> ${pr_ref}" >&2
    return 0
  fi

  local issue_body_file=''
  issue_body_file="$(mktemp)"
  issue_read_body_cmd "$issue_number" "$issue_body_file" "$repo"

  local synced_body_file=''
  synced_body_file="$(mktemp)"

  local sync_out=''
  sync_out="$(python3 - "$issue_body_file" "$head_branch" "$pr_ref" "$synced_body_file" <<'PY'
import pathlib
import re
import sys

body_path = pathlib.Path(sys.argv[1])
head_branch = sys.argv[2].strip()
pr_ref = sys.argv[3].strip()
output_path = pathlib.Path(sys.argv[4])

if not body_path.is_file():
    raise SystemExit(f"error: issue body file not found: {body_path}")
if not head_branch:
    raise SystemExit("error: head branch is required")

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


def normalize_branch(value: str) -> str:
    token = (value or "").strip()
    if token.startswith("`") and token.endswith("`") and len(token) >= 2:
        token = token[1:-1].strip()
    return token


def extract_pr_group(notes: str) -> str:
    m = re.search(r"(?:^|;)\s*pr-group=([^;]+)", notes or "", flags=re.IGNORECASE)
    if not m:
        return ""
    return m.group(1).strip()


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


start, end = section_bounds("## Task Decomposition")
table_rows = [idx for idx in range(start, end) if lines[idx].strip().startswith("|")]
if len(table_rows) < 3:
    raise SystemExit("error: Task Decomposition must contain a markdown table with at least one task row")

headers = parse_row(lines[table_rows[0]])
required = ["Task", "Branch", "PR"]
missing = [name for name in required if name not in headers]
if missing:
    raise SystemExit("error: missing Task Decomposition columns: " + ", ".join(missing))
header_idx = {name: idx for idx, name in enumerate(headers)}
status_idx = header_idx.get("Status")
notes_idx = header_idx.get("Notes")

entries = []
normalized_pr_rows = 0
for idx in table_rows[2:]:
    cells = parse_row(lines[idx])
    if not cells or len(cells) != len(headers):
        continue

    normalized_pr = normalize_pr_display(cells[header_idx["PR"]].strip())
    if cells[header_idx["PR"]].strip() != normalized_pr:
        cells[header_idx["PR"]] = normalized_pr
        lines[idx] = "| " + " | ".join(cells) + " |"
        normalized_pr_rows += 1

    task_id = cells[header_idx["Task"]].strip()
    branch = normalize_branch(cells[header_idx["Branch"]])
    notes = cells[notes_idx].strip() if notes_idx is not None else ""
    pr_group = extract_pr_group(notes)
    entries.append(
        {
            "line_idx": idx,
            "cells": cells,
            "task": task_id,
            "branch": branch,
            "pr_group": pr_group,
        }
    )

target_groups = set()
target_indices = set()
for entry in entries:
    if entry["branch"] != head_branch:
        continue
    target_indices.add(entry["line_idx"])
    if entry["pr_group"]:
        target_groups.add(entry["pr_group"])

for entry in entries:
    if entry["pr_group"] and entry["pr_group"] in target_groups:
        target_indices.add(entry["line_idx"])

updated_tasks = []
for entry in entries:
    if entry["line_idx"] not in target_indices:
        continue
    cells = entry["cells"]
    changed = False
    if cells[header_idx["PR"]].strip() != pr_ref:
        cells[header_idx["PR"]] = pr_ref
        changed = True
    if status_idx is not None:
        status_value = (cells[status_idx] or "").strip().lower()
        if status_value == "planned":
            cells[status_idx] = "in-progress"
            changed = True
    if changed:
        lines[entry["line_idx"]] = "| " + " | ".join(cells) + " |"
        updated_tasks.append(entry["task"])

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"UPDATED_TASK_COUNT={len(updated_tasks)}")
print("UPDATED_TASK_IDS=" + ",".join(updated_tasks))
print(f"NORMALIZED_PR_ROWS={normalized_pr_rows}")
PY
)"

  local updated_count=''
  local updated_task_ids=''
  local normalized_pr_rows=''
  updated_count="$(printf '%s\n' "$sync_out" | awk -F= '/^UPDATED_TASK_COUNT=/{print $2; exit}')"
  updated_task_ids="$(printf '%s\n' "$sync_out" | awk -F= '/^UPDATED_TASK_IDS=/{print $2; exit}')"
  normalized_pr_rows="$(printf '%s\n' "$sync_out" | awk -F= '/^NORMALIZED_PR_ROWS=/{print $2; exit}')"
  updated_count="${updated_count:-0}"
  normalized_pr_rows="${normalized_pr_rows:-0}"

  local should_update='0'
  if [[ "$updated_count" =~ ^[0-9]+$ ]] && [[ "$updated_count" -gt 0 ]]; then
    should_update='1'
  fi
  if [[ "$normalized_pr_rows" =~ ^[0-9]+$ ]] && [[ "$normalized_pr_rows" -gt 0 ]]; then
    should_update='1'
  fi

  if [[ "$should_update" == '1' ]]; then
    issue_update_body_cmd "$issue_number" "$synced_body_file" "$repo"
    echo "TASK_DECOMPOSITION_PR_SYNC=updated tasks=${updated_task_ids} normalized_pr_rows=${normalized_pr_rows}" >&2
    if [[ -n "$updated_task_ids" ]]; then
      refresh_sprint_start_comments_pr_values "$issue_number" "$updated_task_ids" "$pr_ref" "$repo" "$is_dry_run"
    fi
  else
    echo "TASK_DECOMPOSITION_PR_SYNC=no matching task rows for branch ${head_branch}" >&2
  fi

  rm -f "$issue_body_file" "$synced_body_file"
}

best_effort_sync_issue_task_pr_by_branch() {
  local issue_number="${1:-}"
  local head_branch="${2:-}"
  local pr_ref="${3:-}"
  local repo="${4:-}"
  local is_dry_run="${5:-0}"

  set +e
  sync_issue_task_pr_by_branch "$issue_number" "$head_branch" "$pr_ref" "$repo" "$is_dry_run"
  local sync_rc=$?
  set -e

  if [[ "$sync_rc" -ne 0 ]]; then
    echo "warn: unable to sync issue task PR fields automatically (issue #${issue_number}, branch=${head_branch})" >&2
  fi
  return 0
}

render_task_prompt_template_text() {
  local template_file="${1:-}"
  [[ -f "$template_file" ]] || die "template file not found: $template_file"

  python3 - "$template_file" <<'PY'
import os
import re
import sys
from pathlib import Path

template_file = Path(sys.argv[1])
text = template_file.read_text(encoding="utf-8")

keys = [
    "ISSUE_NUMBER",
    "TASK_ID",
    "TASK_SUMMARY",
    "TASK_OWNER",
    "BRANCH",
    "WORKTREE",
    "EXECUTION_MODE",
    "BASE_BRANCH",
    "PR_TITLE",
    "REPO_DISPLAY",
    "REPO_FLAG",
    "TASK_NOTES_BULLETS",
    "ACCEPTANCE_BULLETS",
    "PR_BODY_TEMPLATE_PATH",
    "PR_BODY_DRAFT_PATH",
    "ISSUE_SUBAGENT_PR_SCRIPT",
    "CREATE_WORKTREE_HINT",
    "OPEN_PR_COMMAND",
    "VALIDATE_PR_BODY_COMMAND",
]
values = {k: os.environ.get(k, "") for k in keys}

for key, value in values.items():
    text = text.replace(f"{{{{{key}}}}}", value)

unresolved = sorted(set(re.findall(r"\{\{[A-Z0-9_]+\}\}", text)))
if unresolved:
    raise SystemExit(
        "error: unresolved prompt template placeholders: " + ", ".join(unresolved)
    )

sys.stdout.write(text.rstrip("\n") + "\n")
PY
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
  create-worktree)
    branch=""
    base_ref="main"
    worktree_name=""
    worktrees_root=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --branch)
          branch="${2:-}"
          shift 2
          ;;
        --base)
          base_ref="${2:-}"
          shift 2
          ;;
        --worktree-name)
          worktree_name="${2:-}"
          shift 2
          ;;
        --worktrees-root)
          worktrees_root="${2:-}"
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
          die "unknown option for create-worktree: $1"
          ;;
      esac
    done

    [[ -n "$branch" ]] || die "--branch is required for create-worktree"

    require_cmd git

    root="$(repo_root)"
    repo_name="$(basename "$root")"

    if [[ -z "$worktrees_root" ]]; then
      worktrees_root="${root}/../.worktrees/${repo_name}/issue"
    fi

    if [[ -z "$worktree_name" ]]; then
      worktree_name="${branch//\//__}"
    fi

    worktree_path="${worktrees_root%/}/${worktree_name}"

    if [[ -e "$worktree_path" ]]; then
      die "worktree path already exists: $worktree_path"
    fi

    mkdir -p "$worktrees_root"

    cmd=(git worktree add -b "$branch" "$worktree_path" "$base_ref")

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${cmd[@]}"
      echo "$worktree_path"
      exit 0
    fi

    run_cmd "${cmd[@]}"
    echo "$worktree_path"
    ;;

  open-pr)
    issue_number=""
    pr_title=""
    base_branch="main"
    head_branch=""
    body=""
    body_file=""
    use_template="0"
    is_draft="1"
    comment_issue="1"

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --title)
          pr_title="${2:-}"
          shift 2
          ;;
        --base)
          base_branch="${2:-}"
          shift 2
          ;;
        --head)
          head_branch="${2:-}"
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
        --ready)
          is_draft="0"
          shift
          ;;
        --no-issue-comment)
          comment_issue="0"
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
          die "unknown option for open-pr: $1"
          ;;
      esac
    done

    [[ -n "$issue_number" ]] || die "--issue is required for open-pr"
    [[ -n "$pr_title" ]] || die "--title is required for open-pr"

    if [[ -z "$head_branch" ]]; then
      require_cmd git
      head_branch="$(current_branch)"
    fi

    if [[ "$use_template" == "1" && -z "$body" && -z "$body_file" ]]; then
      body_file="$default_pr_template"
    fi

    if [[ -n "$body_file" && ! -f "$body_file" ]]; then
      die "body file not found: $body_file"
    fi

    # Subagent must submit a filled PR body. `--use-template` is allowed, but the
    # template must be copied/edited first so placeholder tokens are gone.
    if [[ -n "$body" || -n "$body_file" ]]; then
      validate_pr_body_input "$body" "$body_file" "$issue_number" "open-pr"
    else
      die "PR body is required; provide --body/--body-file (or a filled template via --use-template)"
    fi

    require_cmd gh

    cmd=(gh pr create --title "$pr_title" --base "$base_branch" --head "$head_branch")
    if [[ -n "$repo_arg" ]]; then
      cmd+=(-R "$repo_arg")
    fi
    if [[ "$is_draft" == "1" ]]; then
      cmd+=(--draft)
    fi

    if [[ -n "$body" ]]; then
      cmd+=(--body "$body")
    else
      cmd+=(--body-file "$body_file")
    fi

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${cmd[@]}"
      pr_url="DRY-RUN-PR-URL"
      pr_comment_ref="$(normalize_pr_announcement_ref "$pr_url")"
      best_effort_sync_issue_task_pr_by_branch "$issue_number" "$head_branch" "$pr_comment_ref" "$repo_arg" "$dry_run"
      if [[ "$comment_issue" == "1" ]]; then
        issue_cmd=(gh issue comment "$issue_number")
        if [[ -n "$repo_arg" ]]; then
          issue_cmd+=(-R "$repo_arg")
        fi
        issue_cmd+=(--body "Subagent opened PR: ${pr_comment_ref}")
        run_cmd "${issue_cmd[@]}"
      fi
      echo "$pr_url"
      exit 0
    fi

    pr_url="$(run_cmd "${cmd[@]}")"
    pr_comment_ref="$(normalize_pr_announcement_ref "$pr_url")"
    best_effort_sync_issue_task_pr_by_branch "$issue_number" "$head_branch" "$pr_comment_ref" "$repo_arg" "$dry_run"
    if [[ "$comment_issue" == "1" ]]; then
      issue_cmd=(gh issue comment "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        issue_cmd+=(-R "$repo_arg")
      fi
      issue_cmd+=(--body "Subagent opened PR: ${pr_comment_ref}")
      run_cmd "${issue_cmd[@]}"
    fi

    echo "$pr_url"
    ;;

  render-task-prompt)
    issue_number=""
    task_id=""
    task_summary=""
    task_owner=""
    branch=""
    worktree=""
    execution_mode=""
    pr_title=""
    base_branch="main"
    task_notes=""
    acceptance_file=""
    prompt_template_file="$default_task_prompt_template"
    output_file=""
    acceptance_items=()

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --task-id)
          task_id="${2:-}"
          shift 2
          ;;
        --summary)
          task_summary="${2:-}"
          shift 2
          ;;
        --owner)
          task_owner="${2:-}"
          shift 2
          ;;
        --branch)
          branch="${2:-}"
          shift 2
          ;;
        --worktree)
          worktree="${2:-}"
          shift 2
          ;;
        --execution-mode)
          execution_mode="${2:-}"
          shift 2
          ;;
        --pr-title)
          pr_title="${2:-}"
          shift 2
          ;;
        --base)
          base_branch="${2:-}"
          shift 2
          ;;
        --notes)
          task_notes="${2:-}"
          shift 2
          ;;
        --acceptance)
          acceptance_items+=("${2:-}")
          shift 2
          ;;
        --acceptance-file)
          acceptance_file="${2:-}"
          shift 2
          ;;
        --template)
          prompt_template_file="${2:-}"
          shift 2
          ;;
        --output)
          output_file="${2:-}"
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
          die "unknown option for render-task-prompt: $1"
          ;;
      esac
    done

    [[ "$issue_number" =~ ^[0-9]+$ ]] || die "--issue must be a numeric issue number"
    [[ -n "$task_id" ]] || die "--task-id is required for render-task-prompt"
    [[ -n "$task_summary" ]] || die "--summary is required for render-task-prompt"
    [[ -n "$task_owner" ]] || die "--owner is required for render-task-prompt"
    [[ -n "$branch" ]] || die "--branch is required for render-task-prompt"
    [[ -n "$worktree" ]] || die "--worktree is required for render-task-prompt"
    [[ -n "$execution_mode" ]] || die "--execution-mode is required for render-task-prompt"
    [[ -n "$pr_title" ]] || die "--pr-title is required for render-task-prompt"

    is_placeholder_value "$task_id" && die "--task-id must not be a placeholder"
    is_placeholder_value "$task_summary" && die "--summary must not be a placeholder"
    is_placeholder_value "$task_owner" && die "--owner must not be TBD"
    is_placeholder_value "$branch" && die "--branch must not be TBD"
    is_placeholder_value "$worktree" && die "--worktree must not be TBD"
    is_placeholder_value "$pr_title" && die "--pr-title must not be TBD"

    if is_main_agent_owner "$task_owner"; then
      die "--owner must not be main-agent; subagent-only ownership is required"
    fi
    if [[ "$(to_lower "$task_owner")" != *"subagent"* ]]; then
      die "--owner must include 'subagent' to reflect delegated implementation ownership"
    fi

    execution_mode="$(normalize_execution_mode_value "$execution_mode")"
    case "$execution_mode" in
      per-task|per-sprint|single-pr)
        ;;
      *)
        die "--execution-mode must be one of: per-task, per-sprint, single-pr"
        ;;
    esac

    if [[ -n "$acceptance_file" ]]; then
      [[ -f "$acceptance_file" ]] || die "acceptance file not found: $acceptance_file"
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "${line// }" ]] || continue
        acceptance_items+=("$line")
      done <"$acceptance_file"
    fi

    acceptance_bullets=""
    if [[ ${#acceptance_items[@]} -eq 0 ]]; then
      acceptance_bullets='- (Use issue/plan acceptance criteria for this task if no task-specific criteria were supplied.)'
    else
      for item in "${acceptance_items[@]}"; do
        acceptance_bullets+="- ${item}"$'\n'
      done
      acceptance_bullets="${acceptance_bullets%$'\n'}"
    fi

    if is_placeholder_value "$task_notes"; then
      task_notes=""
    fi
    if [[ -z "$task_notes" ]]; then
      task_notes_bullets='- (No additional task notes.)'
    else
      task_notes_bullets="- ${task_notes}"
    fi

    task_id_safe="$(printf '%s' "$task_id" | tr -cs 'A-Za-z0-9._-' '-')"
    task_id_safe="${task_id_safe#-}"
    task_id_safe="${task_id_safe%-}"
    [[ -n "$task_id_safe" ]] || task_id_safe="task"

    issue_subagent_pr_script_ref='$AGENT_HOME/skills/workflows/issue/issue-subagent-pr/scripts/manage_issue_subagent_pr.sh'
    pr_body_draft_path="/tmp/pr-${issue_number}-${task_id_safe}.md"
    if [[ -n "$repo_arg" ]]; then
      repo_display="$repo_arg"
      repo_flag=" --repo $(shell_quote "$repo_arg")"
    else
      repo_display="(current repo context)"
      repo_flag=""
    fi

    validate_pr_body_command="${issue_subagent_pr_script_ref} validate-pr-body${repo_flag} --issue $(shell_quote "$issue_number") --body-file $(shell_quote "$pr_body_draft_path")"
    open_pr_command="${issue_subagent_pr_script_ref} open-pr${repo_flag} --issue $(shell_quote "$issue_number") --title $(shell_quote "$pr_title") --base $(shell_quote "$base_branch") --head $(shell_quote "$branch") --body-file $(shell_quote "$pr_body_draft_path")"
    create_worktree_hint="Use assigned worktree path $(shell_quote "$worktree"). If the worktree does not exist yet, create it with branch $(shell_quote "$branch") from base $(shell_quote "$base_branch"), then verify the resulting path matches the assignment before editing."

    rendered_prompt="$(
      ISSUE_NUMBER="$issue_number" \
      TASK_ID="$task_id" \
      TASK_SUMMARY="$task_summary" \
      TASK_OWNER="$task_owner" \
      BRANCH="$branch" \
      WORKTREE="$worktree" \
      EXECUTION_MODE="$execution_mode" \
      BASE_BRANCH="$base_branch" \
      PR_TITLE="$pr_title" \
      REPO_DISPLAY="$repo_display" \
      REPO_FLAG="$repo_flag" \
      TASK_NOTES_BULLETS="$task_notes_bullets" \
      ACCEPTANCE_BULLETS="$acceptance_bullets" \
      PR_BODY_TEMPLATE_PATH="$default_pr_template" \
      PR_BODY_DRAFT_PATH="$pr_body_draft_path" \
      ISSUE_SUBAGENT_PR_SCRIPT="$issue_subagent_pr_script_ref" \
      CREATE_WORKTREE_HINT="$create_worktree_hint" \
      OPEN_PR_COMMAND="$open_pr_command" \
      VALIDATE_PR_BODY_COMMAND="$validate_pr_body_command" \
      render_task_prompt_template_text "$prompt_template_file"
    )"

    if [[ -n "$output_file" ]]; then
      output_dir="$(dirname "$output_file")"
      if [[ "$dry_run" == "1" ]]; then
        echo "dry-run: $(print_cmd mkdir -p "$output_dir")" >&2
        echo "dry-run: $(print_cmd write "$output_file")" >&2
        printf '%s\n' "$rendered_prompt"
        exit 0
      fi
      mkdir -p "$output_dir"
      printf '%s\n' "$rendered_prompt" >"$output_file"
      echo "$output_file"
      exit 0
    fi

    printf '%s\n' "$rendered_prompt"
    ;;

  validate-pr-body)
    issue_number=""
    body=""
    body_file=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --body)
          body="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --issue)
          issue_number="${2:-}"
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
          die "unknown option for validate-pr-body: $1"
          ;;
      esac
    done

    if [[ -z "$body" && -z "$body_file" ]]; then
      die "validate-pr-body requires --body or --body-file"
    fi
    validate_pr_body_input "$body" "$body_file" "$issue_number" "validate-pr-body"
    ;;

  respond-review)
    pr_number=""
    review_comment_url=""
    body=""
    body_file=""
    issue_number=""

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --pr)
          pr_number="${2:-}"
          shift 2
          ;;
        --review-comment-url)
          review_comment_url="${2:-}"
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
        --issue)
          issue_number="${2:-}"
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
          die "unknown option for respond-review: $1"
          ;;
      esac
    done

    [[ -n "$pr_number" ]] || die "--pr is required for respond-review"
    [[ -n "$review_comment_url" ]] || die "--review-comment-url is required for respond-review"

    if [[ -n "$body" && -n "$body_file" ]]; then
      die "use either --body or --body-file, not both"
    fi

    if [[ -n "$body_file" && ! -f "$body_file" ]]; then
      die "body file not found: $body_file"
    fi

    require_cmd gh

    additional=""
    if [[ -n "$body" ]]; then
      additional="$body"
    elif [[ -n "$body_file" ]]; then
      additional="$(cat "$body_file")"
    fi

    response_body="Addressing main-agent review comment: ${review_comment_url}"
    if [[ -n "$additional" ]]; then
      response_body+=$'\n\n'
      response_body+="$additional"
    fi

    comment_cmd=(gh pr comment "$pr_number")
    if [[ -n "$repo_arg" ]]; then
      comment_cmd+=(-R "$repo_arg")
    fi
    comment_cmd+=(--body "$response_body")

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${comment_cmd[@]}"
      pr_comment_url="DRY-RUN-PR-COMMENT-URL"
      if [[ -n "$issue_number" ]]; then
        issue_cmd=(gh issue comment "$issue_number")
        if [[ -n "$repo_arg" ]]; then
          issue_cmd+=(-R "$repo_arg")
        fi
        issue_cmd+=(--body "Subagent posted an update in PR #${pr_number}: ${pr_comment_url}")
        run_cmd "${issue_cmd[@]}"
      fi
      echo "$pr_comment_url"
      exit 0
    fi

    run_cmd "${comment_cmd[@]}"

    view_cmd=(gh pr view "$pr_number")
    if [[ -n "$repo_arg" ]]; then
      view_cmd+=(-R "$repo_arg")
    fi
    view_cmd+=(--json comments -q '.comments[-1].url')
    pr_comment_url="$(run_cmd "${view_cmd[@]}")"

    if [[ -n "$issue_number" ]]; then
      issue_cmd=(gh issue comment "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        issue_cmd+=(-R "$repo_arg")
      fi
      issue_cmd+=(--body "Subagent posted an update in PR #${pr_number}: ${pr_comment_url}")
      run_cmd "${issue_cmd[@]}"
    fi

    echo "$pr_comment_url"
    ;;

  -h|--help)
    usage
    ;;

  *)
    die "unknown subcommand: $subcommand"
    ;;
esac
