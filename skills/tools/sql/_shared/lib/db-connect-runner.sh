#!/usr/bin/env bash
set -euo pipefail

sql_skill_repo_root() {
  local start_dir="${1-}"
  if [[ -z "$start_dir" ]]; then
    return 1
  fi

  local root=''
  root="$(git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$root" && -d "$root" ]]; then
    printf '%s\n' "$root"
    return 0
  fi

  if [[ -n "${CODEX_HOME-}" && -d "${CODEX_HOME}/skills/tools/sql" ]]; then
    printf '%s\n' "${CODEX_HOME}"
    return 0
  fi

  local dir=''
  dir="$(cd "$start_dir" && pwd -P)"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -d "$dir/skills/tools/sql" && -d "$dir/skills" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}

sql_skill_require_prefix() {
  local prefix="${1-}"
  if [[ -z "$prefix" ]]; then
    echo "error: missing --prefix" >&2
    return 2
  fi
  if [[ ! "$prefix" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "error: invalid prefix: $prefix" >&2
    return 2
  fi
}

sql_skill_source_env_file() {
  local env_file="${1-}"
  [[ -n "$env_file" ]] || return 1

  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

sql_skill_require_env_var() {
  local env_file="${1-}"
  local name="${2-}"

  local value="${!name-}"
  if [[ -z "$value" ]]; then
    echo "Missing ${name}. Check: ${env_file}" >&2
    return 1
  fi
  printf '%s' "$value"
}

sql_skill_path_maybe_prepend() {
  local bin_dir="${1-}"
  [[ -n "$bin_dir" && -d "$bin_dir" ]] || return 0
  case ":${PATH}:" in
    *":${bin_dir}:"*) ;;
    *) export PATH="${bin_dir}:${PATH}" ;;
  esac
}

sql_skill_maybe_add_brew_prefix_bin() {
  local formula="${1-}"
  [[ -n "$formula" ]] || return 0
  command -v brew >/dev/null 2>&1 || return 0

  local prefix=''
  prefix="$(brew --prefix "$formula" 2>/dev/null || true)"
  [[ -n "$prefix" ]] || return 0
  sql_skill_path_maybe_prepend "${prefix}/bin"
}

sql_skill_ensure_psql() {
  sql_skill_maybe_add_brew_prefix_bin "libpq"
}

sql_skill_ensure_mysql() {
  command -v mysql >/dev/null 2>&1 && return 0
  sql_skill_maybe_add_brew_prefix_bin "mysql-client"
}

sql_skill_ensure_sqlcmd() {
  command -v sqlcmd >/dev/null 2>&1 && return 0
  sql_skill_maybe_add_brew_prefix_bin "mssql-tools18"
}

sql_skill_run_postgres() {
  local prefix="${1-}"
  local env_file="${2-}"
  shift 2 || true

  sql_skill_require_prefix "$prefix" || return $?
  [[ -n "$env_file" ]] || { echo "error: missing --env-file" >&2; return 2; }

  sql_skill_ensure_psql
  sql_skill_source_env_file "$env_file"

  local host port user password database
  host="$(sql_skill_require_env_var "$env_file" "${prefix}_PGHOST")" || return 1
  port="$(sql_skill_require_env_var "$env_file" "${prefix}_PGPORT")" || return 1
  user="$(sql_skill_require_env_var "$env_file" "${prefix}_PGUSER")" || return 1
  password="$(sql_skill_require_env_var "$env_file" "${prefix}_PGPASSWORD")" || return 1
  database="$(sql_skill_require_env_var "$env_file" "${prefix}_PGDATABASE")" || return 1

  PGPASSWORD="$password" psql \
    --host="$host" \
    --port="$port" \
    --username="$user" \
    --dbname="$database" \
    "$@"
}

sql_skill_run_mysql() {
  local prefix="${1-}"
  local env_file="${2-}"
  shift 2 || true

  sql_skill_require_prefix "$prefix" || return $?
  [[ -n "$env_file" ]] || { echo "error: missing --env-file" >&2; return 2; }

  sql_skill_ensure_mysql
  sql_skill_source_env_file "$env_file"

  local host port user password database
  host="$(sql_skill_require_env_var "$env_file" "${prefix}_MYSQL_HOST")" || return 1
  port="$(sql_skill_require_env_var "$env_file" "${prefix}_MYSQL_PORT")" || return 1
  user="$(sql_skill_require_env_var "$env_file" "${prefix}_MYSQL_USER")" || return 1
  password="$(sql_skill_require_env_var "$env_file" "${prefix}_MYSQL_PASSWORD")" || return 1
  database="$(sql_skill_require_env_var "$env_file" "${prefix}_MYSQL_DB")" || return 1

  MYSQL_PWD="$password" mysql \
    --protocol=tcp \
    --host="$host" \
    --port="$port" \
    --user="$user" \
    "$database" \
    "$@" \
    -A
}

sql_skill_run_mssql() {
  local prefix="${1-}"
  local env_file="${2-}"
  shift 2 || true

  sql_skill_require_prefix "$prefix" || return $?
  [[ -n "$env_file" ]] || { echo "error: missing --env-file" >&2; return 2; }

  sql_skill_ensure_sqlcmd
  sql_skill_source_env_file "$env_file"

  local host port user password database trust_cert schema
  host="$(sql_skill_require_env_var "$env_file" "${prefix}_MSSQL_HOST")" || return 1
  port="$(sql_skill_require_env_var "$env_file" "${prefix}_MSSQL_PORT")" || return 1
  user="$(sql_skill_require_env_var "$env_file" "${prefix}_MSSQL_USER")" || return 1
  password="$(sql_skill_require_env_var "$env_file" "${prefix}_MSSQL_PASSWORD")" || return 1
  database="$(sql_skill_require_env_var "$env_file" "${prefix}_MSSQL_DB")" || return 1
  local trust_cert_var="${prefix}_MSSQL_TRUST_CERT"
  local schema_var="${prefix}_MSSQL_SCHEMA"
  trust_cert="${!trust_cert_var-}"
  schema="${!schema_var-}"

  local -a base_args=()
  base_args=(
    -S "${host},${port}"
    -U "$user"
    -P "$password"
    -d "$database"
  )

  if [[ -n "$schema" ]]; then
    base_args+=(-v "schema=${schema}")
  fi

  case "${trust_cert,,}" in
    1|true|yes) base_args+=(-C) ;;
  esac

  sqlcmd "${base_args[@]}" "$@"
}
