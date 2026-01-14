#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="$SCRIPT_NAME"

print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [--repo <path>] [--changelog <path>] [--check] [--no-skip-template] [-h|--help]"
  print -r --
  print -r -- "Purpose:"
  print -r -- "  Audit CHANGELOG.md formatting and placeholder cleanup for the release-workflow fallback."
  print -r --
  print -r -- "Checks (when not skipped):"
  print -r -- "  - Header format (blank lines + standard intro line)"
  print -r -- "  - Version headings like: ## vX.Y.Z - YYYY-MM-DD (and blank line / separator after)"
  print -r -- "  - No placeholder leftovers: vX.Y.Z, YYYY-MM-DD, '- ...', '...'"
  print -r -- "  - No HTML comment scaffolding lines (<!-- ... -->)"
  print -r --
  print -r -- "Skip behavior:"
  print -r -- "  - By default, skips when the repo provides its own template (e.g. docs/templates/RELEASE_TEMPLATE.md)."
  print -r -- "  - Use --no-skip-template to force auditing anyway."
  print -r --
  print -r -- "Exit:"
  print -r -- "  - 0: ok / skipped (or warnings when not using --check)"
  print -r -- "  - 1: issues found (only when using --check)"
  print -r -- "  - 2: usage error"
  print -r --
  print -r -- "Expected header format:"
  print -r --
  print -r -- "  # Changelog"
  print -r -- ""
  print -r -- "  All notable changes to this project will be documented in this file."
  print -r -- ""
  print -r -- "  ## v1.0.0 - 2026-01-13"
}

detect_repo_template() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset -a candidates=(
    "docs/templates/RELEASE_TEMPLATE.md"
    "docs/templates/CHANGELOG_TEMPLATE.md"
    "docs/templates/CHANGELOG.md"
  )

  typeset path=''
  for path in "${candidates[@]}"; do
    if [[ -f "$path" ]]; then
      print -r -- "$path"
      return 0
    fi
  done

  return 1
}

is_separator_line() {
  emulate -L zsh
  setopt nounset

  typeset line="$1"
  [[ "$line" =~ '^[[:space:]]*-{10,}[[:space:]]*$' ]]
}

audit_changelog_file() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset changelog="$1"
  typeset want_check="$2"
  typeset -i problems=0

  typeset preface='All notable changes to this project will be documented in this file.'

  if [[ ! -f "$changelog" ]]; then
    print -u2 -r -- "fail: changelog not found: $changelog"
    return 1
  fi

  typeset -a lines=()
  lines=("${(@f)$(<"$changelog")}")
  lines=("${(@)lines//$'\r'/}")

  report_problem() {
    emulate -L zsh
    setopt nounset

    typeset msg="$1"
    if (( want_check )); then
      print -u2 -r -- "fail: $msg"
    else
      print -u2 -r -- "warn: $msg"
    fi
    (( ++problems ))
  }

  if (( ${#lines[@]} == 0 )); then
    report_problem "changelog is empty: $changelog"
  else
    if [[ "${lines[1]-}" != "# Changelog" ]]; then
      report_problem "expected first line '# Changelog' (found: ${lines[1]-<missing>})"
    fi

    if [[ "${lines[2]-}" != "" ]]; then
      report_problem "expected blank line after '# Changelog' (line 2)"
    fi

    if [[ "${lines[3]-}" != "$preface" ]]; then
      report_problem "expected standard preface on line 3: $preface"
    fi

    if [[ "${lines[4]-}" != "" ]]; then
      report_problem "expected blank line after preface (line 4)"
    fi
  fi

  typeset -i i=0
  for i in {1..${#lines[@]}}; do
    typeset line="${lines[i]}"

    if is_separator_line "$line"; then
      continue
    fi

    if [[ "$line" == *'<!--'* || "$line" == *'-->'* ]]; then
      report_problem "HTML comment scaffolding detected (remove <!-- ... -->): ${changelog}:${i}"
      continue
    fi

    if [[ "$line" == *'vX.Y.Z'* ]]; then
      report_problem "placeholder 'vX.Y.Z' detected: ${changelog}:${i}"
      continue
    fi

    if [[ "$line" == *'YYYY-MM-DD'* ]]; then
      report_problem "placeholder 'YYYY-MM-DD' detected: ${changelog}:${i}"
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*-[[:space:]]+\.{3}[[:space:]]*$' ]]; then
      report_problem "placeholder list item '- ...' detected: ${changelog}:${i}"
      continue
    fi

    if [[ "$line" =~ '^[[:space:]]*\.{3}[[:space:]]*$' ]]; then
      report_problem "placeholder line '...' detected: ${changelog}:${i}"
      continue
    fi

    if [[ "$line" == '## v'* ]]; then
      if [[ ! "$line" =~ '^## v[0-9]+\.[0-9]+\.[0-9]+ - [0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
        report_problem "unexpected version heading format (expected '## vX.Y.Z - YYYY-MM-DD'): ${changelog}:${i}"
      fi

      typeset next="${lines[i+1]-}"
      if [[ -n "$next" && "$next" != "" ]] && ! is_separator_line "$next"; then
        report_problem "expected blank line (or separator) after version heading: ${changelog}:${i}"
      fi
      continue
    fi

    if [[ "$line" == '### '* ]]; then
      typeset prev="${lines[i-1]-}"
      if [[ -n "$prev" && "$prev" != "" ]] && ! is_separator_line "$prev"; then
        report_problem "expected blank line (or separator) before section heading: ${changelog}:${i}"
      fi
      continue
    fi
  done

  if (( problems == 0 )); then
    print -r -- "ok: changelog audit passed: $changelog"
    return 0
  fi

  if (( want_check )); then
    print -u2 -r -- "fail: changelog audit found ${problems} issue(s): $changelog"
    return 1
  fi

  print -u2 -r -- "warn: changelog audit found ${problems} issue(s): $changelog"
  return 0
}

main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || {
    print -u2 -r -- "❌ zsh/zutil is required for zparseopts."
    return 1
  }

  typeset -A opts=()
  zparseopts -D -E -A opts -- h -help c -check -repo: -changelog: -no-skip-template || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset repo="${opts[--repo]-.}"
  [[ -z "$repo" ]] && repo='.'

  typeset changelog="${opts[--changelog]-CHANGELOG.md}"
  [[ -z "$changelog" ]] && changelog='CHANGELOG.md'

  typeset want_check=0
  (( ${+opts[-c]} || ${+opts[--check]} )) && want_check=1

  typeset skip_if_template=1
  (( ${+opts[--no-skip-template]} )) && skip_if_template=0

  if [[ ! -d "$repo" ]]; then
    print -u2 -r -- "❌ repo not found: $repo"
    return 2
  fi

  cd "$repo" || return 2

  if (( skip_if_template )); then
    typeset template=''
    template="$(detect_repo_template)" || template=''
    if [[ -n "$template" ]]; then
      print -r -- "ok: skip changelog audit (repo template present): $template"
      return 0
    fi
  fi

  audit_changelog_file "$changelog" "$want_check"
}

main "$@"
