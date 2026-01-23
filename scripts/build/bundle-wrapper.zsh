#!/usr/bin/env -S zsh -f
# Bundle a wrapper script into a single standalone command by inlining sources,
# and optionally embedding runtime-executed tools as self-extracting functions.
#
# Supported wrapper manifest patterns:
# - `source ...` / `. ...` (simple, static paths only)
# - `typeset -a sources=(...)` (paths are relative to `$ZSH_SCRIPT_DIR`)
# - `typeset -a exec_sources=(...)` (paths are relative to `$ZDOTDIR`)
#
# Embedded exec tools:
# - Each `exec_sources` entry is embedded as a function named after the basename
#   without `.zsh` (e.g. `tools/open-changed-files.zsh` -> `open-changed-files`).
# - At runtime, calling the function writes the tool to a temp file, executes it,
#   and deletes the temp file (best-effort).
set -euo pipefail

# usage
# Print CLI usage/help.
# Usage: usage
usage() {
  cat <<'USAGE'
Usage:
  bundle-wrapper.zsh --input <wrapper> --output <path> [--entry <fn>]

Notes:
  - Bundles a wrapper script by inlining its sourced files.
  - Optionally embeds runtime-executed tools via `typeset -a exec_sources=(...)`.
  - Only supports simple "source" lines and a "sources=(...)" / "exec_sources=(...)" array pattern.
  - Expects ZDOTDIR-style paths; will set defaults if missing.
USAGE
}

# die <message...>
# Print an error message to stderr and exit 1.
# Usage: die <message...>
die() {
  print -u2 -r -- "error: $*"
  exit 1
}

input=''
output=''
entry=''

while [[ $# -gt 0 ]]; do
  case "${1-}" in
    --input)
      input="${2-}"
      shift 2
      ;;
    --output)
      output="${2-}"
      shift 2
      ;;
    --entry)
      entry="${2-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: ${1-}"
      ;;
  esac
done

[[ -n "$input" ]] || die "--input is required"
[[ -n "$output" ]] || die "--output is required"
[[ -f "$input" ]] || die "input not found: $input"

typeset -g ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
export ZDOTDIR
export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"
export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"
export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"

for var in ZSH_CONFIG_DIR ZSH_BOOTSTRAP_SCRIPT_DIR ZSH_SCRIPT_DIR; do
  if [[ -z "${(P)var-}" ]]; then
    die "missing env: $var"
  fi
done

print -u2 -r -- "bundle: input=$input"
print -u2 -r -- "bundle: output=$output"
print -u2 -r -- "bundle: ZDOTDIR=$ZDOTDIR"
print -u2 -r -- "bundle: ZSH_CONFIG_DIR=$ZSH_CONFIG_DIR"
print -u2 -r -- "bundle: ZSH_BOOTSTRAP_SCRIPT_DIR=$ZSH_BOOTSTRAP_SCRIPT_DIR"
print -u2 -r -- "bundle: ZSH_SCRIPT_DIR=$ZSH_SCRIPT_DIR"

if command grep -q '^# Bundled from:' "$input" 2>/dev/null && command grep -q '^# --- BEGIN ' "$input" 2>/dev/null; then
  print -u2 -r -- "bundle: detected already-bundled input; copying"

  typeset input_label="$input"
  if [[ "$input_label" == "$HOME/"* ]]; then
    input_label='$HOME/'"${input_label#$HOME/}"
  fi

  typeset tmpfile=''
  tmpfile="$(mktemp 2>/dev/null || true)"
  [[ -n "$tmpfile" ]] || die "failed to create temp file"

  typeset replaced=false
  typeset line=''
  {
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$replaced" == false && "$line" == "# Bundled from:"* ]]; then
        print -r -- "# Bundled from: ${input_label}"
        replaced=true
        continue
      fi
      print -r -- "$line"
    done < "$input"
  } >| "$tmpfile"

  mkdir -p -- "${output:h}"
  mv -f -- "$tmpfile" "$output"
  chmod +x "$output"
  exit 0
fi

typeset -a sources_from_array=()
typeset -a sources_explicit=()
typeset -A seen_sources=()

