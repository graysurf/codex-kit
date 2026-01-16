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
  print -r -- "Rewrite zsh scripts to avoid bare typeset/local declarations that"
  print -r -- "can print existing values to stdout (e.g., when typeset_silent is unset)."
  print -r -- ""
  print -r -- "Fix:"
  print -r -- "  local foo bar        -> local foo='' bar=''"
  print -r -- "  typeset -a items     -> typeset -a items=()"
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
  setopt pipe_fail err_return nounset extendedglob null_glob

  typeset root_dir="$1"

  command -v git >/dev/null 2>&1 || {
    print -u2 -r -- "error: git is required to list targets"
    return 2
  }
  command git -C "$root_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -u2 -r -- "error: not a git work tree: $root_dir"
    return 2
  }

  typeset out=''
  out="$(command git -C "$root_dir" ls-files -z -- 'scripts/**' 'commands/*' 'skills/**/scripts/**')"

  typeset -a candidates=()
  candidates=(${(0)out})
  candidates=("${(@)candidates:#}")

  typeset -a targets=()
  typeset rel='' first_line=''
  for rel in "${candidates[@]}"; do
    [[ -f "$root_dir/$rel" ]] || continue
    first_line="$(command head -n 1 "$root_dir/$rel" 2>/dev/null || true)"
    if [[ "$first_line" == '#!'* && "$first_line" == *zsh* ]]; then
      targets+=("$rel")
    fi
  done

  targets=("${(@on)targets}")
  print -rl -- "${targets[@]}"
}

line_needs_fix() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset line="$1"

  [[ "$line" =~ '^[[:space:]]*(typeset|local)([[:space:]]|$)' ]] || return 1

  typeset -a words=("${(z)line}")
  (( ${#words[@]} > 0 )) || return 1

  typeset cmd="${words[1]}"
  [[ "$cmd" == "typeset" || "$cmd" == "local" ]] || return 1

  typeset -a opts=()
  typeset idx=2
  while (( idx <= ${#words[@]} )); do
    typeset tok="${words[idx]}"
    [[ "$tok" == "#" ]] && break
    if [[ "$tok" == "--" ]]; then
      opts+=("$tok")
      (( idx++ ))
      break
    fi
    if [[ "$tok" == [-+]* ]]; then
      opts+=("$tok")
      (( idx++ ))
      continue
    fi
    break
  done

  typeset opt_flags="${(j::)opts}"
  [[ "$opt_flags" == *f* || "$opt_flags" == *p* ]] && return 1

  typeset tok=''
  typeset i="$idx"
  while (( i <= ${#words[@]} )); do
    tok="${words[i]}"
    [[ "$tok" == "#" ]] && break
    [[ "$tok" == *"="* ]] && { (( i++ )); continue }
    [[ "$tok" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || { (( i++ )); continue }
    return 0
  done

  return 1
}

fix_line() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset line="$1"

  [[ "$line" =~ '^[[:space:]]*(typeset|local)([[:space:]]|$)' ]] || {
    print -r -- "$line"
    return 1
  }

  typeset -a words=("${(z)line}")
  (( ${#words[@]} > 0 )) || {
    print -r -- "$line"
    return 1
  }

  typeset cmd="${words[1]}"
  [[ "$cmd" == "typeset" || "$cmd" == "local" ]] || {
    print -r -- "$line"
    return 1
  }

  typeset -a opts=()
  typeset idx=2
  while (( idx <= ${#words[@]} )); do
    typeset tok="${words[idx]}"
    [[ "$tok" == "#" ]] && break
    if [[ "$tok" == "--" ]]; then
      opts+=("$tok")
      (( idx++ ))
      break
    fi
    if [[ "$tok" == [-+]* ]]; then
      opts+=("$tok")
      (( idx++ ))
      continue
    fi
    break
  done

  typeset opt_flags="${(j::)opts}"
  [[ "$opt_flags" == *f* || "$opt_flags" == *p* ]] && {
    print -r -- "$line"
    return 1
  }

  typeset init="''"
  if [[ "$opt_flags" == *A* || "$opt_flags" == *a* ]]; then
    init="()"
  elif [[ "$opt_flags" == *i* ]]; then
    init="0"
  fi

  typeset changed=false
  typeset -a out_words=("$cmd" "${opts[@]}")

  typeset i="$idx" tok=''
  while (( i <= ${#words[@]} )); do
    tok="${words[i]}"
    if [[ "$tok" == "#" ]]; then
      out_words+=("${words[@]:$(( i - 1 ))}")
      break
    fi

    if [[ "$tok" == *"="* ]]; then
      out_words+=("$tok")
    elif [[ "$tok" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]; then
      out_words+=("${tok}=${init}")
      changed=true
    else
      out_words+=("$tok")
    fi
    (( i++ ))
  done

  if [[ "$changed" == true ]]; then
    typeset indent="${line%%[^[:space:]]*}"
    print -r -- "${indent}${(j: :)out_words}"
    return 0
  fi

  print -r -- "$line"
  return 1
}

# fix_file_in_place <file>
fix_file_in_place() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset file="$1"

  typeset orig_perm=''
  if zmodload zsh/stat >/dev/null 2>&1; then
    typeset -a st=()
    if zstat -A st +mode "$file" >/dev/null 2>&1; then
      orig_perm="$(printf '%o' $(( st[1] & 8#7777 )))"
    fi
  fi

  typeset tmp=''
  tmp="$(mktemp 2>/dev/null || true)"
  if [[ -z "$tmp" ]]; then
    tmp="$(mktemp -t codex-zsh-fix.XXXXXX 2>/dev/null || true)"
  fi
  [[ -n "$tmp" ]] || {
    print -u2 -r -- "error: failed to create temp file"
    return 1
  }

  typeset changed=false
  typeset -a out_lines=()
  typeset line='' fixed=''

  while IFS= read -r line || [[ -n "$line" ]]; do
    fixed="$(fix_line "$line" || true)"
    if [[ "$fixed" != "$line" ]]; then
      changed=true
    fi
    out_lines+=("$fixed")
  done <"$file"

  if [[ "$changed" != true ]]; then
    rm -f -- "$tmp" >/dev/null 2>&1 || true
    return 0
  fi

  print -rl -- "${out_lines[@]}" >"$tmp" || {
    rm -f -- "$tmp" >/dev/null 2>&1 || true
    return 1
  }
  if [[ -n "$orig_perm" ]]; then
    command chmod "$orig_perm" "$tmp" >/dev/null 2>&1 || {
      rm -f -- "$tmp" >/dev/null 2>&1 || true
      return 1
    }
  fi
  command mv -f -- "$tmp" "$file" || {
    rm -f -- "$tmp" >/dev/null 2>&1 || true
    return 1
  }
  if [[ -n "$orig_perm" ]]; then
    command chmod "$orig_perm" "$file" >/dev/null 2>&1 || return 1
  fi
  return 0
}

# file_needs_fix <file>
file_needs_fix() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset file="$1"
  typeset line=''
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_needs_fix "$line" && return 0
  done <"$file"
  return 1
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

  print -u2 -r -- "files with bare typeset/local declarations (missing initializers):"
  print -u2 -rl -- "${changed[@]}"

  [[ "$mode" == 'check' ]] && return 1
  return 0
}

main "$@"
