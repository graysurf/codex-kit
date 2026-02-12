#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: render_feature_pr.sh [--pr|--output] [--from-progress-pr] [--progress-url <url>] [--progress-file <path>] [--planning-pr <number>]

--pr                 Output the PR body template
--output             Output the skill output template
--from-progress-pr   Enable progress-derived sections (only with --pr)
--progress-url <url> Full GitHub URL for docs/progress file (requires --from-progress-pr)
--progress-file <p>  Repo-relative docs/progress path; auto-build GitHub URL (requires --from-progress-pr)
--planning-pr <num>  Include "## Planning PR" as "- #<num>" (requires --from-progress-pr)

Notes:
  - `## Progress` and `## Planning PR` are rendered only when --from-progress-pr is set.
  - Never render `None` in PR body optional sections.
USAGE
}

mode=""
from_progress_pr="false"
progress_url=""
progress_file=""
planning_pr=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --pr|--output)
      if [[ -n "$mode" ]]; then
        echo "error: choose exactly one mode" >&2
        usage >&2
        exit 1
      fi
      mode="$1"
      shift
      ;;
    --progress-url)
      if [[ $# -lt 2 ]]; then
        echo "error: --progress-url requires a value" >&2
        usage >&2
        exit 1
      fi
      progress_url="$2"
      shift 2
      ;;
    --progress-file)
      if [[ $# -lt 2 ]]; then
        echo "error: --progress-file requires a value" >&2
        usage >&2
        exit 1
      fi
      progress_file="$2"
      shift 2
      ;;
    --planning-pr)
      if [[ $# -lt 2 ]]; then
        echo "error: --planning-pr requires a value" >&2
        usage >&2
        exit 1
      fi
      planning_pr="$2"
      shift 2
      ;;
    --from-progress-pr)
      from_progress_pr="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$mode" ]]; then
  usage >&2
  exit 1
fi

if [[ "$mode" == "--output" ]] && ([[ "$from_progress_pr" == "true" ]] || [[ -n "$progress_url" ]] || [[ -n "$progress_file" ]] || [[ -n "$planning_pr" ]]); then
  echo "error: --from-progress-pr/--progress-url/--progress-file/--planning-pr can only be used with --pr" >&2
  usage >&2
  exit 1
fi

github_slug_from_remote() {
  local remote_url="${1:-}"
  case "$remote_url" in
    git@github.com:*.git)
      printf '%s\n' "${remote_url#git@github.com:}" | sed -E 's/\.git$//'
      return 0
      ;;
    git@github.com:*)
      printf '%s\n' "${remote_url#git@github.com:}"
      return 0
      ;;
    https://github.com/*.git)
      printf '%s\n' "${remote_url#https://github.com/}" | sed -E 's/\.git$//'
      return 0
      ;;
    https://github.com/*)
      printf '%s\n' "${remote_url#https://github.com/}"
      return 0
      ;;
    ssh://git@github.com/*.git)
      printf '%s\n' "${remote_url#ssh://git@github.com/}" | sed -E 's/\.git$//'
      return 0
      ;;
    ssh://git@github.com/*)
      printf '%s\n' "${remote_url#ssh://git@github.com/}"
      return 0
      ;;
    *)
      echo "error: unable to parse GitHub slug from origin remote: ${remote_url}" >&2
      return 1
      ;;
  esac
}

resolve_progress_url_from_file() {
  local path="${1:-}"
  local remote_url=''
  local repo_slug=''
  local branch=''

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: --progress-file requires running inside a git repository" >&2
    return 1
  fi

  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$remote_url" ]]; then
    echo "error: cannot resolve origin remote for --progress-file" >&2
    return 1
  fi

  repo_slug="$(github_slug_from_remote "$remote_url")"
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    branch="${GITHUB_HEAD_REF:-}"
  fi
  if [[ -z "$branch" ]] || [[ "$branch" == "HEAD" ]]; then
    branch="$(git for-each-ref --format='%(refname:short)' --points-at HEAD refs/heads refs/remotes/origin 2>/dev/null | sed 's#^origin/##' | awk '$0 != "HEAD" {print; exit}')"
  fi
  if [[ -z "$branch" ]] || [[ "$branch" == "HEAD" ]]; then
    echo "error: cannot resolve current branch for --progress-file" >&2
    return 1
  fi

  printf 'https://github.com/%s/blob/%s/%s\n' "$repo_slug" "$branch" "$path"
}

if [[ "$mode" == "--pr" ]] && [[ "$from_progress_pr" != "true" ]] && ([[ -n "$progress_url" ]] || [[ -n "$progress_file" ]] || [[ -n "$planning_pr" ]]); then
  echo "error: --progress-url/--progress-file/--planning-pr require --from-progress-pr" >&2
  exit 1
fi

if [[ "$mode" == "--pr" ]] && [[ "$from_progress_pr" == "true" ]]; then
  if [[ -z "$planning_pr" ]]; then
    echo "error: --planning-pr is required when --from-progress-pr is set" >&2
    exit 1
  fi
  if [[ -z "$progress_url" ]] && [[ -z "$progress_file" ]]; then
    echo "error: --from-progress-pr requires --progress-url or --progress-file" >&2
    exit 1
  fi
fi

if [[ -n "$progress_url" ]] && [[ ! "$progress_url" =~ ^https://github\.com/[[:graph:]]+$ ]]; then
  echo "error: --progress-url must be a full GitHub URL" >&2
  exit 1
fi

if [[ -n "$progress_file" ]] && [[ ! "$progress_file" =~ ^docs/progress/.+\.md$ ]]; then
  echo "error: --progress-file must be a docs/progress/*.md path" >&2
  exit 1
fi

if [[ -n "$planning_pr" ]]; then
  planning_pr="${planning_pr#\#}"
  if [[ ! "$planning_pr" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: --planning-pr must be a positive PR number" >&2
    exit 1
  fi
fi

if [[ -z "$progress_url" ]] && [[ -n "$progress_file" ]]; then
  progress_url="$(resolve_progress_url_from_file "$progress_file")"
fi

render_optional_sections() {
  if [[ "$from_progress_pr" == "true" ]] && [[ -n "$progress_url" ]]; then
    cat <<EOF
## Progress
- [docs/progress/<YYYYMMDD_feature_slug>.md](${progress_url})

EOF
  fi

  if [[ "$from_progress_pr" == "true" ]] && [[ -n "$planning_pr" ]]; then
    cat <<EOF
## Planning PR
- #${planning_pr}

EOF
  fi
}

render_pr_template() {
  local template=''
  local optional_sections=''
  template="$(cat "${skill_dir}/references/PR_TEMPLATE.md")"
  optional_sections="$(render_optional_sections)"
  printf '%s\n' "${template//'{{OPTIONAL_SECTIONS}}'/$optional_sections}"
}

case "$mode" in
  --pr)
    render_pr_template
    ;;
  --output)
    cat "${skill_dir}/references/ASSISTANT_RESPONSE_TEMPLATE.md"
    ;;
  *)
    echo "error: unknown mode: $mode" >&2
    exit 1
    ;;
esac
