#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sql-mssql.sh --prefix <PREFIX> --env-file <path> [--query "<sql>" | --file <file.sql> | -- <sqlcmd args...>]

Examples:
  sql-mssql.sh --prefix TEST --env-file /dev/null --query "select 1;"
  sql-mssql.sh --prefix TEST --env-file /dev/null --file ./query.sql
  sql-mssql.sh --prefix TEST --env-file /dev/null -- -Q "select 1;" -h -1
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
if [[ -n "$query" ]]; then
  client_args+=(-Q "$query")
fi
if [[ -n "$file" ]]; then
  client_args+=(-i "$file")
fi
client_args+=("${pass_args[@]}")

sql_skill_run_mssql "$prefix" "$env_file" "${client_args[@]}"
