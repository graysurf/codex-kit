#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="scripts/$SCRIPT_NAME"

# print_usage: Print CLI usage/help.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [-h|--help] [--check|--write]"
  print -r -- ""
  print -r -- "Runs repo-local shell style fixers (check or write)."
  print -r -- ""
  print -r -- "Modes:"
  print -r -- "  --check: Exit 1 if any fixer would change files (default)"
  print -r -- "  --write: Apply changes in-place"
}

# repo_root_from_script: Resolve repo root directory from this script path.
repo_root_from_script() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset script_dir='' root_dir='' git_root=''
  script_dir="${SCRIPT_PATH:h}"
  root_dir="${script_dir:h}"

  if command -v git >/dev/null 2>&1; then
    git_root="$(command git -C "$root_dir" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$git_root" ]]; then
      print -r -- "$git_root"
      return 0
    fi
  fi

  print -r -- "$root_dir"
}

# main [args...]
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  zparseopts -D -E -A opts -- h -help -check -write || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset mode='check'
  if (( ${+opts[--write]} )); then
    mode='write'
  elif (( ${+opts[--check]} )); then
    mode='check'
  fi

  typeset root_dir=''
  root_dir="$(repo_root_from_script)"
  builtin cd "$root_dir" || return 1

  typeset quotes_fixer="$root_dir/scripts/fix-typeset-empty-string-quotes.zsh"
  typeset init_fixer="$root_dir/scripts/fix-zsh-typeset-initializers.zsh"

  [[ -x "$quotes_fixer" ]] || { print -u2 -r -- "error: missing fixer: $quotes_fixer"; return 2 }
  [[ -x "$init_fixer" ]] || { print -u2 -r -- "error: missing fixer: $init_fixer"; return 2 }

  typeset rc=0
  if [[ "$mode" == "write" ]]; then
    if ! "$quotes_fixer" --write; then
      rc=1
    fi
    if ! "$init_fixer" --write; then
      rc=1
    fi
    return "$rc"
  fi

  if ! "$quotes_fixer" --check; then
    rc=1
  fi
  if ! "$init_fixer" --check; then
    rc=1
  fi

  return "$rc"
}

main "$@"

