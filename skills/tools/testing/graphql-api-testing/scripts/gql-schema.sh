#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "$1" >&2
  exit 1
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$s"
}

usage() {
  cat >&2 <<'EOF'
Usage:
  gql-schema.sh [options]

Options:
  --config-dir <dir>   GraphQL setup dir (same discovery semantics as gql.sh; default: current dir)
  --file <path>        Explicit schema file path (overrides env + schema.env)
  --cat                Print the schema file contents (default: print resolved path)
  -h, --help           Show help

Environment variables:
  GQL_SCHEMA_FILE       Override schema file path (relative paths resolve under <setup_dir>)

Config files (recommended):
  setup/graphql/schema.env        Committed (no secrets); sets GQL_SCHEMA_FILE
  setup/graphql/schema.local.env  Local override (gitignored via *.local.env)

Defaults (when no explicit config is set):
  <setup_dir>/schema.gql
  <setup_dir>/schema.graphql
  <setup_dir>/schema.graphqls
  <setup_dir>/api.graphql
  <setup_dir>/api.gql

Examples:
  # Print resolved schema file path
  $CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-schema.sh --config-dir setup/graphql

  # Print schema contents
  $CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql-schema.sh --config-dir setup/graphql --cat
EOF
}

config_dir=""
schema_file_arg=""
print_mode="path"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --config-dir)
      config_dir="${2:-}"
      [[ -n "$config_dir" ]] || die "Missing value for --config-dir"
      shift 2
      ;;
    --file)
      schema_file_arg="${2:-}"
      [[ -n "$schema_file_arg" ]] || die "Missing value for --file"
      shift 2
      ;;
    --cat)
      print_mode="cat"
      shift
      ;;
    *)
      die "Unknown argument: ${1}"
      ;;
  esac
done

find_upwards_for_file() {
  local start_dir="$1"
  local filename="$2"
  local dir="$start_dir"

  if [[ "$dir" == /* ]]; then
    dir="/${dir##/}"
  fi

  while [[ -n "$dir" ]]; do
    if [[ -f "$dir/$filename" ]]; then
      printf "%s" "$dir"
      return 0
    fi

    local parent
    parent="$(cd "$dir" 2>/dev/null && cd .. && pwd -P)" || break
    if [[ "$parent" == /* ]]; then
      parent="/${parent##/}"
    fi
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
  done

  return 1
}

read_env_var_from_files() {
  local key="$1"
  shift

  local value=''
  local file
  for file in "$@"; do
    [[ -f "$file" ]] || continue

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
      raw_line="${raw_line%$'\r'}"
      local line
      line="$(trim "$raw_line")"
      [[ -z "$line" ]] && continue
      [[ "$line" == \#* ]] && continue

      if [[ "$line" =~ ^(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
        local found_key="${BASH_REMATCH[2]}"
        [[ "$found_key" == "$key" ]] || continue

        local found_value
        found_value="$(trim "${BASH_REMATCH[3]}")"

        if [[ "$found_value" =~ ^\"(.*)\"$ ]]; then
          found_value="${BASH_REMATCH[1]}"
        elif [[ "$found_value" =~ ^\'(.*)\'$ ]]; then
          found_value="${BASH_REMATCH[1]}"
        fi

        value="$found_value"
      fi
    done < "$file"
  done

  [[ -n "$value" ]] || return 1
  printf "%s" "$value"
}

resolve_setup_dir() {
  local seed="."
  local config_dir_explicit="0"

  if [[ -n "$config_dir" ]]; then
    seed="$config_dir"
    config_dir_explicit="1"
  fi

  local seed_abs=''
  seed_abs="$(cd "$seed" 2>/dev/null && pwd -P || true)"
  [[ -n "$seed_abs" ]] || return 1

  local found=''
  found="$(find_upwards_for_file "$seed_abs" "schema.env" 2>/dev/null || true)"
  if [[ -z "$found" ]]; then
    found="$(find_upwards_for_file "$seed_abs" "schema.local.env" 2>/dev/null || true)"
  fi
  if [[ -z "$found" ]]; then
    found="$(find_upwards_for_file "$seed_abs" "endpoints.env" 2>/dev/null || true)"
  fi
  if [[ -z "$found" ]]; then
    found="$(find_upwards_for_file "$seed_abs" "jwts.env" 2>/dev/null || true)"
  fi
  if [[ -z "$found" ]]; then
    found="$(find_upwards_for_file "$seed_abs" "jwts.local.env" 2>/dev/null || true)"
  fi

  if [[ -n "$found" ]]; then
    printf "%s" "$found"
    return 0
  fi

  if [[ "$config_dir_explicit" == "1" ]]; then
    printf "%s" "$seed_abs"
    return 0
  fi

  if [[ -d "setup/graphql" ]]; then
    (cd "setup/graphql" 2>/dev/null && pwd -P) || true
    return 0
  fi

  printf "%s" "$seed_abs"
}

setup_dir="$(resolve_setup_dir 2>/dev/null || true)"
[[ -n "$setup_dir" ]] || die "Failed to resolve setup dir (try --config-dir)."

schema_file="${schema_file_arg:-${GQL_SCHEMA_FILE:-}}"
if [[ -z "$schema_file" ]]; then
  schema_file="$(read_env_var_from_files "GQL_SCHEMA_FILE" "$setup_dir/schema.local.env" "$setup_dir/schema.env" 2>/dev/null || true)"
fi

if [[ -z "$schema_file" ]]; then
  for candidate in schema.gql schema.graphql schema.graphqls api.graphql api.gql; do
    if [[ -f "$setup_dir/$candidate" ]]; then
      schema_file="$candidate"
      break
    fi
  done
fi

[[ -n "$schema_file" ]] || die "Schema file not configured. Set GQL_SCHEMA_FILE in schema.env (or pass --file)."

if [[ "$schema_file" != /* ]]; then
  schema_path="$(cd "$setup_dir" 2>/dev/null && cd "$(dirname "$schema_file")" 2>/dev/null && pwd -P)/$(basename "$schema_file")"
else
  schema_path="$schema_file"
fi

[[ -f "$schema_path" ]] || die "Schema file not found: $schema_path"

if [[ "$print_mode" == "cat" ]]; then
  cat "$schema_path"
else
  printf "%s\n" "$schema_path"
fi

