#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_dir="$(cd "${script_dir}/.." && pwd -P)"
repo_root_default="$(cd "${skill_dir}/../../.." && pwd -P)"
agent_home="${AGENT_HOME:-$repo_root_default}"

issue_lifecycle_script="${repo_root_default}/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh"
if [[ ! -x "$issue_lifecycle_script" ]]; then
  issue_lifecycle_script="${agent_home%/}/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh"
fi

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

trim_text() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

to_lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

is_pr_placeholder() {
  local value=''
  value="$(trim_text "${1:-}")"
  local lower=''
  lower="$(to_lower "$value")"
  case "$lower" in
    ""|"-"|"tbd"|"none"|"n/a"|"na")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_owner_token() {
  local value=''
  value="$(trim_text "${1:-}")"
  value="$(to_lower "$value")"
  value="${value//_/ }"
  value="${value//-/ }"
  value="${value//\// }"
  value="${value// /}"
  printf '%s' "$value"
}

is_owner_placeholder() {
  local normalized=''
  normalized="$(normalize_owner_token "${1:-}")"
  case "$normalized" in
    ""|"tbd"|"none"|"na")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_main_agent_owner() {
  local owner_raw=''
  owner_raw="$(trim_text "${1:-}")"
  local owner_lower=''
  owner_lower="$(to_lower "$owner_raw")"
  local normalized=''
  normalized="$(normalize_owner_token "$owner_raw")"

  case "$normalized" in
    "mainagent"|"main"|"codex"|"orchestrator"|"leadagent")
      return 0
      ;;
  esac

  case "$owner_lower" in
    *"main-agent"*|*"main agent"*)
      return 0
      ;;
  esac

  return 1
}

is_subagent_owner() {
  local owner_lower=''
  owner_lower="$(to_lower "$(trim_text "${1:-}")")"
  [[ "$owner_lower" == *"subagent"* ]]
}

body_contains_task_decomposition() {
  local body_file="${1:-}"
  [[ -f "$body_file" ]] || return 1
  if command -v rg >/dev/null 2>&1; then
    rg -q '^## Task Decomposition$' "$body_file"
    return $?
  fi
  grep -Eq '^## Task Decomposition$' "$body_file"
}

