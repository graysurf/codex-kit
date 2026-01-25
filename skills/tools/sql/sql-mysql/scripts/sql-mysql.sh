#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sql-mysql.sh --prefix <PREFIX> --env-file <path> [--query "<sql>" | --file <file.sql> | -- <mysql args...>]

Examples:
  sql-mysql.sh --prefix TEST --env-file /dev/null --query "select 1;"
  sql-mysql.sh --prefix TEST --env-file /dev/null --file ./query.sql
  sql-mysql.sh --prefix TEST --env-file /dev/null -- --execute "select 1;" --table
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
shared_lib="${script_dir}/../../_shared/lib/db-connect-runner.sh"
# shellcheck disable=SC1090
source "$shared_lib"

prefix=""
env_file=""
query=""
file=""
pass_args=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --prefix)
      prefix="${2-}"
      shift 2
      ;;
    --env-file)
      env_file="${2-}"
      shift 2
      ;;
    -q|--query)
      query="${2-}"
      shift 2
      ;;
    --file)
      file="${2-}"
      shift 2
      ;;
    --)
      shift
      pass_args+=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$prefix" ]]; then
  echo "error: --prefix is required" >&2
  usage >&2
  exit 2
fi
if [[ -z "$env_file" ]]; then
  echo "error: --env-file is required (use /dev/null to rely on exported env vars)" >&2
  usage >&2
  exit 2
fi
if [[ -n "$query" && -n "$file" ]]; then
  echo "error: choose only one: --query or --file" >&2
  usage >&2
  exit 2
fi
if [[ -n "$file" && ! -f "$file" ]]; then
  echo "error: missing --file: $file" >&2
  exit 2
fi

client_args=()
stdin_file=""

if [[ -n "$query" ]]; then
  client_args+=(-e "$query")
fi
if [[ -n "$file" ]]; then
  stdin_file="$file"
fi
client_args+=("${pass_args[@]}")

if [[ -n "$stdin_file" ]]; then
  sql_skill_run_mysql "$prefix" "$env_file" "${client_args[@]}" <"$stdin_file"
  exit $?
fi

sql_skill_run_mysql "$prefix" "$env_file" "${client_args[@]}"
