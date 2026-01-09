#!/usr/bin/env -S zsh -f

setopt pipe_fail

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"

typeset -gi OCF_DEFAULT_MAX_FILES=5
typeset -gi OCF_GIT_ROOT_MAX_DEPTH=5
typeset -gi OCF_BATCH_SIZE=50
typeset -gi OCF_VERBOSE=0

# print_usage: Print CLI usage/help.
print_usage() {
  emulate -L zsh
  setopt pipe_fail

  print -r -- "Open changed files in VSCode."
  print -r -- ""
  print -r -- "Usage:"
  print -r -- "  $SCRIPT_NAME [--list|--git] [--workspace-mode pwd|git] [--dry-run] [--verbose] [--max-files N] [--] [files...]"
  print -r -- ""
  print -r -- "Modes:"
  print -r -- "  --list  Open explicit file paths (default; stdin fallback when no args)"
  print -r -- "  --git   Open changed files from git (staged + unstaged + untracked)"
  print -r -- ""
  print -r -- "Options:"
  print -r -- "  --dry-run       Print planned 'code ...' invocations (does not execute)"
  print -r -- "  --verbose       Explain no-op behavior and ignored paths (stderr only)"
  print -r -- "  --workspace-mode pwd|git (default: ${OPEN_CHANGED_FILES_WORKSPACE_MODE:-pwd})"
  print -r -- "  --max-files N   Max files to open (default: ${OPEN_CHANGED_FILES_MAX_FILES:-$OCF_DEFAULT_MAX_FILES})"
  print -r -- "  -h, --help      Show this help"
  print -r -- ""
  print -r -- "Env:"
  print -r -- "  OPEN_CHANGED_FILES_SOURCE=list|git (default: ${OPEN_CHANGED_FILES_SOURCE:-list})"
  print -r -- "  OPEN_CHANGED_FILES_WORKSPACE_MODE=pwd|git (default: ${OPEN_CHANGED_FILES_WORKSPACE_MODE:-pwd})"
  print -r -- "  OPEN_CHANGED_FILES_MAX_FILES=<n>     (default: $OCF_DEFAULT_MAX_FILES)"
}

# _ocf::die_usage: Print an error + usage to stderr and return status 2.
# Usage: _ocf::die_usage [message]
_ocf::die_usage() {
  emulate -L zsh
  setopt pipe_fail

  typeset msg="${1-}"
  [[ -n "$msg" ]] && print -u2 -r -- "❌ $msg"
  print -u2 -r -- ""
  print_usage >&2
  return 2
}

# _ocf::log: Print a message to stderr when `--verbose` is enabled.
# Usage: _ocf::log <msg...>
_ocf::log() {
  emulate -L zsh
  setopt err_return nounset

  (( OCF_VERBOSE )) || return 0
  print -u2 -r -- "$@"
}

# _ocf::resolve_code_path: Resolve a usable VSCode CLI path on macOS/Linux.
# Usage: _ocf::resolve_code_path
# Output:
# - Prints resolved path to stdout on success.
_ocf::resolve_code_path() {
  emulate -L zsh
  setopt err_return nounset

  typeset code_path=''
  if command -v code >/dev/null 2>&1; then
    code_path="$(command -v code)"
    print -r -- "$code_path"
    return 0
  fi

  typeset os="${OSTYPE-}"
  typeset home="${HOME-}"
  typeset -a candidates=()

  if [[ "$os" == darwin* ]]; then
    candidates+=(
      /usr/local/bin/code
      /opt/homebrew/bin/code
      "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
      "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code"
    )
    if [[ -n "$home" ]]; then
      candidates+=(
        "$home/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        "$home/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code"
      )
    fi
  else
    candidates+=(
      /usr/bin/code
      /usr/local/bin/code
      /snap/bin/code
      /var/lib/flatpak/exports/bin/com.visualstudio.code
    )
    if [[ -n "$home" ]]; then
      candidates+=(
        "$home/.local/bin/code"
        "$home/bin/code"
        "$home/.linuxbrew/bin/code"
      )
    fi
  fi

  typeset candidate=''
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    print -r -- "$candidate"
    return 0
  done

  return 1
}