enforce_subagent_owner_policy() {
  local body_file="${1:-}"
  local source_label="${2:-issue body}"
  [[ -f "$body_file" ]] || die "owner policy check body file not found: $body_file"

  if ! body_contains_task_decomposition "$body_file"; then
    return 0
  fi

  local errors=()
  while IFS=$'\t' read -r task _summary owner branch worktree execution_mode _pr status _notes; do
    local task_id owner_value branch_value worktree_value mode_value status_value
    task_id="$(trim_text "$task")"
    owner_value="$(trim_text "$owner")"
    branch_value="$(trim_text "$branch")"
    worktree_value="$(trim_text "$worktree")"
    mode_value="$(trim_text "$execution_mode")"
    status_value="$(to_lower "$(trim_text "$status")")"

    # Planning/blocked rows can remain TBD until execution details are real.
    if [[ "$status_value" == "planned" || "$status_value" == "blocked" ]]; then
      continue
    fi
    if is_owner_placeholder "$owner_value"; then
      errors+=("${task_id}: Owner must reference a subagent identity (got: ${owner_value:-<empty>})")
      continue
    fi
    if is_main_agent_owner "$owner_value"; then
      errors+=("${task_id}: Owner must not be main-agent; main-agent is orchestration/review-only")
      continue
    fi
    if ! is_subagent_owner "$owner_value"; then
      errors+=("${task_id}: Owner must include 'subagent' to mark delegated implementation ownership")
      continue
    fi
    if is_owner_placeholder "$branch_value"; then
      errors+=("${task_id}: Branch must not be TBD when Status is ${status_value:-<empty>}")
    fi
    if is_owner_placeholder "$worktree_value"; then
      errors+=("${task_id}: Worktree must not be TBD when Status is ${status_value:-<empty>}")
    fi
    if is_owner_placeholder "$mode_value"; then
      errors+=("${task_id}: Execution Mode must not be TBD when Status is ${status_value:-<empty>}")
    fi
  done < <(parse_issue_tasks_tsv "$body_file")

  if [[ ${#errors[@]} -gt 0 ]]; then
    local err=''
    for err in "${errors[@]}"; do
      echo "error: ${source_label}: ${err}" >&2
    done
    return 1
  fi

  return 0
}

normalize_pr_ref() {
  local value
  value="$(trim_text "${1:-}")"
  if [[ "$value" =~ ^PR#([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^#([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  printf '%s\n' "$value"
}

canonical_pr_display() {
  local value
  value="$(trim_text "${1:-}")"
  if is_pr_placeholder "$value"; then
    printf 'TBD\n'
    return 0
  fi

  local normalized
  normalized="$(normalize_pr_ref "$value")"
  if [[ "$normalized" =~ ^[0-9]+$ ]]; then
    printf '#%s\n' "$normalized"
    return 0
  fi
  printf '%s\n' "$normalized"
}

extract_issue_number_from_url() {
  local issue_url="${1:-}"
  if [[ "$issue_url" =~ /issues/([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$issue_url" == "DRY-RUN-ISSUE-URL" ]]; then
    printf '999\n'
    return 0
  fi
  return 1
}

ensure_issue_lifecycle_script() {
  [[ -x "$issue_lifecycle_script" ]] || die "missing executable: $issue_lifecycle_script"
}

run_issue_lifecycle() {
  local cmd=("$issue_lifecycle_script" "$@")
  if [[ -n "$repo_arg" ]]; then
    cmd+=(--repo "$repo_arg")
  fi
  if [[ "$dry_run" == "1" ]]; then
    cmd+=(--dry-run)
  fi
  "${cmd[@]}"
}

issue_read_cmd() {
  local issue_number="${1:-}"
  local out_file="${2:-}"
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

fetch_issue_state() {
  local issue_number="${1:-}"
  [[ -n "$issue_number" ]] || die "issue number is required"
  require_cmd gh

  local cmd=(gh issue view "$issue_number")
  if [[ -n "$repo_arg" ]]; then
    cmd+=(-R "$repo_arg")
  fi
  cmd+=(--json state -q .state)
  "${cmd[@]}"
}

parse_issue_tasks_tsv() {
  local body_file="${1:-}"
  [[ -f "$body_file" ]] || die "issue body file not found: $body_file"

  python3 - "$body_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.splitlines()


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


required_columns = ["Task", "Summary", "Owner", "Branch", "Worktree", "PR", "Status", "Notes"]
start, end = section_bounds("## Task Decomposition")
section = lines[start:end]
table_lines = [line for line in section if line.strip().startswith("|")]
if len(table_lines) < 3:
    raise SystemExit("error: Task Decomposition must contain a markdown table with at least one row")

headers = parse_row(table_lines[0])
missing = [col for col in required_columns if col not in headers]
if missing:
    raise SystemExit("error: missing Task Decomposition columns: " + ", ".join(missing))

rows = []
for raw in table_lines[2:]:
    cells = parse_row(raw)
    if not cells:
        continue
    if len(cells) != len(headers):
        raise SystemExit("error: malformed Task Decomposition row")
    row = {headers[idx]: cells[idx] for idx in range(len(headers))}
    if "Execution Mode" not in row:
        row["Execution Mode"] = "TBD"
    if not any(v.strip() for v in cells):
        continue
    rows.append(row)

if not rows:
    raise SystemExit("error: Task Decomposition table must include at least one task row")

for row in rows:
    values = [
        row.get("Task", "").replace("\t", " "),
        row.get("Summary", "").replace("\t", " "),
        row.get("Owner", "").replace("\t", " "),
        row.get("Branch", "").replace("\t", " "),
        row.get("Worktree", "").replace("\t", " "),
        row.get("Execution Mode", "").replace("\t", " "),
        row.get("PR", "").replace("\t", " "),
        row.get("Status", "").replace("\t", " "),
        row.get("Notes", "").replace("\t", " "),
    ]
    print("\t".join(values))
PY
}

validate_approval_comment_url() {
  local url="${1:-}"
  python3 - "$url" <<'PY'
import re
import sys

url = sys.argv[1].strip()
pat = re.compile(r"^https://github\.com/([^/]+)/([^/]+)/(issues|pull)/(\d+)#issuecomment-(\d+)$")
m = pat.match(url)
if not m:
    raise SystemExit("error: --approved-comment-url must be a GitHub issues/pull comment URL")
print("\t".join(m.groups()))
PY
}

fetch_pr_meta_tsv() {
  local pr_ref="${1:-}"
  require_cmd gh

  local cmd=(gh pr view "$pr_ref")
  if [[ -n "$repo_arg" ]]; then
    cmd+=(-R "$repo_arg")
  fi
  cmd+=(
    --json
    "number,url,state,isDraft,reviewDecision,mergeStateStatus,mergedAt"
    -q
    '[.number, .url, .state, (if .isDraft then "true" else "false" end), ((.reviewDecision // "") | if . == "" then "NONE" else . end), ((.mergeStateStatus // "") | if . == "" then "UNKNOWN" else . end), (.mergedAt // "")] | @tsv'
  )

  "${cmd[@]}"
}

build_status_snapshot() {
  local body_file="${1:-}"

  local now_utc
  now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local nl=$'\n'

  local output="## Main-Agent Status Snapshot${nl}${nl}"
  output+="- Generated at: ${now_utc}${nl}${nl}"
  output+="| Task | Summary | Planned Status | PR | PR State | Review | Suggested |${nl}"
  output+="| --- | --- | --- | --- | --- | --- | --- |${nl}"

  local errors=()
  local has_rows="0"

  while IFS=$'\t' read -r task summary _owner _branch _worktree _execution_mode pr status _notes; do
    has_rows="1"
    local task_id summary_value pr_value planned_status
    task_id="$(trim_text "$task")"
    summary_value="$(trim_text "$summary")"
    pr_value="$(trim_text "$pr")"
    planned_status="$(trim_text "$status")"

    local pr_display pr_state review_state suggested
    pr_display="$pr_value"
    pr_state="NO_PR"
    review_state="-"
    suggested="planned"

    if is_pr_placeholder "$pr_value"; then
      pr_display="TBD"
      if [[ "$planned_status" == "done" ]]; then
        suggested="blocked"
      fi
    else
      local pr_ref
      pr_ref="$(normalize_pr_ref "$pr_value")"
      pr_display="$(canonical_pr_display "$pr_value")"

      if [[ "$dry_run" == "1" ]]; then
        pr_state="UNKNOWN"
        review_state="UNKNOWN"
        suggested="in-progress"
      else
        local meta
        set +e
        meta="$(fetch_pr_meta_tsv "$pr_ref" 2>&1)"
        local meta_code=$?
        set -e
        if [[ "$meta_code" -ne 0 ]]; then
          errors+=("${task_id}: failed to query PR ${pr_ref}: ${meta}")
          pr_state="ERROR"
          review_state="ERROR"
          suggested="blocked"
        else
          local _pr_number pr_url state _is_draft review_decision _merge_status merged_at
          IFS=$'\t' read -r _pr_number pr_url state _is_draft review_decision _merge_status merged_at <<<"$meta"
          pr_display="${pr_url:-$pr_ref}"
          pr_state="${state:-UNKNOWN}"
          review_state="${review_decision:-UNKNOWN}"

          if [[ -n "$merged_at" ]]; then
            suggested="done"
          elif [[ "$state" == "CLOSED" ]]; then
            suggested="blocked"
          elif [[ "$review_decision" == "CHANGES_REQUESTED" ]]; then
            suggested="blocked"
          else
            suggested="in-progress"
          fi
        fi
      fi
    fi

    output+="| ${task_id} | ${summary_value:-'-'} | ${planned_status:-unknown} | ${pr_display} | ${pr_state} | ${review_state} | ${suggested} |${nl}"
  done < <(parse_issue_tasks_tsv "$body_file")

  [[ "$has_rows" == "1" ]] || die "no task rows found in issue body"

  if [[ ${#errors[@]} -gt 0 ]]; then
    printf '%s\n' "$output"
    local err
    for err in "${errors[@]+"${errors[@]}"}"; do
      echo "error: $err" >&2
    done
    return 1
  fi

  printf '%s\n' "$output"
}

build_review_request_body() {
  local body_file="${1:-}"
  local summary_text="${2:-}"
  local nl=$'\n'

  local output="## Main-Agent Review Request${nl}${nl}"
  output+="- Close gate: provide an approval comment URL, then run close-after-review.${nl}${nl}"
  output+="| Task | Summary | Status | PR |${nl}"
  output+="| --- | --- | --- | --- |${nl}"

  local task_count=0
  local pr_count=0

  while IFS=$'\t' read -r task summary _owner _branch _worktree _execution_mode pr status _notes; do
    task_count=$((task_count + 1))
    local task_id summary_value status_value pr_value
    task_id="$(trim_text "$task")"
    summary_value="$(trim_text "$summary")"
    status_value="$(trim_text "$status")"
    pr_value="$(trim_text "$pr")"

    if ! is_pr_placeholder "$pr_value"; then
      pr_count=$((pr_count + 1))
      pr_value="$(canonical_pr_display "$pr_value")"
    else
      pr_value="TBD"
    fi

    output+="| ${task_id} | ${summary_value:-'-'} | ${status_value} | ${pr_value} |${nl}"
  done < <(parse_issue_tasks_tsv "$body_file")

  [[ "$task_count" -gt 0 ]] || die "issue has no tasks in Task Decomposition"
  [[ "$pr_count" -gt 0 ]] || die "ready-for-review requires at least one non-TBD PR"

  if [[ -n "$summary_text" ]]; then
    output+="${nl}## Main-Agent Notes${nl}${nl}${summary_text}${nl}"
  fi

  printf '%s\n' "$output"
}

compose_close_comment() {
  local approved_url="${1:-}"
  local merged_rows="${2:-}"
  local extra="${3:-}"
  local nl=$'\n'

  local msg="Closed after review approval: ${approved_url}${nl}${nl}"
  msg+="Merged implementation PRs:${nl}${merged_rows}${nl}"
  if [[ -n "$extra" ]]; then
    msg+="${nl}Additional note:${nl}${extra}${nl}"
  fi
  printf '%s\n' "$msg"
}

usage() {
  cat <<'USAGE'
Usage:
  manage_issue_delivery_loop.sh <start|status|ready-for-review|close-after-review> [options]

Subcommands:
  start               Open and bootstrap an issue execution loop
  status              Build a task/PR status snapshot and optionally comment on issue
  ready-for-review    Post main-agent review request and optionally set review labels
  close-after-review  Close issue only after approval URL + merged PR checks

Owner policy:
  - Task Decomposition.Owner must reference subagent ownership.
  - main-agent/codex ownership is rejected for implementation tasks.

Common options:
  --repo <owner/repo> Target repository passed to gh via -R
  --dry-run           Print write operations without mutating GitHub state

start options:
  --title <text>                 Issue title (required)
  --body <text>                  Issue body text
  --body-file <path>             Issue body file
  --use-template                 Force issue-lifecycle built-in template
  --label <name>                 Repeatable label
  --assignee <login>             Repeatable assignee
  --project <title>              Repeatable project title
  --milestone <name>             Milestone title
  --task-spec <path>             Optional TSV for task decomposition comment
  --task-header <text>           Decomposition heading (default: Task Decomposition)
  --no-decompose-comment         Print decomposition only (do not comment)

status options:
  --issue <number>               Issue number (required unless --body-file)
  --body-file <path>             Local issue body markdown for offline snapshot
  --comment                      Post snapshot to issue (default when --issue)
  --no-comment                   Do not post snapshot comment

ready-for-review options:
  --issue <number>               Issue number (required unless --body-file)
  --body-file <path>             Local issue body markdown for offline render
  --summary <text>               Additional reviewer notes
  --summary-file <path>          Additional reviewer notes file
  --label <name>                 Label to add when issue mode (default: needs-review)
  --remove-label <name>          Repeatable labels to remove when issue mode
  --no-label-update              Do not mutate labels
  --comment                      Post review request comment (default when --issue)
  --no-comment                   Do not post review request comment

close-after-review options:
  --issue <number>               Issue number to close (required unless --body-file)
  --body-file <path>             Local issue body markdown for offline gate checks
  --approved-comment-url <url>   Reviewer approval comment URL (required)
  --reason <completed|not planned>
                                Close reason (default: completed)
  --comment <text>               Additional close note
  --comment-file <path>          Additional close note file
  --allow-not-done               Allow closing even when task Status is not done
USAGE
}

subcommand="${1:-}"
if [[ -z "$subcommand" ]]; then
  usage >&2
  exit 1
fi
shift || true

repo_arg=""
dry_run="0"

ensure_issue_lifecycle_script

case "$subcommand" in
  start)
    title=""
    body=""
    body_file=""
    use_template="0"
    milestone=""
    task_spec=""
    task_header="Task Decomposition"
    decompose_comment="1"
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
        --task-spec)
          task_spec="${2:-}"
          shift 2
          ;;
        --task-header)
          task_header="${2:-}"
          shift 2
          ;;
        --no-decompose-comment)
          decompose_comment="0"
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
          die "unknown option for start: $1"
          ;;
      esac
    done

    [[ -n "$title" ]] || die "--title is required for start"
    if [[ -n "$body" && -n "$body_file" ]]; then
      die "use either --body or --body-file, not both"
    fi
    if [[ -n "$body_file" && ! -f "$body_file" ]]; then
      die "body file not found: $body_file"
    fi
    if [[ -n "$task_spec" && ! -f "$task_spec" ]]; then
      die "task spec not found: $task_spec"
    fi

    if [[ -n "$body" ]]; then
      temp_start_body="$(mktemp)"
      printf '%s\n' "$body" >"$temp_start_body"
      enforce_subagent_owner_policy "$temp_start_body" "start-body"
      rm -f "$temp_start_body"
    elif [[ -n "$body_file" ]]; then
      enforce_subagent_owner_policy "$body_file" "start-body-file"
    fi

    local_open_args=(open --title "$title")
    if [[ -n "$body" ]]; then
      local_open_args+=(--body "$body")
    elif [[ -n "$body_file" ]]; then
      local_open_args+=(--body-file "$body_file")
    elif [[ "$use_template" == "1" ]]; then
      local_open_args+=(--use-template)
    fi
    if [[ -n "$milestone" ]]; then
      local_open_args+=(--milestone "$milestone")
    fi

    item=''
    for item in "${labels[@]+"${labels[@]}"}"; do
      local_open_args+=(--label "$item")
    done
    for item in "${assignees[@]+"${assignees[@]}"}"; do
      local_open_args+=(--assignee "$item")
    done
    for item in "${projects[@]+"${projects[@]}"}"; do
      local_open_args+=(--project "$item")
    done

    issue_url="$(run_issue_lifecycle "${local_open_args[@]}")"
    issue_number=""
    if ! issue_number="$(extract_issue_number_from_url "$issue_url")"; then
      die "failed to parse issue number from URL: $issue_url"
    fi

    if [[ -n "$task_spec" ]]; then
      decompose_args=(decompose --issue "$issue_number" --spec "$task_spec" --header "$task_header")
      if [[ "$decompose_comment" == "1" ]]; then
        decompose_args+=(--comment)
      fi
      run_issue_lifecycle "${decompose_args[@]}" >/dev/null
    fi

    if [[ "$dry_run" != "1" && "$issue_number" != "999" ]]; then
      run_issue_lifecycle validate --issue "$issue_number" >/dev/null
    fi

    printf 'ISSUE_URL=%s\n' "$issue_url"
    printf 'ISSUE_NUMBER=%s\n' "$issue_number"
    printf 'TASK_SPEC_APPLIED=%s\n' "$( [[ -n "$task_spec" ]] && echo 1 || echo 0 )"
    ;;

  status)
    issue_number=""
    body_file=""
    post_comment=""

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
        --comment)
          post_comment="1"
          shift
          ;;
        --no-comment)
          post_comment="0"
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
          die "unknown option for status: $1"
          ;;
      esac
    done

    if [[ -n "$issue_number" && -n "$body_file" ]]; then
      die "use either --issue or --body-file, not both"
    fi
    if [[ -z "$issue_number" && -z "$body_file" ]]; then
      die "status requires --issue or --body-file"
    fi

    source_label="body-file"
    source_ref="$body_file"
    temp_body=""
    if [[ -n "$issue_number" ]]; then
      source_label="issue"
      source_ref="#${issue_number}"
      if [[ -z "$post_comment" ]]; then
        post_comment="1"
      fi
      run_issue_lifecycle validate --issue "$issue_number" >/dev/null
      temp_body="$(mktemp)"
      issue_read_cmd "$issue_number" "$temp_body"
      body_file="$temp_body"
    else
      [[ -f "$body_file" ]] || die "body file not found: $body_file"
      if [[ -z "$post_comment" ]]; then
        post_comment="0"
      fi
      run_issue_lifecycle validate --body-file "$body_file" >/dev/null
    fi

    enforce_subagent_owner_policy "$body_file" "status ${source_label}:${source_ref}"

    snapshot="$(build_status_snapshot "$body_file")"
    printf '%s\n' "$snapshot"

    if [[ -n "$temp_body" ]]; then
      rm -f "$temp_body"
    fi

    if [[ "$post_comment" == "1" ]]; then
      [[ -n "$issue_number" ]] || die "--comment requires --issue"
      run_issue_lifecycle comment --issue "$issue_number" --body "$snapshot" >/dev/null
    fi
    ;;

  ready-for-review)
    issue_number=""
    body_file=""
    summary_text=""
    summary_file=""
    review_label="needs-review"
    label_update="1"
    post_comment=""
    remove_labels=()

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
        --summary)
          summary_text="${2:-}"
          shift 2
          ;;
        --summary-file)
          summary_file="${2:-}"
          shift 2
          ;;
        --label)
          review_label="${2:-}"
          shift 2
          ;;
        --remove-label)
          remove_labels+=("${2:-}")
          shift 2
          ;;
        --no-label-update)
          label_update="0"
          shift
          ;;
        --comment)
          post_comment="1"
          shift
          ;;
        --no-comment)
          post_comment="0"
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
          die "unknown option for ready-for-review: $1"
          ;;
      esac
    done

    if [[ -n "$issue_number" && -n "$body_file" ]]; then
      die "use either --issue or --body-file, not both"
    fi
    if [[ -z "$issue_number" && -z "$body_file" ]]; then
      die "ready-for-review requires --issue or --body-file"
    fi
    if [[ -n "$summary_text" && -n "$summary_file" ]]; then
      die "use either --summary or --summary-file, not both"
    fi
    if [[ -n "$summary_file" ]]; then
      [[ -f "$summary_file" ]] || die "summary file not found: $summary_file"
      summary_text="$(cat "$summary_file")"
    fi

    issue_ref="local-body"
    temp_body=""
    if [[ -n "$issue_number" ]]; then
      issue_ref="#${issue_number}"
      if [[ -z "$post_comment" ]]; then
        post_comment="1"
      fi
      run_issue_lifecycle validate --issue "$issue_number" >/dev/null
      temp_body="$(mktemp)"
      issue_read_cmd "$issue_number" "$temp_body"
      body_file="$temp_body"
    else
      [[ -f "$body_file" ]] || die "body file not found: $body_file"
      if [[ -z "$post_comment" ]]; then
        post_comment="0"
      fi
      run_issue_lifecycle validate --body-file "$body_file" >/dev/null
    fi

    enforce_subagent_owner_policy "$body_file" "ready-for-review ${issue_ref}"

    review_body="$(build_review_request_body "$body_file" "$summary_text")"
    printf '%s\n' "$review_body"

    if [[ -n "$temp_body" ]]; then
      rm -f "$temp_body"
    fi

    if [[ "$post_comment" == "1" ]]; then
      [[ -n "$issue_number" ]] || die "--comment requires --issue"
      run_issue_lifecycle comment --issue "$issue_number" --body "$review_body" >/dev/null
    fi

    if [[ "$label_update" == "1" && -n "$issue_number" ]]; then
      update_args=(update --issue "$issue_number")
      if [[ -n "$review_label" ]]; then
        update_args+=(--add-label "$review_label")
      fi
      lbl=''
      for lbl in "${remove_labels[@]+"${remove_labels[@]}"}"; do
        update_args+=(--remove-label "$lbl")
      done
      if [[ ${#update_args[@]} -gt 2 ]]; then
        run_issue_lifecycle "${update_args[@]}" >/dev/null
      fi
    fi
    ;;

  close-after-review)
    issue_number=""
    body_file=""
    approved_comment_url=""
    close_reason="completed"
    close_comment=""
    close_comment_file=""
    allow_not_done="0"
    issue_state=""

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
        --approved-comment-url)
          approved_comment_url="${2:-}"
          shift 2
          ;;
        --reason)
          close_reason="${2:-}"
          shift 2
          ;;
        --comment)
          close_comment="${2:-}"
          shift 2
          ;;
        --comment-file)
          close_comment_file="${2:-}"
          shift 2
          ;;
        --allow-not-done)
          allow_not_done="1"
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
          die "unknown option for close-after-review: $1"
          ;;
      esac
    done

    if [[ -n "$issue_number" && -n "$body_file" ]]; then
      die "use either --issue or --body-file, not both"
    fi
    if [[ -z "$issue_number" && -z "$body_file" ]]; then
      die "close-after-review requires --issue or --body-file"
    fi
    [[ -n "$approved_comment_url" ]] || die "--approved-comment-url is required"
    if [[ "$close_reason" != "completed" && "$close_reason" != "not planned" ]]; then
      die "--reason must be one of: completed, not planned"
    fi
    if [[ -n "$close_comment" && -n "$close_comment_file" ]]; then
      die "use either --comment or --comment-file, not both"
    fi
    if [[ -n "$close_comment_file" ]]; then
      [[ -f "$close_comment_file" ]] || die "comment file not found: $close_comment_file"
      close_comment="$(cat "$close_comment_file")"
    fi

    approval_meta="$(validate_approval_comment_url "$approved_comment_url")"
    IFS=$'\t' read -r approval_owner approval_repo _ _ approval_comment_id <<<"$approval_meta"

    if [[ -n "$repo_arg" ]]; then
      if [[ "$repo_arg" != "${approval_owner}/${approval_repo}" ]]; then
        die "approved comment URL repo (${approval_owner}/${approval_repo}) does not match --repo ${repo_arg}"
      fi
    fi

    if [[ "$dry_run" != "1" ]]; then
      require_cmd gh
      gh api "repos/${approval_owner}/${approval_repo}/issues/comments/${approval_comment_id}" >/dev/null
    fi

    temp_body=""
    if [[ -n "$issue_number" ]]; then
      # Re-normalize the issue body before the final gate so main-agent closes against
      # the latest corrected Task Decomposition shape (including legacy section cleanup).
      run_issue_lifecycle sync --issue "$issue_number" >/dev/null
      run_issue_lifecycle validate --issue "$issue_number" >/dev/null
      temp_body="$(mktemp)"
      issue_read_cmd "$issue_number" "$temp_body"
      body_file="$temp_body"
    else
      [[ -f "$body_file" ]] || die "body file not found: $body_file"
      run_issue_lifecycle validate --body-file "$body_file" >/dev/null
    fi

    enforce_subagent_owner_policy "$body_file" "close-after-review"

    merged_rows=""
    gate_errors=()
    nl=$'\n'
    pr_refs=()
    pr_tasks=()

    while IFS=$'\t' read -r task _summary _owner _branch _worktree _execution_mode pr status _notes; do
      task_id="$(trim_text "$task")"
      pr_value="$(trim_text "$pr")"
      status_value="$(to_lower "$status")"

      if [[ "$allow_not_done" != "1" && "$status_value" != "done" ]]; then
        gate_errors+=("${task_id}: Status must be done before close (got: ${status})")
      fi
      if is_pr_placeholder "$pr_value"; then
        gate_errors+=("${task_id}: PR must not be TBD before close")
        continue
      fi

      pr_ref="$(normalize_pr_ref "$pr_value")"
      pr_index='-1'
      for i in "${!pr_refs[@]}"; do
        if [[ "${pr_refs[$i]}" == "$pr_ref" ]]; then
          pr_index="$i"
          break
        fi
      done
      if [[ "$pr_index" == '-1' ]]; then
        pr_refs+=("$pr_ref")
        pr_tasks+=("$task_id")
      else
        pr_tasks[$pr_index]+=", ${task_id}"
      fi
    done < <(parse_issue_tasks_tsv "$body_file")

    for i in "${!pr_refs[@]}"; do
      pr_ref="${pr_refs[$i]}"
      task_list="${pr_tasks[$i]}"

      if [[ "$dry_run" == "1" && -z "$issue_number" ]]; then
        merged_rows+="- ${pr_ref} (tasks: ${task_list}; merge check skipped in dry-run body-file mode)${nl}"
        continue
      fi

      set +e
      pr_meta="$(fetch_pr_meta_tsv "$pr_ref" 2>&1)"
      pr_meta_code=$?
      set -e
      if [[ "$pr_meta_code" -ne 0 ]]; then
        pr_meta="${pr_meta//$'\n'/ }"
        gate_errors+=("Tasks [${task_list}]: failed to query PR ${pr_ref}: ${pr_meta}")
        continue
      fi

      IFS=$'\t' read -r _pr_number pr_url pr_state _is_draft _review_decision _merge_state merged_at <<<"$pr_meta"
      if [[ -z "$merged_at" ]]; then
        gate_errors+=("Tasks [${task_list}]: PR is not merged (${pr_url:-$pr_ref}, state=${pr_state})")
      else
        merged_rows+="- ${pr_url:-$pr_ref} (tasks: ${task_list})${nl}"
      fi
    done

    if [[ -n "$temp_body" ]]; then
      rm -f "$temp_body"
    fi

    if [[ ${#gate_errors[@]} -gt 0 ]]; then
      for err in "${gate_errors[@]+"${gate_errors[@]}"}"; do
        echo "error: $err" >&2
      done
      exit 1
    fi

    final_close_comment="$(compose_close_comment "$approved_comment_url" "$merged_rows" "$close_comment")"
    printf '%s\n' "$final_close_comment"

    if [[ -n "$issue_number" ]]; then
      run_issue_lifecycle close --issue "$issue_number" --reason "$close_reason" --comment "$final_close_comment" >/dev/null
      if [[ "$dry_run" == "1" ]]; then
        printf 'ISSUE_CLOSE_STATUS=DRY_RUN\n'
      else
        issue_state="$(fetch_issue_state "$issue_number")"
        if [[ "$issue_state" != "CLOSED" ]]; then
          die "close-after-review did not close issue #${issue_number} (state=${issue_state})"
        fi
        printf 'ISSUE_CLOSE_STATUS=SUCCESS\n'
        printf 'ISSUE_NUMBER=%s\n' "$issue_number"
        printf 'ISSUE_STATE=%s\n' "$issue_state"
        printf 'DONE_CRITERIA=ISSUE_CLOSED\n'
      fi
    else
      echo "DRY-RUN-CLOSE-SKIPPED"
      printf 'ISSUE_CLOSE_STATUS=DRY_RUN\n'
    fi
    ;;

  -h|--help)
    usage
    ;;

  *)
    die "unknown subcommand: $subcommand"
    ;;
esac
