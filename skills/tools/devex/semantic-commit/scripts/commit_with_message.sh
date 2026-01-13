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

load_codex_tools() {
  if [[ -z "${CODEX_HOME:-}" ]]; then
    local script_dir repo_root
    script_dir="${${(%):-%x}:A:h}"
    repo_root="$(cd "${script_dir}/../../.." && pwd -P)"
    export CODEX_HOME="$repo_root"
  fi

  local loader="${CODEX_HOME%/}/scripts/codex-tools.sh"
  if [[ ! -f "$loader" ]]; then
    echo "error: codex tools loader not found: $loader" >&2
    echo "hint: set CODEX_HOME to your codex-kit path (repo root) or reinstall codex-kit" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$loader"
}

load_codex_tools

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

if command git commit -F "$tmpfile" >/dev/null; then
  :
else
  rc=$?
  echo "error: git commit failed (exit code: $rc)" >&2
  exit "$rc"
fi

if ! git-scope commit HEAD --no-color; then
  echo "warning: git-scope commit failed; falling back to git show --stat" >&2
  command git show --no-color --stat HEAD
fi