# _ocf::find_git_root_upwards: Find nearest git root within N parent levels.
# Usage: _ocf::find_git_root_upwards <start_dir> [max_depth]
# Output:
# - Prints the git root directory to stdout on success.
_ocf::find_git_root_upwards() {
  emulate -L zsh
  setopt err_return nounset

  typeset dir="${1-}"
  typeset -i max_depth="${2:-$OCF_GIT_ROOT_MAX_DEPTH}"
  [[ -z "$dir" ]] && return 1

  dir="${dir:A}"

  typeset -i depth=0
  while (( depth <= max_depth )); do
    if [[ -e "$dir/.git" ]]; then
      print -r -- "$dir"
      return 0
    fi

    [[ "$dir" == "/" ]] && break
    dir="${dir:h}"
    (( ++depth ))
  done

  return 1
}

# _ocf::collect_list_files: Collect existing file paths from args or stdin.
# Usage: _ocf::collect_list_files [paths...]
# Output:
# - Prints absolute file paths (one per line).
_ocf::collect_list_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a input=("$@")
  if (( ${#input[@]} == 0 )); then
    [[ -t 0 ]] && return 0
    typeset line=''
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      input+=("$line")
    done
  fi

  typeset -A seen=()
  typeset -a out=()

  typeset raw='' abs=''
  for raw in "${input[@]}"; do
    [[ -z "$raw" ]] && continue
    abs="${raw:A}"
    if [[ ! -f "$abs" ]]; then
      _ocf::log "skip: not a file: $abs"
      continue
    fi
    (( ${+seen[$abs]} )) && continue
    seen[$abs]=1
    out+=("$abs")
  done

  (( ${#out[@]} == 0 )) && return 0
  print -rl -- "${out[@]}"
}

# _ocf::collect_git_files: Collect changed files from git (staged + unstaged + untracked).
# Usage: _ocf::collect_git_files
# Output:
# - Prints absolute file paths (one per line).
_ocf::collect_git_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if ! command -v git >/dev/null 2>&1; then
    _ocf::log "no-op: git not found"
    return 0
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _ocf::log "no-op: not inside a git work tree"
    return 0
  fi

  typeset repo_root=''
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  repo_root="${repo_root:A}"

  typeset -a candidates=()
  candidates+=("${(@f)$(git diff --name-only --cached 2>/dev/null)}")
  candidates+=("${(@f)$(git diff --name-only 2>/dev/null)}")
  candidates+=("${(@f)$(git ls-files --others --exclude-standard 2>/dev/null)}")

  typeset -A seen=()
  typeset -a out=()

  typeset rel='' abs=''
  for rel in "${candidates[@]}"; do
    [[ -z "$rel" ]] && continue
    abs="${repo_root}/${rel}"
    abs="${abs:A}"
    [[ -f "$abs" ]] || continue
    (( ${+seen[$abs]} )) && continue
    seen[$abs]=1
    out+=("$abs")
  done

  (( ${#out[@]} == 0 )) && return 0
  print -rl -- "${out[@]}"
}

# _ocf::print_code_invocation: Print a shell-quoted `code ...` invocation.
# Usage: _ocf::print_code_invocation <new|reuse|none> <workspace_root> <files...>
_ocf::print_code_invocation() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset window_mode="${1-}"
  shift
  typeset workspace_root="$1"
  shift
  typeset -a files=("$@")

  typeset -a args=()
  typeset code_bin="${OCF_CODE_PATH:-code}"
  args+=("$code_bin")
  if [[ "$window_mode" == "new" ]]; then
    args+=(--new-window)
  elif [[ "$window_mode" == "reuse" ]]; then
    args+=(--reuse-window)
  fi
  args+=(-- "$workspace_root" "${files[@]}")

  print -r -- "${(j: :)${(@q)args}}"
}

# _ocf::run_code_invocation: Invoke VSCode CLI; silent no-op when `code` is missing.
# Usage: _ocf::run_code_invocation <new|reuse|none> <workspace_root> <files...>
_ocf::run_code_invocation() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset code_bin="${OCF_CODE_PATH-}"
  [[ -z "$code_bin" ]] && return 0

  typeset window_mode="${1-}"
  shift
  typeset workspace_root="$1"
  shift
  typeset -a files=("$@")

  if [[ "$window_mode" == "new" ]]; then
    "$code_bin" --new-window -- "$workspace_root" "${files[@]}"
  elif [[ "$window_mode" == "reuse" ]]; then
    "$code_bin" --reuse-window -- "$workspace_root" "${files[@]}"
  else
    "$code_bin" -- "$workspace_root" "${files[@]}"
  fi
}

# main: CLI entrypoint.
# Usage: main [args...]
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- h -help v -verbose -list -git -dry-run -workspace-mode: -max-files: || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  OCF_VERBOSE=0
  (( ${+opts[-v]} || ${+opts[--verbose]} )) && OCF_VERBOSE=1

  if (( ${+opts[--list]} && ${+opts[--git]} )); then
    _ocf::die_usage "Flags are mutually exclusive: --list and --git"
    return $?
  fi

  typeset mode="${OPEN_CHANGED_FILES_SOURCE:-list}"
  (( ${+opts[--list]} )) && mode='list'
  (( ${+opts[--git]} )) && mode='git'

  if [[ "$mode" != "list" && "$mode" != "git" ]]; then
    _ocf::die_usage "Invalid OPEN_CHANGED_FILES_SOURCE: $mode (expected: list|git)"
    return $?
  fi

  typeset workspace_mode="${OPEN_CHANGED_FILES_WORKSPACE_MODE:-pwd}"
  typeset workspace_raw="${opts[--workspace-mode]-}"
  workspace_raw="${workspace_raw#=}"
  [[ -n "$workspace_raw" ]] && workspace_mode="$workspace_raw"
  if [[ "$workspace_mode" != "pwd" && "$workspace_mode" != "git" ]]; then
    _ocf::die_usage "Invalid workspace mode: $workspace_mode (expected: pwd|git)"
    return $?
  fi

  typeset -i dry_run=0
  (( ${+opts[--dry-run]} )) && dry_run=1

  typeset max_raw="${opts[--max-files]-}"
  max_raw="${max_raw#=}"
  [[ -z "$max_raw" ]] && max_raw="${OPEN_CHANGED_FILES_MAX_FILES:-$OCF_DEFAULT_MAX_FILES}"
  [[ "$max_raw" != <-> ]] && { _ocf::die_usage "Invalid --max-files: $max_raw"; return $?; }
  typeset -i max_files="$max_raw"
  (( max_files < 0 )) && { _ocf::die_usage "--max-files must be >= 0"; return $?; }
  (( max_files == 0 )) && return 0

  OCF_CODE_PATH="$(_ocf::resolve_code_path 2>/dev/null || true)"
  if [[ -z "$OCF_CODE_PATH" ]]; then
    if (( dry_run )); then
      OCF_CODE_PATH='code'
    else
      _ocf::log "no-op: 'code' not found"
      return 0
    fi
  fi

  typeset -a files=()
  if [[ "$mode" == "list" ]]; then
    files=("${(@f)$(_ocf::collect_list_files "$@")}")
  else
    files=("${(@f)$(_ocf::collect_git_files)}")
  fi

  (( ${#files[@]} == 0 )) && return 0
  files=("${files[@]:0:$max_files}")

  typeset pwd_workspace="${PWD:A}"
  typeset -A groups=()
  typeset -a workspace_order=()

  typeset file='' workspace=''
  for file in "${files[@]}"; do
    if [[ "$workspace_mode" == "git" ]]; then
      workspace="$(_ocf::find_git_root_upwards "${file:h}" "$OCF_GIT_ROOT_MAX_DEPTH" || true)"
      [[ -z "$workspace" ]] && workspace="$pwd_workspace"
    else
      workspace="$pwd_workspace"
    fi

    if [[ -z "${groups[$workspace]-}" ]]; then
      groups[$workspace]="$file"
      workspace_order+=("$workspace")
    else
      groups[$workspace]+=$'\n'"$file"
    fi
  done

  typeset -i batch_size="$OCF_BATCH_SIZE"
  typeset -i idx=0
  typeset -a ws_files=() batch=()
  for workspace in "${workspace_order[@]}"; do
    ws_files=("${(@f)${groups[$workspace]}}")
    idx=0
    typeset -i is_first=1
    while (( idx < ${#ws_files[@]} )); do
      batch=("${ws_files[@]:$idx:$batch_size}")
      idx=$(( idx + batch_size ))

      typeset window_mode='new'
      if (( !is_first )); then
        window_mode='reuse'
      fi
      is_first=0

      if (( dry_run )); then
        _ocf::print_code_invocation "$window_mode" "$workspace" "${batch[@]}"
      else
        _ocf::run_code_invocation "$window_mode" "$workspace" "${batch[@]}"
      fi
    done
  done

  return 0
}

main "$@"
