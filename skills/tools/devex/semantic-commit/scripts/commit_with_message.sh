#!/usr/bin/env -S zsh -f
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  commit_with_message.sh [--message <text> | --message-file <path>]

Reads a prepared commit message (prefer stdin for multi-line messages), runs:
  git commit -F <temp-file>
Then prints:
  git-scope commit HEAD --no-color

Examples:
  cat <<'MSG' | commit_with_message.sh
  feat(core): add thing

  - Add thing
  MSG

  commit_with_message.sh --message-file ./message.txt
USAGE
}

message=""
message_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message)
      if [[ $# -lt 2 ]]; then
        echo "error: --message requires a value" >&2
        usage >&2
        exit 1
      fi
      message="$2"
      shift 2
      ;;
    --message-file)
      if [[ $# -lt 2 ]]; then
        echo "error: --message-file requires a path" >&2
        usage >&2
        exit 1
      fi
      message_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$message" && -n "$message_file" ]]; then
  echo "error: use only one of --message or --message-file" >&2
  exit 1
fi

if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: must run inside a git work tree" >&2
  exit 1
fi

if command git diff --cached --quiet -- >/dev/null 2>&1; then
  echo "error: no staged changes (stage files with git add first)" >&2
  exit 2
fi

export GIT_PAGER=cat
export PAGER=cat

resolve_codex_command() {
  local name="${1:-}"
  [[ -n "$name" ]] || return 1

  if [[ -z "${CODEX_HOME:-}" ]]; then
    local script_dir='' repo_root=''
    script_dir="${${(%):-%x}:A:h}"
    repo_root="$(cd "${script_dir}/../../../../.." && pwd -P)"
    export CODEX_HOME="$repo_root"
  fi

  local commands_dir="${CODEX_COMMANDS_PATH:-${CODEX_HOME%/}/commands}"
  local candidate="${commands_dir%/}/${name}"
  [[ -x "$candidate" ]] || return 1

  print -r -- "$candidate"
}

fail_validation() {
  local message="${1:-}"
  if [[ -n "$message" ]]; then
    echo "error: $message" >&2
  else
    echo "error: commit message validation failed" >&2
  fi
  exit 1
}

validate_commit_message() {
  local file="$1"
  local -a lines=()
  local line=""
  local header=""
  local header_regex='^[a-z][a-z0-9-]*(\([a-z0-9._-]+\))?: .+$'
  local body_exists=0
  local i=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"

  if (( ${#lines[@]} == 0 )); then
    fail_validation "commit message is empty"
  fi

  header="${lines[1]}"
  if [[ -z "$header" ]]; then
    fail_validation "commit header is empty"
  fi
  if (( ${#header} > 100 )); then
    fail_validation "commit header exceeds 100 characters (max 100)"
  fi
  if [[ ! "$header" =~ $header_regex ]]; then
    fail_validation "invalid header format (expected 'type(scope): subject' or 'type: subject' with lowercase type)"
  fi

  for (( i=2; i<=${#lines[@]}; i++ )); do
    if [[ -n "${lines[$i]}" ]]; then
      body_exists=1
      break
    fi
  done

  if (( body_exists )); then
    if [[ -n "${lines[2]:-}" ]]; then
      fail_validation "commit body must be separated from header by a blank line"
    fi

    for (( i=3; i<=${#lines[@]}; i++ )); do
      line="${lines[$i]}"
      if [[ -z "$line" ]]; then
        fail_validation "commit body line $i is empty; body lines must start with '- ' followed by uppercase letter"
      fi
      if (( ${#line} > 100 )); then
        fail_validation "commit body line $i exceeds 100 characters (max 100)"
      fi
      if [[ ! "$line" =~ "^- [A-Z]" ]]; then
        fail_validation "commit body line $i must start with '- ' followed by uppercase letter"
      fi
    done
  fi
}

tmpfile="$(mktemp 2>/dev/null || true)"
if [[ -z "$tmpfile" ]]; then
  tmpfile="$(mktemp -t codex-commit-msg.XXXXXX 2>/dev/null || true)"
fi
if [[ -z "$tmpfile" ]]; then
  echo "error: failed to create temp file for commit message" >&2
  exit 1
fi

cleanup() {
  rm -f "$tmpfile" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [[ -n "$message_file" ]]; then
  if [[ ! -f "$message_file" ]]; then
    echo "error: message file not found: $message_file" >&2
    exit 1
  fi
  cat "$message_file" >"$tmpfile"
elif [[ -n "$message" ]]; then
  print -r -- "$message" >"$tmpfile"
else
  if [[ -t 0 ]]; then
    echo "error: no commit message provided (use stdin, --message, or --message-file)" >&2
    usage >&2
    exit 1
  fi
  cat >"$tmpfile"
fi

if [[ ! -s "$tmpfile" ]]; then
  echo "error: commit message is empty" >&2
  exit 1
fi

validate_commit_message "$tmpfile"

if command git commit -F "$tmpfile" >/dev/null; then
  :
else
  rc=$?
  echo "error: git commit failed (exit code: $rc)" >&2
  exit "$rc"
fi

git_scope="$(resolve_codex_command git-scope 2>/dev/null || true)"
if [[ -z "$git_scope" ]]; then
  echo "warning: git-scope not found; falling back to git show --stat" >&2
  command git show --no-color --stat HEAD
  exit 0
fi

if ! "$git_scope" commit HEAD --no-color; then
  echo "warning: git-scope commit failed; falling back to git show --stat" >&2
  command git show --no-color --stat HEAD
fi
