#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create-plan-issue-sprint-pr.sh --dispatch-record <path> --issue <number> \
    --summary <text> --scope <text> --testing <text> [options]

Options:
  --summary <text>        Summary bullet. Repeatable.
  --scope <text>          Scope bullet. Repeatable.
  --testing <text>        Testing bullet. Repeatable.
  --task-ids <id>         Extra task ID. Repeatable.
  --repo-slug <owner/repo>
  --title <text>
  --body-only             Render body to stdout and do not call gh.
  --body-out <path>       Write rendered body to a path.
  --ready                 Run gh pr ready after draft creation.
  --help
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_root="$(cd "${script_dir}/.." && pwd -P)"
renderer="${skill_root}/assets/render_pr_body.py"

dispatch_record=''
issue_number=''
repo_slug=''
title=''
body_only=0
ready=0
body_out=''
declare -a summary_args=()
declare -a scope_args=()
declare -a testing_args=()
declare -a task_id_args=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --dispatch-record)
      dispatch_record="${2:-}"
      shift 2
      ;;
    --issue)
      issue_number="${2:-}"
      shift 2
      ;;
    --summary)
      summary_args+=(--summary "${2:-}")
      shift 2
      ;;
    --scope)
      scope_args+=(--scope "${2:-}")
      shift 2
      ;;
    --testing)
      testing_args+=(--testing "${2:-}")
      shift 2
      ;;
    --task-ids)
      task_id_args+=(--task-ids "${2:-}")
      shift 2
      ;;
    --repo-slug)
      repo_slug="${2:-}"
      shift 2
      ;;
    --title)
      title="${2:-}"
      shift 2
      ;;
    --body-only)
      body_only=1
      shift
      ;;
    --body-out)
      body_out="${2:-}"
      shift 2
      ;;
    --ready)
      ready=1
      shift
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$dispatch_record" || -z "$issue_number" ]]; then
  echo "error: --dispatch-record and --issue are required" >&2
  usage >&2
  exit 2
fi

if [[ ${#summary_args[@]} -eq 0 || ${#scope_args[@]} -eq 0 || ${#testing_args[@]} -eq 0 ]]; then
  echo "error: at least one --summary, --scope, and --testing are required" >&2
  usage >&2
  exit 2
fi

declare -a render_args=(--dispatch-record "$dispatch_record" --issue "$issue_number" --print-title)
render_args+=("${summary_args[@]}")
render_args+=("${scope_args[@]}")
render_args+=("${testing_args[@]}")
if [[ ${#task_id_args[@]} -gt 0 ]]; then
  render_args+=("${task_id_args[@]}")
fi
if [[ -n "$repo_slug" ]]; then
  render_args+=(--repo-slug "$repo_slug")
fi
if [[ -n "$title" ]]; then
  render_args+=(--title "$title")
fi

rendered="$(python3 "$renderer" "${render_args[@]}")"
title_line="${rendered%%$'\n---title-end---'$'\n'*}"
body="${rendered#*$'\n---title-end---'$'\n'}"

if [[ -n "$body_out" ]]; then
  mkdir -p "$(dirname "$body_out")"
  printf '%s' "$body" >"$body_out"
fi

if [[ "$body_only" -eq 1 ]]; then
  printf '%s' "$body"
  exit 0
fi

dispatch_json="$(python3 "$renderer" --dispatch-record "$dispatch_record" --print-dispatch)"
worktree="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"])' <<<"$dispatch_json")"
branch="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["branch"])' <<<"$dispatch_json")"
base_branch="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["base_branch"])' <<<"$dispatch_json")"

if [[ ! -d "$worktree" ]]; then
  echo "error: dispatch worktree does not exist: $worktree" >&2
  exit 1
fi

top_level="$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ "$top_level" != "$worktree" ]]; then
  echo "error: dispatch worktree is not the git top-level: $worktree" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh auth status failed" >&2
  exit 1
fi

body_file="$body_out"
if [[ -z "$body_file" ]]; then
  out_root="${AGENT_HOME:-$(pwd -P)}/out/plan-issue-sprint-pr"
  mkdir -p "$out_root"
  body_file="${out_root}/issue-${issue_number}-$(basename "$dispatch_record" .json).md"
  printf '%s' "$body" >"$body_file"
fi

(
  cd "$worktree"
  gh pr create --draft --base "$base_branch" --head "$branch" --title "$title_line" --body-file "$body_file"
)

if [[ -n "$repo_slug" ]]; then
  pr_number="$(gh -R "$repo_slug" pr view "$branch" --json number --jq .number)"
else
  pr_number="$(cd "$worktree" && gh pr view "$branch" --json number --jq .number)"
fi
if [[ "$ready" -eq 1 ]]; then
  if [[ -n "$repo_slug" ]]; then
    gh -R "$repo_slug" pr ready "$pr_number" >/dev/null
  else
    (cd "$worktree" && gh pr ready "$pr_number" >/dev/null)
  fi
fi
if [[ -n "$repo_slug" ]]; then
  gh -R "$repo_slug" pr view "$pr_number" --json url --jq .url
else
  (cd "$worktree" && gh pr view "$pr_number" --json url --jq .url)
fi
