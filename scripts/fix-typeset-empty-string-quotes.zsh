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
  print -r -- "Rewrite repo shell scripts to prefer single quotes for empty-string"
  print -r -- "initializers in typeset/local lines (\"\" -> '')."
  print -r -- ""
  print -r -- "Modes:"
  print -r -- "  --check: Print files that would change; exit 1 if any (default)"
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

# targets_from_root: Print target file paths (newline-separated, repo-relative).
targets_from_root() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"

  command -v git >/dev/null 2>&1 || {
    print -u2 -r -- "error: git is required to list targets"
    return 2
  }
  command git -C "$root_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -u2 -r -- "error: not a git work tree: $root_dir"
    return 2
  }

  typeset -a targets=()
  typeset out=''
  out="$(command git -C "$root_dir" ls-files -z -- '*.sh' '*.zsh' 'commands/*')"
  targets=(${(0)out})
  targets=("${(@)targets:#}")
  targets=("${(@on)targets}")
  print -rl -- "${targets[@]}"
}

# file_needs_fix <file>
# Exit 0 when the file contains a typeset/local line with ="". ("local foo=\"\"")
file_needs_fix() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset file="$1"
  perl -ne 'if (/^\s*(?:typeset|local)\b/ && /=\"\"/) { $found=1; last } END { exit($found ? 0 : 1) }' -- "$file"
}

# fix_file_in_place <file>
# Replace ="" with ='' on typeset/local lines.
fix_file_in_place() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset file="$1"
  perl -pi -e 'if (/^\s*(?:typeset|local)\b/) { s/=\"\"/='\'''\''/g }' -- "$file"
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

  typeset -a targets=()
  IFS=$'\n' targets=($(targets_from_root "$root_dir")) || return $?

  typeset -a changed=()
  typeset file=''
  for file in "${targets[@]}"; do
    [[ -f "$file" ]] || continue
    file_needs_fix "$file" || continue
    changed+=("$file")

    if [[ "$mode" == 'write' ]]; then
      fix_file_in_place "$file" || return 1
    fi
  done

  if (( ${#changed[@]} == 0 )); then
    return 0
  fi

  print -u2 -r -- "files with \"typeset/local ...=\\\"\\\"\" (empty string):"
  print -u2 -rl -- "${changed[@]}"

  [[ "$mode" == 'check' ]] && return 1
  return 0
}

main "$@"