typeset -a exec_sources_from_array=()
typeset -a exec_sources_explicit=()
typeset -A seen_exec_sources=()

# add_source <path>
# Register a source file path (must exist) once.
# Usage: add_source <path>
add_source() {
  local path="$1"
  [[ -z "$path" ]] && return 0
  if [[ ! -f "$path" ]]; then
    die "source file not found: $path"
  fi
  if (( ${+seen_sources[$path]} )); then
    return 0
  fi
  seen_sources[$path]=1
  sources_explicit+=("$path")
}

# add_exec_source <path>
# Register an exec tool file path (must exist) once.
# Usage: add_exec_source <path>
add_exec_source() {
  local path="$1"
  [[ -z "$path" ]] && return 0
  if [[ ! -f "$path" ]]; then
    die "exec source file not found: $path"
  fi
  if (( ${+seen_exec_sources[$path]} )); then
    return 0
  fi
  seen_exec_sources[$path]=1
  exec_sources_explicit+=("$path")
}

# parse_sources_array <file>
# Parse a `typeset -a sources=(...)` block from a wrapper manifest.
# Usage: parse_sources_array <file>
parse_array_entries() {
  local rest="$1"
  local -a tokens=()
  local token=''
  local -i i=1
  local -i in_single=0
  local -i in_double=0
  local ch=''

  while (( i <= ${#rest} )); do
    ch="${rest[i]}"
    if (( in_single )); then
      if [[ "$ch" == "'" ]]; then
        in_single=0
      else
        token+="$ch"
      fi
    elif (( in_double )); then
      if [[ "$ch" == "\"" ]]; then
        in_double=0
      elif [[ "$ch" == "\\" ]]; then
        (( i++ ))
        if (( i <= ${#rest} )); then
          token+="${rest[i]}"
        fi
      else
        token+="$ch"
      fi
    else
      case "$ch" in
        "'")
          in_single=1
          ;;
        "\"")
          in_double=1
          ;;
        [[:space:]])
          if [[ -n "$token" ]]; then
            tokens+=("$token")
            token=""
          fi
          ;;
        "#")
          if [[ -z "$token" ]]; then
            break
          fi
          token+="$ch"
          ;;
        "("|")")
          ;;
        *)
          token+="$ch"
          ;;
      esac
    fi
    (( i++ ))
  done

  [[ -n "$token" ]] && tokens+=("$token")
  if (( ${#tokens[@]} > 0 )); then
    print -rl -- "${tokens[@]}"
  fi
}

parse_sources_array() {
  local file="$1"
  local in_sources=0
  local line='' rest=''
  while IFS= read -r line; do
    rest="$line"
    if (( ! in_sources )); then
      if [[ "$rest" == *"typeset -a sources=("* ]]; then
        in_sources=1
        rest="${rest#*"typeset -a sources=("}"
      else
        continue
      fi
    fi

    if [[ "$rest" == *")"* ]]; then
      rest="${rest%%")"*}"
      in_sources=0
    fi

    local -a entries=()
    local entry=''
    while IFS= read -r entry; do
      entries+=("$entry")
    done < <(parse_array_entries "$rest")
    if (( ${#entries[@]} > 0 )); then
      sources_from_array+=("${entries[@]}")
    fi
  done < "$file"
}

# parse_exec_sources_array <file>
# Parse a `typeset -a exec_sources=(...)` block from a wrapper manifest.
# Usage: parse_exec_sources_array <file>
parse_exec_sources_array() {
  local file="$1"
  local in_sources=0
  local line='' rest=''
  while IFS= read -r line; do
    rest="$line"
    if (( ! in_sources )); then
      if [[ "$rest" == *"typeset -a exec_sources=("* ]]; then
        in_sources=1
        rest="${rest#*"typeset -a exec_sources=("}"
      else
        continue
      fi
    fi

    if [[ "$rest" == *")"* ]]; then
      rest="${rest%%")"*}"
      in_sources=0
    fi

    local -a entries=()
    local entry=''
    while IFS= read -r entry; do
      entries+=("$entry")
    done < <(parse_array_entries "$rest")
    if (( ${#entries[@]} > 0 )); then
      exec_sources_from_array+=("${entries[@]}")
    fi
  done < "$file"
}

# parse_explicit_sources <file>
# Parse explicit `source` / `.` lines from a wrapper manifest.
# Usage: parse_explicit_sources <file>
parse_explicit_sources() {
  local file="$1"
  local line=''
  local dir="${file:h}"
  local -a tokens=()
  while IFS= read -r line; do
    [[ "$line" == *"source "* || "$line" == *". "* ]] || continue
    tokens=(${(z)line})
    [[ ${#tokens[@]} -ge 2 ]] || continue
    if [[ "${tokens[1]}" != "source" && "${tokens[1]}" != "." ]]; then
      continue
    fi

    local raw="${tokens[2]}"
    if [[ "$raw" == *'$('* || "$raw" == *'`'* || "$raw" == *'<('* || "$raw" == *'>('* ]]; then
      die "dynamic source unsupported: $raw"
    fi
    if [[ "$raw" == *'$src'* || "$raw" == *'${src}'* ]]; then
      continue
    fi

    raw="${(Q)raw}"
    local expanded="$raw"
    local var_name='' var_value=''

    while [[ "$expanded" =~ '\$\{([A-Za-z_][A-Za-z0-9_]*)\}' ]]; do
      var_name="${match[1]}"
      (( ${+parameters[$var_name]} )) || die "unbound variable in source path: $var_name"
      var_value="${(P)var_name}"
      expanded="${expanded//$MATCH/$var_value}"
    done

    while [[ "$expanded" =~ '\$([A-Za-z_][A-Za-z0-9_]*)' ]]; do
      var_name="${match[1]}"
      (( ${+parameters[$var_name]} )) || die "unbound variable in source path: $var_name"
      var_value="${(P)var_name}"
      expanded="${expanded//$MATCH/$var_value}"
    done

    expanded="${expanded/#\~/$HOME}"
    if [[ "$expanded" != /* ]]; then
      expanded="${dir%/}/${expanded}"
    fi
    add_source "$expanded"
  done < "$file"
}

parse_sources_array "$input"
parse_exec_sources_array "$input"
parse_explicit_sources "$input"

typeset -a all_sources=("${sources_explicit[@]}")
for src in "${sources_from_array[@]}"; do
  add_source "${ZSH_SCRIPT_DIR%/}/$src"
done
all_sources=("${sources_explicit[@]}")

typeset -a all_exec_sources=("${exec_sources_explicit[@]}")
for src in "${exec_sources_from_array[@]}"; do
  if [[ "$src" == /* ]]; then
    add_exec_source "$src"
  else
    add_exec_source "${ZDOTDIR%/}/$src"
  fi
done
all_exec_sources=("${exec_sources_explicit[@]}")

tmpfile="$(mktemp 2>/dev/null || true)"
[[ -n "$tmpfile" ]] || die "failed to create temp file"
trap '[[ -n "${tmpfile-}" ]] && command rm -f -- "${tmpfile-}" >/dev/null 2>&1 || true' EXIT

{
  local input_label="$input"
  if [[ "$input_label" == "$HOME/"* ]]; then
    input_label='$HOME/'"${input_label#$HOME/}"
  fi

  print -r -- "#!/usr/bin/env -S zsh -f"
  print -r -- "set -e"
  print -r -- ""
  print -r -- "# Bundled from: ${input_label}"
  print -r -- ': "${ZDOTDIR:=$HOME/.config/zsh}"'
  print -r -- "export ZDOTDIR"
  print -r -- 'export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"'
  print -r -- 'export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"'
  print -r -- 'export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"'
  print -r -- ""

  local src='' label=''
  for src in "${all_sources[@]}"; do
    label="$src"
    if [[ "$label" == "$ZSH_SCRIPT_DIR/"* ]]; then
      label="${label#$ZSH_SCRIPT_DIR/}"
    elif [[ "$label" == "$HOME/"* ]]; then
      label='$HOME/'"${label#$HOME/}"
    fi
    print -r -- "# --- BEGIN ${label}"
    cat "$src"
    print -r -- ""
    print -r -- "# --- END ${label}"
    print -r -- ""
  done

	if (( ${#all_exec_sources[@]} > 0 )); then
	  print -r -- "# --- BEGIN embedded exec tools"
	  print -r -- "_bundle_wrapper_exec_tools::run() {"
	  print -r -- "  emulate -L zsh"
	  print -r -- "  setopt pipe_fail err_return nounset local_traps"
	  print -r -- ""
	  print -r -- "  typeset writer_fn=\"\${1-}\" label=\"\${2-}\""
	  print -r -- "  shift 2 || true"
	  print -r -- "  [[ -n \"\$writer_fn\" && -n \"\$label\" ]] || return 2"
	  print -r -- "  typeset tmp=''"
	  print -r -- "  tmp=\"\$(mktemp 2>/dev/null || true)\""
	  print -r -- "  [[ -n \"\$tmp\" ]] || tmp=\"/tmp/bundle-wrapper.\${label}.\$\$.zsh\""
	  print -r -- "  trap '[[ -n \"\${tmp-}\" ]] && command rm -f -- \"\${tmp-}\" >/dev/null 2>&1 || true' EXIT"
	  print -r -- "  if ! typeset -f \"\$writer_fn\" >/dev/null 2>&1; then"
	  print -r -- "    print -u2 -r -- \"❌ missing embedded writer: \$writer_fn\""
	  print -r -- "    return 1"
	  print -r -- "  fi"
	  print -r -- "  \"\$writer_fn\" >| \"\$tmp\""
	  print -r -- "  zsh -f -- \"\$tmp\" \"\$@\""
	  print -r -- "  return \$?"
	  print -r -- "}"
	  print -r -- ""

    local tool_path='' tool_rel='' tool_file='' tool_cmd='' tool_id='' writer_fn='' delim='' suffix=''
    local -i n=0
    for tool_path in "${all_exec_sources[@]}"; do
      tool_rel="$tool_path"
      if [[ "$tool_rel" == "$ZDOTDIR/"* ]]; then
        tool_rel="${tool_rel#$ZDOTDIR/}"
      elif [[ "$tool_rel" == "$HOME/"* ]]; then
        tool_rel='$HOME/'"${tool_rel#$HOME/}"
      fi

      tool_file="${tool_path:t}"
      tool_cmd="${tool_file%.zsh}"
      tool_id="$tool_cmd"
      tool_id="${tool_id//-/_}"
      tool_id="${tool_id//./_}"
      tool_id="${tool_id//[^A-Za-z0-9_]/_}"

      writer_fn="_bundle_wrapper_exec_tools::write_${tool_id}"
      delim="__BUNDLE_WRAPPER_EOF_${tool_id}__"
      if command grep -Fqx -- "$delim" "$tool_path" >/dev/null 2>&1; then
        n=1
        while true; do
          suffix="_$n"
          delim="__BUNDLE_WRAPPER_EOF_${tool_id}${suffix}__"
          command grep -Fqx -- "$delim" "$tool_path" >/dev/null 2>&1 || break
          n=$(( n + 1 ))
        done
      fi

      print -r -- "# embedded: ${tool_rel}"
      print -r -- "${writer_fn}() {"
      print -r -- "  cat <<'${delim}'"
      cat "$tool_path"
      print -r -- "${delim}"
      print -r -- "}"
      print -r -- ""

      print -r -- "${tool_cmd}() {"
      print -r -- "  _bundle_wrapper_exec_tools::run ${writer_fn} ${tool_cmd} \"\$@\""
      print -r -- "}"
      print -r -- ""
    done

    print -r -- "# --- END embedded exec tools"
    print -r -- ""
  fi

  if [[ -n "$entry" ]]; then
    print -r -- "if ! typeset -f ${entry} >/dev/null 2>&1; then"
    print -r -- "  print -u2 -r -- \"❌ missing function: ${entry}\""
    print -r -- "  exit 1"
    print -r -- "fi"
    print -r -- ""
    print -r -- "${entry} \"\$@\""
  fi
} > "$tmpfile"

mkdir -p -- "${output:h}"
mv -f "$tmpfile" "$output"
chmod +x "$output"
