if [[ -n ${_codex_projects_db_connect_loaded-} ]]; then
  return 0 2>/dev/null || exit 0
fi
typeset -gr _codex_projects_db_connect_loaded=1

codex_projects_repo_root_from_project_dir() {
  emulate -L zsh
  setopt localoptions nounset

  local project_dir="${1:?}"
  print -r -- "${project_dir:h:h:h}"
}

codex_projects_ensure_codex_home() {
  emulate -L zsh
  setopt localoptions nounset

  local project_dir="${1:?}"
  if [[ -z "${CODEX_HOME:-}" ]]; then
    export CODEX_HOME="$(codex_projects_repo_root_from_project_dir "$project_dir")"
  fi
}

codex_projects_source_db_connect() {
  emulate -L zsh
  setopt localoptions nounset

  local kind="${1:?}" # psql|mysql|mssql

  local fn="codex_${kind}_run"
  if ! typeset -f "$fn" >/dev/null 2>&1; then
    source "${CODEX_HOME%/}/scripts/db-connect/${kind}.zsh"
  fi
}

