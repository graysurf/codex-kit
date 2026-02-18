#!/usr/bin/env -S zsh -f

[[ -z "${ZSH_VERSION:-}" ]] && return
[[ -n "${CODEX_ENV_LOADED:-}" ]] && return
export CODEX_ENV_LOADED=1

# non-interactive only: reduce color/control sequences for LLM consumption
if [[ ! -o interactive ]]; then
  export NO_COLOR=1
  export CLICOLOR=0
  export CLICOLOR_FORCE=0
  export FORCE_COLOR=0
  export PY_COLORS=0
  export PYTEST_ADDOPTS="${PYTEST_ADDOPTS:+$PYTEST_ADDOPTS }--color=no"
  export GIT_PAGER="${GIT_PAGER:-cat}"

  # Force no-color flags for common CLIs (non-interactive only).
  mypy() {
    emulate -L zsh
    command mypy --no-color-output "$@"
  }
  pytest() {
    emulate -L zsh
    command pytest --color=no "$@"
  }
fi
