#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
default_pr_template="${skill_dir}/references/PR_BODY_TEMPLATE.md"

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
  manage_issue_subagent_pr.sh <create-worktree|open-pr|respond-review> [options]

Subcommands:
  create-worktree  Create a dedicated worktree/branch for subagent implementation
  open-pr          Open a draft PR for an issue branch and sync PR URL back to issue
  respond-review   Post a PR follow-up comment referencing a main-agent review comment link

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

    if [[ -n "$body" && -n "$body_file" ]]; then
      die "use either --body or --body-file, not both"
    fi

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
    elif [[ -n "$body_file" ]]; then
      cmd+=(--body-file "$body_file")
    else
      cmd+=(--body "## Summary\n- Implements #${issue_number}.\n\n## Testing\n- not run (subagent to update)\n")
    fi

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${cmd[@]}"
      pr_url="DRY-RUN-PR-URL"
      if [[ "$comment_issue" == "1" ]]; then
        issue_cmd=(gh issue comment "$issue_number")
        if [[ -n "$repo_arg" ]]; then
          issue_cmd+=(-R "$repo_arg")
        fi
        issue_cmd+=(--body "Subagent opened PR for #${issue_number}: ${pr_url}")
        run_cmd "${issue_cmd[@]}"
      fi
      echo "$pr_url"
      exit 0
    fi

    pr_url="$(run_cmd "${cmd[@]}")"
    if [[ "$comment_issue" == "1" ]]; then
      issue_cmd=(gh issue comment "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        issue_cmd+=(-R "$repo_arg")
      fi
      issue_cmd+=(--body "Subagent opened PR for #${issue_number}: ${pr_url}")
      run_cmd "${issue_cmd[@]}"
    fi

    echo "$pr_url"
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
