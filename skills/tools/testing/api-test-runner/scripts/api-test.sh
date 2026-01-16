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

to_lower() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

bool_from_env() {
  local raw="${1:-}"
  local name="${2:-}"
  local default="${3:-false}"

  raw="$(trim "$raw")"
  if [[ -z "$raw" ]]; then
    [[ "$default" == "true" ]]
    return $?
  fi

  local lowered
  lowered="$(to_lower "$raw")"
  case "$lowered" in
    true) return 0 ;;
    false) return 1 ;;
    *)
      echo "api-test.sh: warning: ${name} must be true|false (got: ${raw}); treating as false" >&2
      return 1
      ;;
  esac
}

to_upper() {
  printf "%s" "$1" | tr '[:lower:]' '[:upper:]'
}

mask_args_for_command_snippet() {
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  local -a original=("$@")
  local -a masked=()
  local mask_next="0"
  local arg=''

  for arg in "${original[@]}"; do
    if [[ "$mask_next" == "1" ]]; then
      masked+=("REDACTED")
      mask_next="0"
      continue
    fi

    case "$arg" in
      --token|--jwt)
        masked+=("$arg")
        mask_next="1"
        ;;
      --token=*|--jwt=*)
        masked+=("${arg%%=*}=REDACTED")
        ;;
      *)
        masked+=("$arg")
        ;;
    esac
  done

  local out=''
  out="$(printf "%q " "${masked[@]}")"
  out="${out% }"
  printf "%s" "$out"
}

now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

usage() {
  cat >&2 <<'EOF'
Usage:
  api-test.sh (--suite <name> | --suite-file <path>) [options]

Options:
  --suite <name>           Resolve suite under tests/api/suites/<name>.suite.json (fallback: setup/api/suites)
  --suite-file <path>      Explicit suite file path (overrides canonical path)
  --out <path>             Write JSON results to a file (stdout always emits JSON)
  --junit <path>           Write JUnit XML to a file (optional)
  --allow-writes           Allow write-capable cases (still requires allowWrite: true in the case)
  --only <id1,id2,...>      Run only the listed case IDs
  --skip <id1,id2,...>      Skip the listed case IDs
  --tag <tag>              Run only cases that include this tag (repeatable)
  --fail-fast              Stop after the first failed case
  --continue               Continue after failures (default)
  -h, --help               Show help

Environment:
  API_TEST_ALLOW_WRITES_ENABLED=true  Same as --allow-writes
  API_TEST_OUTPUT_DIR      Base output dir (default: <repo>/out/api-test-runner)
  API_TEST_AUTH_JSON       JSON credentials for suite auth (when .auth is configured; override via .auth.secretEnv)
  API_TEST_REST_URL        Default REST URL when suite/case omits url
  API_TEST_GQL_URL         Default GraphQL URL when suite/case omits url
  API_TEST_SUITES_DIR      Override suites dir for --suite (e.g. tests/api/suites)

Notes:
  - Requires: git, jq, python3
  - Runs from any subdir inside the repo; paths are resolved relative to repo root.
  - `--suite` only searches the canonical suite dirs; if your suite file lives elsewhere, use `--suite-file` (or set `API_TEST_SUITES_DIR`).
  - GraphQL ops that contain a `mutation` definition require `allowWrite: true` on the case (guardrail to prevent accidental writes in CI).
  - REST requests support multipart file uploads and optional cleanup blocks (see rest.sh schema).
  - Suite cases may optionally define .cleanup steps (REST + GraphQL) to remove write-case artifacts.
EOF
}

suite_name=""
suite_file=""
out_file=""
junit_file=""
allow_writes="0"
fail_fast="0"

declare -a tag_filters=()
only_csv=""
skip_csv=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --suite)
      suite_name="${2:-}"
      [[ -n "$suite_name" ]] || die "Missing value for --suite"
      shift 2
      ;;
    --suite-file)
      suite_file="${2:-}"
      [[ -n "$suite_file" ]] || die "Missing value for --suite-file"
      shift 2
      ;;
    --out)
      out_file="${2:-}"
      [[ -n "$out_file" ]] || die "Missing value for --out"
      shift 2
      ;;
    --junit)
      junit_file="${2:-}"
      [[ -n "$junit_file" ]] || die "Missing value for --junit"
      shift 2
      ;;
    --allow-writes)
      allow_writes="1"
      shift
      ;;
    --only)
      only_csv="${2:-}"
      [[ -n "$only_csv" ]] || die "Missing value for --only"
      shift 2
      ;;
    --skip)
      skip_csv="${2:-}"
      [[ -n "$skip_csv" ]] || die "Missing value for --skip"
      shift 2
      ;;
    --tag)
      tag="${2:-}"
      [[ -n "$tag" ]] || die "Missing value for --tag"
      tag_filters+=("$tag")
      shift 2
      ;;
    --fail-fast)
      fail_fast="1"
      shift
      ;;
    --continue)
      fail_fast="0"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: ${1}"
      ;;
  esac
done

for cmd in git jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Must run inside a git work tree"
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

[[ -z "$suite_name" || -z "$suite_file" ]] || die "Use only one of --suite or --suite-file"
[[ -n "$suite_name" || -n "$suite_file" ]] || die "Missing suite (use --suite or --suite-file)"

rest_runner_abs="${repo_root%/}/tests/tools/rest-api-testing/scripts/rest.sh"
gql_runner_abs="${repo_root%/}/tests/tools/graphql-api-testing/scripts/gql.sh"
if [[ ! -f "$rest_runner_abs" ]]; then
  rest_runner_abs="${repo_root%/}/skills/tools/testing/rest-api-testing/scripts/rest.sh"
fi
if [[ ! -f "$gql_runner_abs" ]]; then
  gql_runner_abs="${repo_root%/}/skills/tools/testing/graphql-api-testing/scripts/gql.sh"
fi
[[ -f "$rest_runner_abs" ]] || die "Missing REST runner: ${rest_runner_abs#"$repo_root"/}"
[[ -f "$gql_runner_abs" ]] || die "Missing GraphQL runner: ${gql_runner_abs#"$repo_root"/}"

resolve_path() {
  local raw="$1"
  if [[ "$raw" == /* ]]; then
    printf "%s" "$raw"
  else
    printf "%s" "${repo_root%/}/$raw"
  fi
}

suite_path=""
if [[ -n "$suite_file" ]]; then
  suite_path="$(resolve_path "$suite_file")"
else
  suite_key="$suite_name"
  suite_key="$(trim "$suite_key")"
  suite_key="${suite_key%.suite.json}"
  suite_key="${suite_key%.json}"

  suite_dir_override="$(trim "${API_TEST_SUITES_DIR:-}")"
  if [[ -n "$suite_dir_override" ]]; then
    suite_dir_override_abs="$(resolve_path "$suite_dir_override")"
    suite_path="${suite_dir_override_abs%/}/${suite_key}.suite.json"
  else
    suite_path="${repo_root%/}/tests/api/suites/${suite_key}.suite.json"
    if [[ ! -f "$suite_path" ]]; then
      suite_path="${repo_root%/}/setup/api/suites/${suite_key}.suite.json"
    fi
  fi
fi

[[ -f "$suite_path" ]] || die "Suite file not found: ${suite_path#"$repo_root"/}"

run_id="$(date -u +%Y%m%d-%H%M%SZ 2>/dev/null || date +%Y%m%d-%H%M%S)"
out_dir_base="${API_TEST_OUTPUT_DIR:-${repo_root%/}/out/api-test-runner}"
run_dir="${out_dir_base%/}/${run_id}"
mkdir -p "$run_dir"

if bool_from_env "${API_TEST_ALLOW_WRITES_ENABLED:-}" "API_TEST_ALLOW_WRITES_ENABLED" "false"; then
  allow_writes="1"
fi

suite_version="$(jq -r '.version // empty' "$suite_path")"
[[ "$suite_version" =~ ^[0-9]+$ ]] || die "Invalid suite version (expected integer): $suite_version"
[[ "$suite_version" == "1" ]] || die "Unsupported suite version: $suite_version (expected 1)"

suite_name_value="$(jq -r '.name // empty' "$suite_path")"
suite_name_value="$(trim "$suite_name_value")"
[[ -n "$suite_name_value" ]] || suite_name_value="$(basename "$suite_path")"

default_env="$(jq -r '.defaults.env? // empty' "$suite_path")"
default_env="$(trim "$default_env")"

default_no_history="$(jq -r '.defaults.noHistory? // false' "$suite_path")"
default_no_history="$(to_lower "$(trim "$default_no_history")")"

default_rest_config_dir="$(jq -r '.defaults.rest.configDir? // "setup/rest"' "$suite_path")"
default_graphql_config_dir="$(jq -r '.defaults.graphql.configDir? // "setup/graphql"' "$suite_path")"

default_rest_token="$(jq -r '.defaults.rest.token? // empty' "$suite_path")"
default_rest_url="$(jq -r '.defaults.rest.url? // empty' "$suite_path")"

default_graphql_jwt="$(jq -r '.defaults.graphql.jwt? // empty' "$suite_path")"
default_graphql_url="$(jq -r '.defaults.graphql.url? // empty' "$suite_path")"

env_rest_url="$(trim "${API_TEST_REST_URL:-}")"
env_gql_url="$(trim "${API_TEST_GQL_URL:-}")"

# ----------------------------
# Optional CI auth via secrets
# ----------------------------
auth_enabled="0"
auth_provider=""
auth_required="true"
auth_secret_env="API_TEST_AUTH_JSON"
auth_secret_json=""

auth_rest_login_request_template=""
auth_rest_credentials_jq=""
auth_rest_token_jq=""
auth_rest_config_dir=""
auth_rest_url=""
auth_rest_env=""

auth_gql_login_op=""
auth_gql_login_vars_template=""
auth_gql_credentials_jq=""
auth_gql_token_jq=""
auth_gql_config_dir=""
auth_gql_url=""
auth_gql_env=""

auth_type="$(jq -r '(.auth // empty) | type' "$suite_path" 2>/dev/null || true)"
auth_type="$(trim "$auth_type")"
if [[ -n "$auth_type" ]]; then
  [[ "$auth_type" == "object" ]] || die "Invalid suite auth block (expected object): .auth is $auth_type"
  auth_enabled="1"

  auth_secret_env="$(jq -r '.auth.secretEnv? // "API_TEST_AUTH_JSON"' "$suite_path")"
  auth_secret_env="$(trim "$auth_secret_env")"
  [[ -n "$auth_secret_env" ]] || die "Invalid suite auth block: .auth.secretEnv is empty"
  [[ "$auth_secret_env" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "Invalid suite auth block: .auth.secretEnv must be a valid env var name"

  auth_required="$(jq -r '.auth.required? // true' "$suite_path")"
  auth_required="$(to_lower "$(trim "$auth_required")")"
  if [[ "$auth_required" != "true" && "$auth_required" != "false" ]]; then
    die "Invalid suite auth block: .auth.required must be boolean"
  fi

  auth_provider="$(jq -r '.auth.provider? // empty' "$suite_path")"
  auth_provider="$(to_lower "$(trim "$auth_provider")")"
  if [[ -z "$auth_provider" ]]; then
    has_rest="$(jq -r '(.auth.rest // empty) | type' "$suite_path" 2>/dev/null || true)"
    has_rest="$(trim "$has_rest")"
    has_gql="$(jq -r '(.auth.graphql // empty) | type' "$suite_path" 2>/dev/null || true)"
    has_gql="$(trim "$has_gql")"
    if [[ -n "$has_rest" && -z "$has_gql" ]]; then
      auth_provider="rest"
    elif [[ -z "$has_rest" && -n "$has_gql" ]]; then
      auth_provider="graphql"
    else
      die "Invalid suite auth block: .auth.provider is required when both .auth.rest and .auth.graphql are present"
    fi
  fi

  if [[ "$auth_provider" != "rest" && "$auth_provider" != "graphql" && "$auth_provider" != "gql" ]]; then
    die "Invalid suite auth block: .auth.provider must be one of: rest, graphql"
  fi
  if [[ "$auth_provider" == "gql" ]]; then
    auth_provider="graphql"
  fi

  if [[ "$auth_provider" == "rest" ]]; then
    auth_rest_login_request_template="$(jq -r '.auth.rest.loginRequestTemplate? // empty' "$suite_path")"
    auth_rest_login_request_template="$(trim "$auth_rest_login_request_template")"
    [[ -n "$auth_rest_login_request_template" ]] || die "Invalid suite auth.rest block: missing loginRequestTemplate"

    auth_rest_credentials_jq="$(jq -r '.auth.rest.credentialsJq? // empty' "$suite_path")"
    auth_rest_credentials_jq="$(trim "$auth_rest_credentials_jq")"
    [[ -n "$auth_rest_credentials_jq" ]] || die "Invalid suite auth.rest block: missing credentialsJq"

    auth_rest_token_jq="$(jq -r '.auth.rest.tokenJq? // empty' "$suite_path")"
    auth_rest_token_jq="$(trim "$auth_rest_token_jq")"
    if [[ -z "$auth_rest_token_jq" ]]; then
      auth_rest_token_jq='.. | objects | (.accessToken? // .access_token? // .token? // .jwt? // empty) | select(type=="string" and length>0) | .'
    fi

    auth_rest_config_dir="$(jq -r '.auth.rest.configDir? // empty' "$suite_path")"
    auth_rest_config_dir="$(trim "$auth_rest_config_dir")"
    auth_rest_config_dir="${auth_rest_config_dir:-$default_rest_config_dir}"

    auth_rest_url="$(jq -r '.auth.rest.url? // empty' "$suite_path")"
    auth_rest_url="$(trim "$auth_rest_url")"
    auth_rest_env="$(jq -r '.auth.rest.env? // empty' "$suite_path")"
    auth_rest_env="$(trim "$auth_rest_env")"

  else
    auth_gql_login_op="$(jq -r '.auth.graphql.loginOp? // empty' "$suite_path")"
    auth_gql_login_op="$(trim "$auth_gql_login_op")"
    [[ -n "$auth_gql_login_op" ]] || die "Invalid suite auth.graphql block: missing loginOp"

    auth_gql_login_vars_template="$(jq -r '.auth.graphql.loginVarsTemplate? // empty' "$suite_path")"
    auth_gql_login_vars_template="$(trim "$auth_gql_login_vars_template")"
    [[ -n "$auth_gql_login_vars_template" ]] || die "Invalid suite auth.graphql block: missing loginVarsTemplate"

    auth_gql_credentials_jq="$(jq -r '.auth.graphql.credentialsJq? // empty' "$suite_path")"
    auth_gql_credentials_jq="$(trim "$auth_gql_credentials_jq")"
    [[ -n "$auth_gql_credentials_jq" ]] || die "Invalid suite auth.graphql block: missing credentialsJq"

    auth_gql_token_jq="$(jq -r '.auth.graphql.tokenJq? // empty' "$suite_path")"
    auth_gql_token_jq="$(trim "$auth_gql_token_jq")"
    if [[ -z "$auth_gql_token_jq" ]]; then
      auth_gql_token_jq='.. | objects | (.accessToken? // .access_token? // .token? // .jwt? // empty) | select(type=="string" and length>0) | .'
    fi

    auth_gql_config_dir="$(jq -r '.auth.graphql.configDir? // empty' "$suite_path")"
    auth_gql_config_dir="$(trim "$auth_gql_config_dir")"
    auth_gql_config_dir="${auth_gql_config_dir:-$default_graphql_config_dir}"

    auth_gql_url="$(jq -r '.auth.graphql.url? // empty' "$suite_path")"
    auth_gql_url="$(trim "$auth_gql_url")"
    auth_gql_env="$(jq -r '.auth.graphql.env? // empty' "$suite_path")"
    auth_gql_env="$(trim "$auth_gql_env")"
  fi

  # Read and validate secret JSON.
  auth_secret_json="$(printenv "$auth_secret_env" 2>/dev/null || true)"
  auth_secret_json="$(trim "$auth_secret_json")"
  if [[ -z "$auth_secret_json" ]]; then
    if [[ "$auth_required" == "false" ]]; then
      auth_enabled="0"
      auth_secret_json=""
      printf "api-test-runner: auth disabled (missing %s and auth.required=false)\n" "$auth_secret_env" >&2
    else
      die "Missing auth secret env var for suite auth: ${auth_secret_env}"
    fi
  else
    printf "%s" "$auth_secret_json" | jq -e . >/dev/null 2>&1 || die "Invalid JSON in ${auth_secret_env}"
  fi
fi

declare -A auth_tokens=()
declare -A auth_errors=()
declare -A access_token_rest_config_dir_cache=()
declare -A access_token_graphql_config_dir_cache=()
auth_token_value=""

slug_for_cache_dir() {
  python3 - "$1" <<'PY'
import hashlib
import re
import sys

s = sys.argv[1]
slug = re.sub(r"[^A-Za-z0-9._-]+", "-", s)
slug = re.sub(r"-{2,}", "-", slug).strip("-") or "dir"
h = hashlib.sha1(s.encode("utf-8")).hexdigest()[:8]
print(f"{slug}-{h}")
PY
}

path_relative_to_repo_root() {
  local abs="$1"
  if [[ "$abs" == "$repo_root/"* ]]; then
    printf "%s" "${abs#"$repo_root"/}"
  else
    printf "%s" "$abs"
  fi
}

ensure_access_token_rest_config_dir() {
  local source_dir_raw="$1"
  source_dir_raw="$(trim "$source_dir_raw")"
  [[ -n "$source_dir_raw" ]] || die "Internal error: empty REST configDir"

  local source_abs key
  source_abs="$(resolve_path "$source_dir_raw")"
  key="$source_abs"

  if [[ -n "${access_token_rest_config_dir_cache[$key]:-}" ]]; then
    printf "%s" "${access_token_rest_config_dir_cache[$key]}"
    return 0
  fi

  local slug dest_abs dest_rel
  slug="$(slug_for_cache_dir "rest:${source_dir_raw}")"
  dest_abs="${run_dir%/}/auth-config/rest/${slug}"
  mkdir -p "$dest_abs" || die "Failed to create auth config dir: ${dest_abs#"$repo_root"/}"

  # Copy endpoint presets (safe to commit) if present, but intentionally do NOT copy tokens.env.
  if [[ -f "$source_abs/endpoints.env" ]]; then
    cp "$source_abs/endpoints.env" "$dest_abs/endpoints.env" || die "Failed to copy endpoints.env for auth config dir"
  else
    : >"$dest_abs/endpoints.env" || die "Failed to create endpoints.env for auth config dir"
  fi
  if [[ -f "$source_abs/endpoints.local.env" ]]; then
    cp "$source_abs/endpoints.local.env" "$dest_abs/endpoints.local.env" || die "Failed to copy endpoints.local.env for auth config dir"
  fi

  dest_rel="$(path_relative_to_repo_root "$dest_abs")"
  access_token_rest_config_dir_cache[$key]="$dest_rel"
  printf "%s" "$dest_rel"
}

ensure_access_token_graphql_config_dir() {
  local source_dir_raw="$1"
  source_dir_raw="$(trim "$source_dir_raw")"
  [[ -n "$source_dir_raw" ]] || die "Internal error: empty GraphQL configDir"

  local source_abs key
  source_abs="$(resolve_path "$source_dir_raw")"
  key="$source_abs"

  if [[ -n "${access_token_graphql_config_dir_cache[$key]:-}" ]]; then
    printf "%s" "${access_token_graphql_config_dir_cache[$key]}"
    return 0
  fi

  local slug dest_abs dest_rel
  slug="$(slug_for_cache_dir "graphql:${source_dir_raw}")"
  dest_abs="${run_dir%/}/auth-config/graphql/${slug}"
  mkdir -p "$dest_abs" || die "Failed to create auth config dir: ${dest_abs#"$repo_root"/}"

  # Copy endpoint presets if present, but intentionally do NOT copy jwts.env.
  if [[ -f "$source_abs/endpoints.env" ]]; then
    cp "$source_abs/endpoints.env" "$dest_abs/endpoints.env" || die "Failed to copy endpoints.env for auth config dir"
  else
    : >"$dest_abs/endpoints.env" || die "Failed to create endpoints.env for auth config dir"
  fi
  if [[ -f "$source_abs/endpoints.local.env" ]]; then
    cp "$source_abs/endpoints.local.env" "$dest_abs/endpoints.local.env" || die "Failed to copy endpoints.local.env for auth config dir"
  fi

  dest_rel="$(path_relative_to_repo_root "$dest_abs")"
  access_token_graphql_config_dir_cache[$key]="$dest_rel"
  printf "%s" "$dest_rel"
}

auth_render_credentials() {
  local profile="$1"
  local expr="$2"
  local provider="$3"
  local out='' rc arr_json count

  [[ -n "$auth_secret_json" ]] || { printf "%s" "auth_secret_missing(provider=${provider},profile=${profile})" >&2; return 1; }

  set +e
  arr_json="$(
    printf "%s" "$auth_secret_json" |
      jq -c --arg profile "$profile" "[ ( $expr ) ]" 2>/dev/null
  )"
  rc=$?
  set -e

  if [[ "$rc" != "0" ]]; then
    printf "%s" "auth_credentials_jq_error(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  count="$(jq -r 'length' <<<"$arr_json" 2>/dev/null || true)"
  count="$(trim "$count")"
  if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
    printf "%s" "auth_credentials_jq_error(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  if [[ "$count" == "0" ]]; then
    printf "%s" "auth_credentials_missing(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  if [[ "$count" != "1" ]]; then
    printf "%s" "auth_credentials_ambiguous(provider=${provider},profile=${profile},count=${count})" >&2
    return 1
  fi

  out="$(jq -c '.[0]' <<<"$arr_json" 2>/dev/null || true)"
  out="$(trim "$out")"
  if [[ -z "$out" || "$out" == "null" ]]; then
    printf "%s" "auth_credentials_missing(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  if ! printf "%s" "$out" | jq -e 'type == "object"' >/dev/null 2>&1; then
    printf "%s" "auth_credentials_invalid(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  printf "%s" "$out"
}

auth_extract_token() {
  local response_file="$1"
  local token_expr="$2"
  local provider="$3"
  local profile="$4"
  local token='' rc

  set +e
  token="$(
    jq -r "$token_expr" "$response_file" 2>/dev/null |
      head -n 1
  )"
  rc=$?
  set -e

  if [[ "$rc" != "0" ]]; then
    printf "%s" "auth_token_jq_error(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  token="$(trim "$token")"
  if [[ -z "$token" || "$token" == "null" ]]; then
    printf "%s" "auth_token_missing(provider=${provider},profile=${profile})" >&2
    return 1
  fi

  printf "%s" "$token"
}

auth_login_rest() {
  local profile="$1"

  local template_abs credentials_json request_file_tmp response_tmp stderr_tmp rc token auth_login_url auth_env
  local auth_config_dir=''
  local -a cmd=()
  template_abs="$(resolve_path "$auth_rest_login_request_template")"
  [[ -f "$template_abs" ]] || return 1

  credentials_json="$(auth_render_credentials "$profile" "$auth_rest_credentials_jq" "rest")" || return 1
  credentials_json="$(trim "$credentials_json")"
  [[ -n "$credentials_json" ]] || return 1

  request_file_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.rest.request.json)"
  response_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.rest.response.json)"
  stderr_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.rest.stderr.log)"
  rc=0

  if ! jq -c --argjson creds "$credentials_json" '.body = ((.body // {}) + $creds)' "$template_abs" >"$request_file_tmp" 2>/dev/null; then
    printf "%s" "auth_login_template_render_failed(provider=rest,profile=${profile})" >&2
    rm -f "$request_file_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true
    return 1
  fi

  auth_login_url="$(trim "$auth_rest_url")"
  if [[ -z "$auth_login_url" ]]; then
    auth_login_url="$(trim "$default_rest_url")"
  fi
  if [[ -z "$auth_login_url" && -n "$env_rest_url" ]]; then
    auth_login_url="$(trim "$env_rest_url")"
  fi

  auth_config_dir="$(ensure_access_token_rest_config_dir "$auth_rest_config_dir")"

  cmd=("$rest_runner_abs" "--config-dir" "$auth_config_dir" "--no-history")
  if [[ -n "$auth_login_url" ]]; then
    cmd+=("--url" "$auth_login_url")
  else
    auth_env="$(trim "${auth_rest_env:-$default_env}")"
    auth_env="$(trim "$auth_env")"
    [[ -n "$auth_env" ]] || { rm -f "$request_file_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true; return 1; }
    cmd+=("--env" "$auth_env")
  fi
  cmd+=("$request_file_tmp")

  if REST_TOKEN_NAME="" GQL_JWT_NAME="" ACCESS_TOKEN="" "${cmd[@]}" >"$response_tmp" 2>"$stderr_tmp"; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" != "0" ]]; then
    printf "%s" "auth_login_request_failed(provider=rest,profile=${profile},rc=${rc})" >&2
    rm -f "$request_file_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true
    return 1
  fi

  token="$(auth_extract_token "$response_tmp" "$auth_rest_token_jq" "rest" "$profile")" || {
    rm -f "$request_file_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true
    return 1
  }
  token="$(trim "$token")"

  rm -f "$request_file_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true

  [[ -n "$token" ]] || return 1
  printf "%s" "$token"
}

auth_login_graphql() {
  local profile="$1"

  local op_abs vars_template_abs credentials_json vars_tmp response_tmp stderr_tmp rc token auth_login_url auth_env
  local auth_config_dir=''
  local -a cmd=()
  op_abs="$(resolve_path "$auth_gql_login_op")"
  [[ -f "$op_abs" ]] || return 1

  vars_template_abs="$(resolve_path "$auth_gql_login_vars_template")"
  [[ -f "$vars_template_abs" ]] || return 1

  credentials_json="$(auth_render_credentials "$profile" "$auth_gql_credentials_jq" "graphql")" || return 1
  credentials_json="$(trim "$credentials_json")"
  [[ -n "$credentials_json" ]] || return 1

  vars_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.gql.vars.json)"
  response_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.gql.response.json)"
  stderr_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.gql.stderr.log)"
  rc=0

  if ! jq -c --argjson creds "$credentials_json" '. + $creds' "$vars_template_abs" >"$vars_tmp" 2>/dev/null; then
    printf "%s" "auth_login_template_render_failed(provider=graphql,profile=${profile})" >&2
    rm -f "$vars_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true
    return 1
  fi

  auth_login_url="$(trim "$auth_gql_url")"
  if [[ -z "$auth_login_url" ]]; then
    auth_login_url="$(trim "$default_graphql_url")"
  fi
  if [[ -z "$auth_login_url" && -n "$env_gql_url" ]]; then
    auth_login_url="$(trim "$env_gql_url")"
  fi

  auth_config_dir="$(ensure_access_token_graphql_config_dir "$auth_gql_config_dir")"

  cmd=("$gql_runner_abs" "--config-dir" "$auth_config_dir" "--no-history")
  if [[ -n "$auth_login_url" ]]; then
    cmd+=("--url" "$auth_login_url")
  else
    auth_env="$(trim "${auth_gql_env:-$default_env}")"
    auth_env="$(trim "$auth_env")"
    [[ -n "$auth_env" ]] || { rm -f "$vars_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true; return 1; }
    cmd+=("--env" "$auth_env")
  fi
  cmd+=("${op_abs#"$repo_root"/}")
  cmd+=("$vars_tmp")

  if REST_TOKEN_NAME="" GQL_JWT_NAME="" ACCESS_TOKEN="" "${cmd[@]}" >"$response_tmp" 2>"$stderr_tmp"; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" != "0" ]]; then
    printf "%s" "auth_login_request_failed(provider=graphql,profile=${profile},rc=${rc})" >&2
    rm -f "$vars_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true
    return 1
  fi

  token="$(auth_extract_token "$response_tmp" "$auth_gql_token_jq" "graphql" "$profile")" || {
    rm -f "$vars_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true
    return 1
  }
  token="$(trim "$token")"

  rm -f "$vars_tmp" "$response_tmp" "$stderr_tmp" 2>/dev/null || true

  [[ -n "$token" ]] || return 1
  printf "%s" "$token"
}

ensure_auth_token() {
  local profile="$1"
  auth_token_value=""

  [[ -n "$profile" ]] || return 1
  [[ "$auth_enabled" == "1" ]] || return 1

  if [[ -n "${auth_tokens[$profile]:-}" ]]; then
    auth_token_value="${auth_tokens[$profile]}"
    return 0
  fi

  if [[ -n "${auth_errors[$profile]:-}" ]]; then
    return 1
  fi

  local err_tmp
  err_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.auth.error)"
  local token=''
  if [[ "$auth_provider" == "rest" ]]; then
    token="$(auth_login_rest "$profile" 2>"$err_tmp" || true)"
  else
    token="$(auth_login_graphql "$profile" 2>"$err_tmp" || true)"
  fi
  token="$(trim "$token")"
  local err=''
  err="$(cat "$err_tmp" 2>/dev/null || true)"
  err="$(trim "$err")"
  rm -f "$err_tmp" 2>/dev/null || true
  if [[ -z "$token" ]]; then
    auth_errors["$profile"]="${err:-auth_login_failed(provider=${auth_provider},profile=${profile})}"
    return 1
  fi

  auth_tokens["$profile"]="$token"
  auth_token_value="$token"
  return 0
}

split_csv() {
  local csv="$1"
  python3 - "$csv" <<'PY'
import sys
csv = sys.argv[1].strip()
if not csv:
  raise SystemExit(0)
for part in csv.split(","):
  part = part.strip()
  if part:
    print(part)
PY
}

declare -A only_ids=()
if [[ -n "$only_csv" ]]; then
  while IFS= read -r item; do
    only_ids["$item"]="1"
  done < <(split_csv "$only_csv")
fi

declare -A skip_ids=()
if [[ -n "$skip_csv" ]]; then
  while IFS= read -r item; do
    skip_ids["$item"]="1"
  done < <(split_csv "$skip_csv")
fi

case_count="$(jq -r '.cases | length' "$suite_path")"
[[ "$case_count" =~ ^[0-9]+$ ]] || die "Invalid suite cases array"

sanitize_id() {
  python3 - "$1" <<'PY'
import re, sys
s = sys.argv[1]
s = re.sub(r"[^A-Za-z0-9._-]+", "-", s)
s = re.sub(r"-{2,}", "-", s).strip("-")
print(s or "case")
PY
}

is_rest_write_method() {
  local method
  method="$(to_upper "$(trim "${1:-}")")"
  case "$method" in
    GET|HEAD|OPTIONS)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

graphql_op_is_mutation() {
  local file="$1"
  python3 - "$file" <<'PY'
import re
import sys

path = sys.argv[1]
try:
  text = open(path, "r", encoding="utf-8").read()
except Exception:
  sys.exit(2)

# Best-effort: strip comments and string literals, then look for an operation definition.
#
# We intentionally treat any detected `mutation` operation definition as write-capable,
# even if the file starts with fragments/comments/schema snippets.
text = re.sub(r"/\\*.*?\\*/", " ", text, flags=re.S)

# Strip string literals (avoid false positives from e.g. argument strings containing "mutation").
text = re.sub(r"\"\"\"[\\s\\S]*?\"\"\"", " ", text)
text = re.sub(r"\"(?:\\\\.|[^\"\\\\])*\"", " ", text)

# Strip line comments (GraphQL uses '#', but some tools allow '//' too).
text = re.sub(r"(?m)#.*$", " ", text)
text = re.sub(r"(?m)//.*$", " ", text)

# Detect `mutation` operation definitions.
# - Must appear at the start of a definition line.
# - Must not be schema shorthand like `mutation: Mutation` (exclude ':' as the next token).
mutation_re = re.compile(
  r"(?im)^\s*mutation\b(?=\s*(?:\(|@|\{|[_A-Za-z]))"
)

sys.exit(0 if mutation_re.search(text) else 1)
PY
}

cleanup_append_log() {
  local file="$1"
  shift

  [[ -n "$file" ]] || return 0
  [[ "$#" -gt 0 ]] || return 0
  {
    printf "%s\n" "$@"
  } >>"$file"
}

cleanup_extract_value() {
  local response_file="$1"
  local expr="$2"

  [[ -n "$response_file" && -f "$response_file" ]] || return 1
  [[ -n "$expr" ]] || return 1

  local out='' rc
  set +e
  out="$(
    jq -r "$expr" "$response_file" 2>/dev/null |
      head -n 1
  )"
  rc=$?
  set -e

  [[ "$rc" == "0" ]] || return 1
  out="$(trim "$out")"
  [[ -n "$out" && "$out" != "null" ]] || return 1
  printf "%s" "$out"
  return 0
}

cleanup_render_template() {
  local template="$1"
  local response_file="$2"
  local vars_json="$3"

  local out="$template"

  if [[ -z "$vars_json" || "$vars_json" == "null" ]]; then
    printf "%s" "$out"
    return 0
  fi

  if ! printf "%s" "$vars_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
    return 1
  fi

  local var_key expr value
  while IFS= read -r var_key; do
    [[ -n "$var_key" ]] || continue
    expr="$(jq -r --arg key "$var_key" '.[$key] // empty' <<<"$vars_json")"
    expr="$(trim "$expr")"
    [[ -n "$expr" ]] || return 1

    value="$(cleanup_extract_value "$response_file" "$expr" 2>/dev/null || true)"
    value="$(trim "$value")"
    [[ -n "$value" && "$value" != "null" ]] || return 1
    out="${out//\{\{$var_key\}\}/$value}"
  done < <(jq -r 'keys[]' <<<"$vars_json")

  printf "%s" "$out"
  return 0
}

cleanup_render_file_template() {
  local template_file="$1"
  local response_file="$2"
  local vars_json="$3"
  local out_file="$4"

  [[ -n "$template_file" && -f "$template_file" ]] || return 1
  [[ -n "$out_file" ]] || return 1

  local rendered=''
  rendered="$(cleanup_render_template "$(cat "$template_file")" "$response_file" "$vars_json" 2>/dev/null || true)"
  rendered="$(trim "$rendered")"
  [[ -n "$rendered" ]] || return 1

  printf "%s\n" "$rendered" >"$out_file"
  jq -e . "$out_file" >/dev/null 2>&1 || return 1
  return 0
}

cleanup_run_rest_step() {
  local step_json="$1"
  local step_index="$2"

  local method path_template vars_json cleanup_path expect_status expect_jq
  method="$(jq -r '.method? // "DELETE"' <<<"$step_json")"
  method="$(to_upper "$(trim "$method")")"
  [[ -n "$method" ]] || die "Case '$id' cleanup step[$step_index] rest.method is empty"

  path_template="$(jq -r '.pathTemplate? // empty' <<<"$step_json")"
  path_template="$(trim "$path_template")"
  [[ -n "$path_template" ]] || die "Case '$id' cleanup step[$step_index] rest.pathTemplate is required"

  vars_json="$(jq -c '.vars? // {}' <<<"$step_json")"
  cleanup_path="$(cleanup_render_template "$path_template" "$stdout_file" "$vars_json" 2>/dev/null || true)"
  cleanup_path="$(trim "$cleanup_path")"
  [[ -n "$cleanup_path" ]] || {
    cleanup_append_log "$stderr_file" "cleanup(rest) render failed: step[$step_index] pathTemplate=$path_template"
    return 1
  }
  [[ "$cleanup_path" == /* ]] || die "Case '$id' cleanup step[$step_index] rest.pathTemplate must resolve to an absolute path (starts with /): $cleanup_path"

  expect_status="$(jq -r '.expect.status? // .expectStatus? // empty' <<<"$step_json")"
  expect_status="$(trim "$expect_status")"
  if [[ -z "$expect_status" ]]; then
    if [[ "$method" == "DELETE" ]]; then
      expect_status="204"
    else
      expect_status="200"
    fi
  fi
  [[ "$expect_status" =~ ^[0-9]+$ ]] || die "Case '$id' cleanup step[$step_index] rest.expectStatus must be an integer: $expect_status"

  expect_jq="$(jq -r '.expect.jq? // .expectJq? // empty' <<<"$step_json")"
  expect_jq="$(trim "$expect_jq")"

  local cleanup_config_dir cleanup_url cleanup_env cleanup_no_history cleanup_token cleanup_access_token
  cleanup_config_dir="$(jq -r '.configDir? // empty' <<<"$step_json")"
  cleanup_config_dir="$(trim "$cleanup_config_dir")"
  if [[ -z "$cleanup_config_dir" ]]; then
    cleanup_config_dir="${rest_config_dir:-$default_rest_config_dir}"
  fi

  cleanup_url="$(jq -r '.url? // empty' <<<"$step_json")"
  cleanup_url="$(trim "$cleanup_url")"
  if [[ -z "$cleanup_url" ]]; then
    cleanup_url="${rest_url:-$default_rest_url}"
    if [[ -z "$cleanup_url" && -n "$env_rest_url" ]]; then
      cleanup_url="$env_rest_url"
    fi
  fi

  cleanup_env="$(jq -r '.env? // empty' <<<"$step_json")"
  cleanup_env="$(trim "$cleanup_env")"
  cleanup_env="${cleanup_env:-$effective_env}"

  cleanup_no_history="$(jq -r '.noHistory? // empty' <<<"$step_json")"
  cleanup_no_history="$(to_lower "$(trim "$cleanup_no_history")")"
  if [[ -z "$cleanup_no_history" ]]; then
    cleanup_no_history="$effective_no_history"
  fi

  cleanup_token="$(jq -r '.token? // empty' <<<"$step_json")"
  cleanup_token="$(trim "$cleanup_token")"
  if [[ -z "$cleanup_token" ]]; then
    cleanup_token="${rest_token:-${gql_jwt:-$default_rest_token}}"
  fi

  cleanup_access_token="$access_token_for_case"
  cleanup_access_token="$(trim "$cleanup_access_token")"
  if [[ "$auth_enabled" == "1" && -n "$cleanup_token" ]]; then
    if ensure_auth_token "$cleanup_token"; then
      cleanup_access_token="$(trim "$auth_token_value")"
    else
      if [[ -z "$cleanup_access_token" ]]; then
        cleanup_append_log "$stderr_file" "cleanup(rest) auth failed: step[$step_index] profile=$cleanup_token"
        cleanup_append_log "$stderr_file" "${auth_errors[$cleanup_token]:-auth_login_failed(provider=${auth_provider},profile=${cleanup_token})}"
        return 1
      fi
    fi
  fi

  local effective_cleanup_config_dir
  effective_cleanup_config_dir="$cleanup_config_dir"
  if [[ -n "$cleanup_access_token" ]]; then
    effective_cleanup_config_dir="$(ensure_access_token_rest_config_dir "$cleanup_config_dir")"
  fi

  local cleanup_request_file cleanup_stdout_file cleanup_stderr_file
  cleanup_request_file="$run_dir/${safe_id}.cleanup.${step_index}.request.json"
  cleanup_stdout_file="$run_dir/${safe_id}.cleanup.${step_index}.response.json"
  cleanup_stderr_file="$run_dir/${safe_id}.cleanup.${step_index}.stderr.log"

  jq -c -n \
    --arg method "$method" \
    --arg path "$cleanup_path" \
    --argjson status "$expect_status" \
    --arg jqexpr "$expect_jq" \
    '
    {
      method: $method,
      path: $path,
      expect: ({ status: $status } + (if ($jqexpr | length) > 0 then { jq: $jqexpr } else {} end))
    }
  ' >"$cleanup_request_file"

  local -a cmd
  cmd=("$rest_runner_abs" "--config-dir" "$effective_cleanup_config_dir")
  if [[ "$cleanup_no_history" == "true" ]]; then
    cmd+=("--no-history")
  fi
  if [[ -n "$cleanup_url" ]]; then
    cmd+=("--url" "$cleanup_url")
  elif [[ -n "$cleanup_env" ]]; then
    cmd+=("--env" "$cleanup_env")
  fi
  if [[ -n "$cleanup_token" && -z "$cleanup_access_token" ]]; then
    cmd+=("--token" "$cleanup_token")
  fi
  cmd+=("${cleanup_request_file#"$repo_root"/}")

  local rc=0
  if [[ -n "$cleanup_access_token" ]]; then
    if REST_TOKEN_NAME="" GQL_JWT_NAME="" ACCESS_TOKEN="$cleanup_access_token" "${cmd[@]}" >"$cleanup_stdout_file" 2>"$cleanup_stderr_file"; then
      rc=0
    else
      rc=$?
    fi
  else
    if "${cmd[@]}" >"$cleanup_stdout_file" 2>"$cleanup_stderr_file"; then
      rc=0
    else
      rc=$?
    fi
  fi

  if [[ "$rc" != "0" ]]; then
    cleanup_append_log "$stderr_file" "cleanup(rest) failed: step[$step_index] rc=$rc $method $cleanup_path"
    if [[ -s "$cleanup_stderr_file" ]]; then
      cat "$cleanup_stderr_file" >>"$stderr_file" 2>/dev/null || true
    fi
    return 1
  fi

  return 0
}

cleanup_run_graphql_step() {
  local step_json="$1"
  local step_index="$2"

  local op op_abs
  op="$(jq -r '.op? // empty' <<<"$step_json")"
  op="$(trim "$op")"
  [[ -n "$op" ]] || die "Case '$id' cleanup step[$step_index] graphql.op is required"
  op_abs="$(resolve_path "$op")"
  [[ -f "$op_abs" ]] || die "Case '$id' cleanup step[$step_index] graphql.op not found: $op"

  local cleanup_config_dir cleanup_jwt cleanup_url cleanup_env cleanup_no_history
  cleanup_config_dir="$(jq -r '.configDir? // empty' <<<"$step_json")"
  cleanup_config_dir="$(trim "$cleanup_config_dir")"
  if [[ -z "$cleanup_config_dir" ]]; then
    cleanup_config_dir="${gql_config_dir:-$default_graphql_config_dir}"
  fi

  cleanup_jwt="$(jq -r '.jwt? // empty' <<<"$step_json")"
  cleanup_jwt="$(trim "$cleanup_jwt")"
  if [[ -z "$cleanup_jwt" ]]; then
    cleanup_jwt="${gql_jwt:-${rest_token:-$default_graphql_jwt}}"
  fi

  cleanup_url="$(jq -r '.url? // empty' <<<"$step_json")"
  cleanup_url="$(trim "$cleanup_url")"
  if [[ -z "$cleanup_url" ]]; then
    cleanup_url="${gql_url:-$default_graphql_url}"
    if [[ -z "$cleanup_url" && -n "$env_gql_url" ]]; then
      cleanup_url="$env_gql_url"
    fi
  fi

  cleanup_env="$(jq -r '.env? // empty' <<<"$step_json")"
  cleanup_env="$(trim "$cleanup_env")"
  cleanup_env="${cleanup_env:-$effective_env}"

  cleanup_no_history="$(jq -r '.noHistory? // empty' <<<"$step_json")"
  cleanup_no_history="$(to_lower "$(trim "$cleanup_no_history")")"
  if [[ -z "$cleanup_no_history" ]]; then
    cleanup_no_history="$effective_no_history"
  fi

  local allow_errors expect_jq
  allow_errors="$(jq -r '.allowErrors? // false' <<<"$step_json")"
  allow_errors="$(to_lower "$(trim "$allow_errors")")"
  if [[ "$allow_errors" != "true" && "$allow_errors" != "false" ]]; then
    die "Case '$id' cleanup step[$step_index] graphql.allowErrors must be boolean"
  fi

  expect_jq="$(jq -r '.expect.jq? // empty' <<<"$step_json")"
  expect_jq="$(trim "$expect_jq")"
  if [[ "$allow_errors" == "true" && -z "$expect_jq" ]]; then
    die "Case '$id' cleanup step[$step_index] graphql allowErrors=true must set expect.jq"
  fi

  local cleanup_access_token
  cleanup_access_token="$access_token_for_case"
  cleanup_access_token="$(trim "$cleanup_access_token")"
  if [[ "$auth_enabled" == "1" && -n "$cleanup_jwt" ]]; then
    if ensure_auth_token "$cleanup_jwt"; then
      cleanup_access_token="$(trim "$auth_token_value")"
    else
      if [[ -z "$cleanup_access_token" ]]; then
        cleanup_append_log "$stderr_file" "cleanup(graphql) auth failed: step[$step_index] profile=$cleanup_jwt"
        cleanup_append_log "$stderr_file" "${auth_errors[$cleanup_jwt]:-auth_login_failed(provider=${auth_provider},profile=${cleanup_jwt})}"
        return 1
      fi
    fi
  fi

  local effective_cleanup_config_dir
  effective_cleanup_config_dir="$cleanup_config_dir"
  if [[ -n "$cleanup_access_token" ]]; then
    effective_cleanup_config_dir="$(ensure_access_token_graphql_config_dir "$cleanup_config_dir")"
  fi

  local vars_jq vars_template vars_abs
  vars_jq="$(jq -r '.varsJq? // empty' <<<"$step_json")"
  vars_jq="$(trim "$vars_jq")"
  vars_template="$(jq -r '.varsTemplate? // empty' <<<"$step_json")"
  vars_template="$(trim "$vars_template")"
  vars_abs=""

  local vars_tmp
  vars_tmp="$run_dir/${safe_id}.cleanup.${step_index}.vars.json"

  if [[ -n "$vars_jq" ]]; then
    local rc=0
    set +e
    jq -c "$vars_jq" "$stdout_file" >"$vars_tmp" 2>/dev/null
    rc=$?
    set -e
    if [[ "$rc" != "0" ]] || ! jq -e 'type == "object"' "$vars_tmp" >/dev/null 2>&1; then
      cleanup_append_log "$stderr_file" "cleanup(graphql) varsJq failed: step[$step_index] varsJq=$vars_jq"
      return 1
    fi
    vars_abs="$vars_tmp"
  elif [[ -n "$vars_template" ]]; then
    local vars_template_abs vars_type vars_json
    vars_template_abs="$(resolve_path "$vars_template")"
    [[ -f "$vars_template_abs" ]] || die "Case '$id' cleanup step[$step_index] graphql.varsTemplate not found: $vars_template"
    vars_type="$(jq -r 'if has("vars") then (.vars | type) else "" end' <<<"$step_json")"
    if [[ -n "$vars_type" && "$vars_type" != "object" ]]; then
      die "Case '$id' cleanup step[$step_index] graphql.vars must be an object when varsTemplate is set"
    fi
    vars_json="$(jq -c '.vars? // {}' <<<"$step_json")"
    if ! cleanup_render_file_template "$vars_template_abs" "$stdout_file" "$vars_json" "$vars_tmp"; then
      cleanup_append_log "$stderr_file" "cleanup(graphql) varsTemplate render failed: step[$step_index] template=$vars_template"
      return 1
    fi
    vars_abs="$vars_tmp"
  else
    local vars_present vars_type vars_file_raw
    vars_present="$(jq -r 'has("vars")' <<<"$step_json")"
    if [[ "$vars_present" == "true" ]]; then
      vars_type="$(jq -r '.vars | type' <<<"$step_json")"
      if [[ "$vars_type" == "string" ]]; then
        vars_file_raw="$(jq -r '.vars' <<<"$step_json")"
        vars_file_raw="$(trim "$vars_file_raw")"
        [[ -n "$vars_file_raw" ]] || die "Case '$id' cleanup step[$step_index] graphql.vars is empty"
        vars_abs="$(resolve_path "$vars_file_raw")"
        [[ -f "$vars_abs" ]] || die "Case '$id' cleanup step[$step_index] graphql.vars not found: $vars_file_raw"
      elif [[ "$vars_type" != "null" && -n "$vars_type" ]]; then
        die "Case '$id' cleanup step[$step_index] graphql.vars must be a file path string when varsTemplate/varsJq are not set"
      fi
    fi
  fi

  local cleanup_stdout_file cleanup_stderr_file
  cleanup_stdout_file="$run_dir/${safe_id}.cleanup.${step_index}.response.json"
  cleanup_stderr_file="$run_dir/${safe_id}.cleanup.${step_index}.stderr.log"

  local -a cmd
  cmd=("$gql_runner_abs" "--config-dir" "$effective_cleanup_config_dir")
  if [[ "$cleanup_no_history" == "true" ]]; then
    cmd+=("--no-history")
  fi
  if [[ -n "$cleanup_url" ]]; then
    cmd+=("--url" "$cleanup_url")
  elif [[ -n "$cleanup_env" ]]; then
    cmd+=("--env" "$cleanup_env")
  fi
  if [[ -n "$cleanup_jwt" && -z "$cleanup_access_token" ]]; then
    cmd+=("--jwt" "$cleanup_jwt")
  fi
  cmd+=("${op_abs#"$repo_root"/}")
  if [[ -n "$vars_abs" ]]; then
    cmd+=("${vars_abs#"$repo_root"/}")
  fi

  local rc=0
  if [[ -n "$cleanup_access_token" ]]; then
    if REST_TOKEN_NAME="" GQL_JWT_NAME="" ACCESS_TOKEN="$cleanup_access_token" "${cmd[@]}" >"$cleanup_stdout_file" 2>"$cleanup_stderr_file"; then
      rc=0
    else
      rc=$?
    fi
  else
    if "${cmd[@]}" >"$cleanup_stdout_file" 2>"$cleanup_stderr_file"; then
      rc=0
    else
      rc=$?
    fi
  fi

  if [[ "$rc" != "0" ]]; then
    cleanup_append_log "$stderr_file" "cleanup(graphql) runner failed: step[$step_index] rc=$rc op=$op"
    if [[ -s "$cleanup_stderr_file" ]]; then
      cat "$cleanup_stderr_file" >>"$stderr_file" 2>/dev/null || true
    fi
    return 1
  fi

  if ! jq -e '(.errors? | length // 0) == 0' "$cleanup_stdout_file" >/dev/null 2>&1; then
    if [[ "$allow_errors" != "true" ]]; then
      cleanup_append_log "$stderr_file" "cleanup(graphql) errors present: step[$step_index] op=$op"
      return 1
    fi
  fi

  if [[ -n "$expect_jq" ]]; then
    if ! jq -e "$expect_jq" "$cleanup_stdout_file" >/dev/null 2>&1; then
      cleanup_append_log "$stderr_file" "cleanup(graphql) expect.jq failed: step[$step_index] $expect_jq"
      return 1
    fi
  fi

  return 0
}

run_case_cleanup() {
  local case_index="$1"

  local cleanup_type
  cleanup_type="$(jq -r "(.cases[$case_index].cleanup? // null) | type" "$suite_path" 2>/dev/null || true)"
  cleanup_type="$(trim "$cleanup_type")"
  if [[ -z "$cleanup_type" || "$cleanup_type" == "null" ]]; then
    return 0
  fi

  if [[ "$allow_writes" != "1" && "$(to_lower "$effective_env")" != "local" ]]; then
    cleanup_append_log "$stderr_file" "cleanup skipped (writes disabled): enable with API_TEST_ALLOW_WRITES_ENABLED=true (or --allow-writes)"
    return 0
  fi

  if [[ -z "$stdout_file" || ! -f "$stdout_file" ]]; then
    cleanup_append_log "$stderr_file" "cleanup failed: missing main response file"
    return 1
  fi

  local cleanup_step_count=0
  if [[ "$cleanup_type" == "object" ]]; then
    cleanup_step_count=1
  elif [[ "$cleanup_type" == "array" ]]; then
    cleanup_step_count="$(jq -r ".cases[$case_index].cleanup | length" "$suite_path")"
  else
    die "Case '$id' cleanup must be an object or array (got: $cleanup_type)"
  fi

  local any_failed=0
  local j step_json step_type rc
  for ((j=0; j<cleanup_step_count; j++)); do
    if [[ "$cleanup_type" == "array" ]]; then
      step_json="$(jq -c ".cases[$case_index].cleanup[$j]" "$suite_path")"
    else
      step_json="$(jq -c ".cases[$case_index].cleanup" "$suite_path")"
    fi

    step_type="$(jq -r '.type? // empty' <<<"$step_json")"
    step_type="$(to_lower "$(trim "$step_type")")"
    [[ -n "$step_type" ]] || die "Case '$id' cleanup step[$j] is missing type"
    if [[ "$step_type" == "gql" ]]; then
      step_type="graphql"
    fi

    rc=0
    if [[ "$step_type" == "rest" ]]; then
      cleanup_run_rest_step "$step_json" "$j"
      rc=$?
    elif [[ "$step_type" == "graphql" ]]; then
      cleanup_run_graphql_step "$step_json" "$j"
      rc=$?
    else
      die "Case '$id' cleanup step[$j] has invalid type (expected: rest|graphql): $step_type"
    fi

    if [[ "$rc" != "0" ]]; then
      any_failed=1
    fi
  done

  [[ "$any_failed" == "0" ]] || return 1
  return 0
}

case_matches_tags() {
  local tags_json="$1"
  if [[ "${#tag_filters[@]}" -eq 0 ]]; then
    return 0
  fi

  local wanted_json
  wanted_json="$(python3 - "${tag_filters[@]}" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1:]))
PY
)"

  jq -e --argjson wanted "$wanted_json" --argjson tags "$tags_json" '
    ($wanted | length) == 0
    or (
      ($tags | type) == "array"
      and ($wanted | all(. as $w; ($tags | index($w)) != null))
    )
  ' >/dev/null 2>&1
}

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"

total=0
passed=0
failed=0
skipped=0

cases_json="[]"

for ((i=0; i<case_count; i++)); do
  id="$(jq -r ".cases[$i].id // empty" "$suite_path")"
  id="$(trim "$id")"
  [[ -n "$id" ]] || die "Case is missing id at index $i"

  type="$(jq -r ".cases[$i].type // empty" "$suite_path")"
  type="$(to_lower "$(trim "$type")")"
  [[ -n "$type" ]] || die "Case '$id' is missing type"

  tags_json="$(jq -c ".cases[$i].tags? // []" "$suite_path")"

  allow_write_case="$(jq -r ".cases[$i].allowWrite? // false" "$suite_path")"
  allow_write_case="$(to_lower "$(trim "$allow_write_case")")"

  case_env="$(jq -r ".cases[$i].env? // empty" "$suite_path")"
  case_env="$(trim "$case_env")"
  effective_env="${case_env:-$default_env}"

  case_no_history="$(jq -r ".cases[$i].noHistory? // empty" "$suite_path")"
  case_no_history="$(to_lower "$(trim "$case_no_history")")"
  effective_no_history="$default_no_history"
  if [[ -n "$case_no_history" ]]; then
    effective_no_history="$case_no_history"
  fi

  should_run="1"
  skip_reason=""

  if [[ "${#only_ids[@]}" -gt 0 && -z "${only_ids[$id]:-}" ]]; then
    should_run="0"
    skip_reason="not_selected"
  fi
  if [[ -n "${skip_ids[$id]:-}" ]]; then
    should_run="0"
    skip_reason="skipped_by_id"
  fi
  if [[ "$should_run" == "1" ]]; then
    if ! case_matches_tags "$tags_json"; then
      should_run="0"
      skip_reason="tag_mismatch"
    fi
  fi

  command_snippet=""
  status="skipped"
  duration_ms=0
  message=""
  assertions_obj="{}"
  stdout_file=""
  stderr_file=""

  if [[ "$should_run" != "1" ]]; then
    total=$((total + 1))
    skipped=$((skipped + 1))
    message="$skip_reason"
  else
    total=$((total + 1))

    execute_case="1"
    start_ms="$(now_ms)"
    rc=0

    safe_id="$(sanitize_id "$id")"
    rest_config_dir=""
    rest_token=""
    rest_url=""
    gql_config_dir=""
    gql_jwt=""
    gql_url=""
    access_token_for_case=""

    if [[ "$type" == "rest" ]]; then
      request="$(jq -r ".cases[$i].request // empty" "$suite_path")"
      request="$(trim "$request")"
      [[ -n "$request" ]] || die "REST case '$id' is missing request"
      request_abs="$(resolve_path "$request")"
      [[ -f "$request_abs" ]] || die "REST case '$id' request not found: $request"

      rest_config_dir="$(jq -r ".cases[$i].configDir? // empty" "$suite_path")"
      rest_config_dir="$(trim "$rest_config_dir")"
      rest_config_dir="${rest_config_dir:-$default_rest_config_dir}"

      rest_token="$(jq -r ".cases[$i].token? // empty" "$suite_path")"
      rest_token="$(trim "$rest_token")"
      rest_token="${rest_token:-$default_rest_token}"

      rest_url="$(jq -r ".cases[$i].url? // empty" "$suite_path")"
      rest_url="$(trim "$rest_url")"
      rest_url="${rest_url:-$default_rest_url}"
      if [[ -z "$rest_url" && -n "$env_rest_url" ]]; then
        rest_url="$env_rest_url"
      fi

      method="$(jq -r '.method // empty' "$request_abs")"
      method="$(trim "$method")"
      if is_rest_write_method "$method"; then
        if [[ "$allow_write_case" != "true" ]]; then
          status="failed"
          message="write_capable_case_requires_allowWrite_true"
          failed=$((failed + 1))
          execute_case="0"
        else
          if [[ "$allow_writes" != "1" && "$(to_lower "$effective_env")" != "local" ]]; then
            status="skipped"
            message="write_cases_disabled"
            skipped=$((skipped + 1))
            execute_case="0"
          fi
        fi
      fi

      if [[ "$execute_case" == "1" ]]; then
        auth_profile=""
	        access_token_for_case=""
	        if [[ "$auth_enabled" == "1" && -n "$rest_token" ]]; then
	          auth_profile="$rest_token"
	          if ensure_auth_token "$auth_profile"; then
	            access_token_for_case="$(trim "$auth_token_value")"
	          else
	            access_token_for_case=""
	          fi
	          if [[ -z "$access_token_for_case" ]]; then
	            status="failed"
	            message="${auth_errors[$auth_profile]:-auth_login_failed(provider=${auth_provider},profile=${auth_profile})}"
	            failed=$((failed + 1))
	            execute_case="0"
	          fi
	        fi
	      fi

      if [[ "$execute_case" == "1" ]]; then
        stdout_file="$run_dir/${safe_id}.response.json"
        stderr_file="$run_dir/${safe_id}.stderr.log"

        effective_rest_config_dir="$rest_config_dir"
        if [[ -n "$access_token_for_case" ]]; then
          effective_rest_config_dir="$(ensure_access_token_rest_config_dir "$rest_config_dir")"
        fi

        cmd=("$rest_runner_abs" "--config-dir" "$effective_rest_config_dir")
        if [[ "$effective_no_history" == "true" ]]; then
          cmd+=("--no-history")
        fi
        if [[ -n "$rest_url" ]]; then
          cmd+=("--url" "$rest_url")
        elif [[ -n "$effective_env" ]]; then
          cmd+=("--env" "$effective_env")
        fi
        if [[ -n "$rest_token" && -z "$access_token_for_case" ]]; then
          cmd+=("--token" "$rest_token")
        fi
        cmd+=("${request_abs#"$repo_root"/}")

        command_snippet="$(
          runner="$rest_runner_abs"
          if [[ -n "${CODEX_HOME:-}" && "$runner" == "${CODEX_HOME%/}/"* ]]; then
            runner="\"\$CODEX_HOME/${runner#"${CODEX_HOME%/}/"}\""
          elif [[ "$runner" == "$repo_root/"* ]]; then
            runner="$(printf "%q" "${runner#"$repo_root"/}")"
          else
            runner="$(printf "%q" "$runner")"
          fi

          args="$(mask_args_for_command_snippet "${cmd[@]:1}")"
          env_prefix=""
          if [[ -n "$access_token_for_case" ]]; then
            env_prefix="ACCESS_TOKEN=REDACTED REST_TOKEN_NAME= GQL_JWT_NAME="
          fi
          if [[ -n "$args" ]]; then
            if [[ -n "$env_prefix" ]]; then
              printf "%s %s %s" "$env_prefix" "$runner" "$args"
            else
              printf "%s %s" "$runner" "$args"
            fi
          else
            if [[ -n "$env_prefix" ]]; then
              printf "%s %s" "$env_prefix" "$runner"
            else
              printf "%s" "$runner"
            fi
          fi
        )"

        if [[ -n "$access_token_for_case" ]]; then
          if REST_TOKEN_NAME="" GQL_JWT_NAME="" ACCESS_TOKEN="$access_token_for_case" "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
            rc=0
          else
            rc=$?
          fi
        else
          if "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
            rc=0
          else
            rc=$?
          fi
        fi

        if [[ "$rc" == "0" ]]; then
          status="passed"
          passed=$((passed + 1))
        else
          status="failed"
          failed=$((failed + 1))
          message="rest_runner_failed"
        fi
      fi

    elif [[ "$type" == "rest-flow" || "$type" == "rest_flow" ]]; then
      login_request="$(jq -r ".cases[$i].loginRequest // empty" "$suite_path")"
      login_request="$(trim "$login_request")"
      [[ -n "$login_request" ]] || die "rest-flow case '$id' is missing loginRequest"
      login_request_abs="$(resolve_path "$login_request")"
      [[ -f "$login_request_abs" ]] || die "rest-flow case '$id' loginRequest not found: $login_request"

      request="$(jq -r ".cases[$i].request // empty" "$suite_path")"
      request="$(trim "$request")"
      [[ -n "$request" ]] || die "rest-flow case '$id' is missing request"
      request_abs="$(resolve_path "$request")"
      [[ -f "$request_abs" ]] || die "rest-flow case '$id' request not found: $request"

      token_jq="$(jq -r ".cases[$i].tokenJq? // empty" "$suite_path")"
      token_jq="$(trim "$token_jq")"
      if [[ -z "$token_jq" ]]; then
        token_jq='.. | objects | (.accessToken? // .access_token? // .token? // empty) | select(type=="string" and length>0) | .'
      fi

      rest_config_dir="$(jq -r ".cases[$i].configDir? // empty" "$suite_path")"
      rest_config_dir="$(trim "$rest_config_dir")"
      rest_config_dir="${rest_config_dir:-$default_rest_config_dir}"

      # Avoid token profile defaults in tokens.env when using ACCESS_TOKEN flow.
      rest_config_dir="$(ensure_access_token_rest_config_dir "$rest_config_dir")"

      rest_url="$(jq -r ".cases[$i].url? // empty" "$suite_path")"
      rest_url="$(trim "$rest_url")"
      rest_url="${rest_url:-$default_rest_url}"
      if [[ -z "$rest_url" && -n "$env_rest_url" ]]; then
        rest_url="$env_rest_url"
      fi

      login_method="$(jq -r '.method // empty' "$login_request_abs")"
      login_method="$(trim "$login_method")"
      main_method="$(jq -r '.method // empty' "$request_abs")"
      main_method="$(trim "$main_method")"

      if is_rest_write_method "$login_method" || is_rest_write_method "$main_method"; then
        if [[ "$allow_write_case" != "true" ]]; then
          status="failed"
          message="write_capable_case_requires_allowWrite_true"
          failed=$((failed + 1))
          execute_case="0"
        else
          if [[ "$allow_writes" != "1" && "$(to_lower "$effective_env")" != "local" ]]; then
            status="skipped"
            message="write_cases_disabled"
            skipped=$((skipped + 1))
            execute_case="0"
          fi
        fi
      fi

      if [[ "$execute_case" == "1" ]]; then
        stderr_file="$run_dir/${safe_id}.stderr.log"
        stdout_file=""
        : >"$stderr_file"

        login_cmd=("$rest_runner_abs" "--config-dir" "$rest_config_dir")
        if [[ "$effective_no_history" == "true" ]]; then
          login_cmd+=("--no-history")
        fi
        if [[ -n "$rest_url" ]]; then
          login_cmd+=("--url" "$rest_url")
        elif [[ -n "$effective_env" ]]; then
          login_cmd+=("--env" "$effective_env")
        fi
        login_cmd+=("${login_request_abs#"$repo_root"/}")

        main_cmd=("$rest_runner_abs" "--config-dir" "$rest_config_dir")
        if [[ "$effective_no_history" == "true" ]]; then
          main_cmd+=("--no-history")
        fi
        if [[ -n "$rest_url" ]]; then
          main_cmd+=("--url" "$rest_url")
        elif [[ -n "$effective_env" ]]; then
          main_cmd+=("--env" "$effective_env")
        fi
        main_cmd+=("${request_abs#"$repo_root"/}")

        command_snippet="$(
          runner="$rest_runner_abs"
          if [[ -n "${CODEX_HOME:-}" && "$runner" == "${CODEX_HOME%/}/"* ]]; then
            runner="\"\$CODEX_HOME/${runner#"${CODEX_HOME%/}/"}\""
          elif [[ "$runner" == "$repo_root/"* ]]; then
            runner="$(printf "%q" "${runner#"$repo_root"/}")"
          else
            runner="$(printf "%q" "$runner")"
          fi

          login_args="$(mask_args_for_command_snippet "${login_cmd[@]:1}")"
          main_args="$(mask_args_for_command_snippet "${main_cmd[@]:1}")"
          token_expr_q="$(printf "%q" "$token_jq")"

          printf "ACCESS_TOKEN=\"\$("
          printf 'REST_TOKEN_NAME= ACCESS_TOKEN= %s %s | jq -r %s' "$runner" "$login_args" "$token_expr_q"
          printf ')" REST_TOKEN_NAME= %s %s' "$runner" "$main_args"
        )"

        login_stdout_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.login.json)"
        login_stderr_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.login.stderr)"
        rc=0

        if REST_TOKEN_NAME="" ACCESS_TOKEN="" "${login_cmd[@]}" >"$login_stdout_tmp" 2>"$login_stderr_tmp"; then
          rc=0
        else
          rc=$?
        fi

        if [[ "$rc" != "0" ]]; then
          status="failed"
          failed=$((failed + 1))
          message="rest_flow_login_failed"
          [[ -s "$login_stderr_tmp" ]] && cat "$login_stderr_tmp" >"$stderr_file"
        else
          token="$(
            jq -r "$token_jq" "$login_stdout_tmp" 2>/dev/null |
              head -n 1
          )"
          token="$(trim "$token")"

	          if [[ -z "$token" || "$token" == "null" ]]; then
	            status="failed"
	            failed=$((failed + 1))
	            message="rest_flow_token_extract_failed"
            {
              echo "Failed to extract token from login response."
              echo "Hint: set cases[$i].tokenJq to the token field (e.g. .accessToken)."
            } >"$stderr_file"
	          else
	            access_token_for_case="$token"
	            rc=0
	            stdout_file="$run_dir/${safe_id}.response.json"
	            if REST_TOKEN_NAME="" ACCESS_TOKEN="$token" "${main_cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
	              rc=0
            else
              rc=$?
            fi

            if [[ "$rc" == "0" ]]; then
              status="passed"
              passed=$((passed + 1))
            else
              status="failed"
              failed=$((failed + 1))
              message="rest_flow_request_failed"
            fi
          fi
        fi

        rm -f "$login_stdout_tmp" "$login_stderr_tmp" 2>/dev/null || true
      fi

    elif [[ "$type" == "graphql" ]]; then
      op="$(jq -r ".cases[$i].op // empty" "$suite_path")"
      op="$(trim "$op")"
      [[ -n "$op" ]] || die "GraphQL case '$id' is missing op"
      op_abs="$(resolve_path "$op")"
      [[ -f "$op_abs" ]] || die "GraphQL case '$id' op not found: $op"

      vars="$(jq -r ".cases[$i].vars? // empty" "$suite_path")"
      vars="$(trim "$vars")"
      vars_abs=""
      if [[ -n "$vars" ]]; then
        vars_abs="$(resolve_path "$vars")"
        [[ -f "$vars_abs" ]] || die "GraphQL case '$id' vars not found: $vars"
      fi

      gql_config_dir="$(jq -r ".cases[$i].configDir? // empty" "$suite_path")"
      gql_config_dir="$(trim "$gql_config_dir")"
      gql_config_dir="${gql_config_dir:-$default_graphql_config_dir}"

      gql_jwt="$(jq -r ".cases[$i].jwt? // empty" "$suite_path")"
      gql_jwt="$(trim "$gql_jwt")"
      gql_jwt="${gql_jwt:-$default_graphql_jwt}"

      gql_url="$(jq -r ".cases[$i].url? // empty" "$suite_path")"
      gql_url="$(trim "$gql_url")"
      gql_url="${gql_url:-$default_graphql_url}"
      if [[ -z "$gql_url" && -n "$env_gql_url" ]]; then
        gql_url="$env_gql_url"
      fi

      expect_jq="$(jq -r ".cases[$i].expect.jq? // empty" "$suite_path")"
      expect_jq="$(trim "$expect_jq")"

      gql_allow_errors="$(jq -r ".cases[$i].allowErrors? // false" "$suite_path")"
      gql_allow_errors="$(to_lower "$(trim "$gql_allow_errors")")"
      if [[ "$gql_allow_errors" != "true" && "$gql_allow_errors" != "false" ]]; then
        die "GraphQL case '$id' has invalid allowErrors (expected boolean)"
      fi
      if [[ "$gql_allow_errors" == "true" && -z "$expect_jq" ]]; then
        die "GraphQL case '$id' with allowErrors=true must set expect.jq"
      fi

      # Defensive: if a case is explicitly marked allowWrite=true, treat it as write-capable and
      # skip it unless writes are enabled (even if mutation detection fails).
      if [[ "$allow_write_case" == "true" ]]; then
        if [[ "$allow_writes" != "1" && "$(to_lower "$effective_env")" != "local" ]]; then
          status="skipped"
          message="write_cases_disabled"
          skipped=$((skipped + 1))
          execute_case="0"
        fi
      fi

      is_mutation_rc=1
      set +e
      graphql_op_is_mutation "$op_abs"
      is_mutation_rc=$?
      set -e

      if [[ "$is_mutation_rc" == "0" ]]; then
        if [[ "$allow_write_case" != "true" ]]; then
          status="failed"
          message="mutation_case_requires_allowWrite_true"
          failed=$((failed + 1))
          execute_case="0"
        else
          if [[ "$allow_writes" != "1" && "$(to_lower "$effective_env")" != "local" ]]; then
            status="skipped"
            message="write_cases_disabled"
            skipped=$((skipped + 1))
            execute_case="0"
          fi
        fi
      fi

      if [[ "$execute_case" == "1" ]]; then
        auth_profile=""
	        access_token_for_case=""
	        if [[ "$auth_enabled" == "1" && -n "$gql_jwt" ]]; then
	          auth_profile="$gql_jwt"
	          if ensure_auth_token "$auth_profile"; then
	            access_token_for_case="$(trim "$auth_token_value")"
	          else
	            access_token_for_case=""
	          fi
	          if [[ -z "$access_token_for_case" ]]; then
	            status="failed"
	            message="${auth_errors[$auth_profile]:-auth_login_failed(provider=${auth_provider},profile=${auth_profile})}"
	            failed=$((failed + 1))
	            execute_case="0"
	          fi
	        fi
	      fi

      if [[ "$execute_case" == "1" ]]; then
        stdout_file="$run_dir/${safe_id}.response.json"
        stderr_file="$run_dir/${safe_id}.stderr.log"

        effective_gql_config_dir="$gql_config_dir"
        if [[ -n "$access_token_for_case" ]]; then
          effective_gql_config_dir="$(ensure_access_token_graphql_config_dir "$gql_config_dir")"
        fi

        cmd=("$gql_runner_abs" "--config-dir" "$effective_gql_config_dir")
        if [[ "$effective_no_history" == "true" ]]; then
          cmd+=("--no-history")
        fi
        if [[ -n "$gql_url" ]]; then
          cmd+=("--url" "$gql_url")
        elif [[ -n "$effective_env" ]]; then
          cmd+=("--env" "$effective_env")
        fi
        if [[ -n "$gql_jwt" && -z "$access_token_for_case" ]]; then
          cmd+=("--jwt" "$gql_jwt")
        fi
        cmd+=("${op_abs#"$repo_root"/}")
        if [[ -n "$vars_abs" ]]; then
          cmd+=("${vars_abs#"$repo_root"/}")
        fi

        command_snippet="$(
          runner="$gql_runner_abs"
          if [[ -n "${CODEX_HOME:-}" && "$runner" == "${CODEX_HOME%/}/"* ]]; then
            runner="\"\$CODEX_HOME/${runner#"${CODEX_HOME%/}/"}\""
          elif [[ "$runner" == "$repo_root/"* ]]; then
            runner="$(printf "%q" "${runner#"$repo_root"/}")"
          else
            runner="$(printf "%q" "$runner")"
          fi

          args="$(mask_args_for_command_snippet "${cmd[@]:1}")"
          env_prefix=""
          if [[ -n "$access_token_for_case" ]]; then
            env_prefix="ACCESS_TOKEN=REDACTED REST_TOKEN_NAME= GQL_JWT_NAME="
          fi
          if [[ -n "$args" ]]; then
            if [[ -n "$env_prefix" ]]; then
              printf "%s %s %s" "$env_prefix" "$runner" "$args"
            else
              printf "%s %s" "$runner" "$args"
            fi
          else
            if [[ -n "$env_prefix" ]]; then
              printf "%s %s" "$env_prefix" "$runner"
            else
              printf "%s" "$runner"
            fi
          fi
        )"

        if [[ -n "$access_token_for_case" ]]; then
          if REST_TOKEN_NAME="" GQL_JWT_NAME="" ACCESS_TOKEN="$access_token_for_case" "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
            rc=0
          else
            rc=$?
          fi
        else
          if "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
            rc=0
          else
            rc=$?
          fi
        fi

        default_no_errors="NOT_EVALUATED"
        default_has_data="NOT_EVALUATED"
        jq_assert="NOT_EVALUATED"

        if [[ "$rc" == "0" ]]; then
          if jq -e '(.errors? | length // 0) == 0' "$stdout_file" >/dev/null 2>&1; then
            default_no_errors="passed"
          else
            default_no_errors="failed"
          fi

          if [[ "$gql_allow_errors" != "true" && -z "$expect_jq" ]]; then
            if jq -e '(.data? != null) and ((.data | type) == "object")' "$stdout_file" >/dev/null 2>&1; then
              default_has_data="passed"
            else
              default_has_data="failed"
            fi
          fi

          if [[ -n "$expect_jq" ]]; then
            if jq -e "$expect_jq" "$stdout_file" >/dev/null 2>&1; then
              jq_assert="passed"
            else
              jq_assert="failed"
            fi
          fi
        fi

        assertions_obj="$(jq -c -n --arg dne "$default_no_errors" --arg ddata "$default_has_data" --arg jqstate "$jq_assert" '
          { defaultNoErrors: $dne }
          + (if $ddata == "NOT_EVALUATED" then {} else { defaultHasData: $ddata } end)
          + (if $jqstate == "NOT_EVALUATED" then {} else { jq: $jqstate } end)
        ')"

        if [[ "$rc" != "0" ]]; then
          status="failed"
          failed=$((failed + 1))
          message="graphql_runner_failed"
        else
          if [[ "$default_no_errors" != "passed" && "$gql_allow_errors" != "true" ]]; then
            status="failed"
            failed=$((failed + 1))
            message="graphql_errors_present"
          elif [[ "$default_has_data" == "failed" ]]; then
            status="failed"
            failed=$((failed + 1))
            message="graphql_data_missing_or_null"
          elif [[ "$jq_assert" == "failed" ]]; then
            status="failed"
            failed=$((failed + 1))
            message="expect_jq_failed"
          else
            status="passed"
            passed=$((passed + 1))
          fi
        fi
      fi

	    else
	      die "Unknown case type '$type' for case '$id'"
	    fi

	    if [[ "$execute_case" == "1" ]]; then
	      cleanup_rc=0
	      set +e
	      run_case_cleanup "$i"
	      cleanup_rc=$?
	      set -e

	      if [[ "$cleanup_rc" != "0" ]]; then
	        if [[ "$status" == "passed" ]]; then
	          status="failed"
	          message="cleanup_failed"
	          passed=$((passed - 1))
	          failed=$((failed + 1))
	        fi
	      fi
	    fi

	    end_ms="$(now_ms)"
	    duration_ms=$((end_ms - start_ms))
	  fi

  stdout_rel=""
  stderr_rel=""
  if [[ -n "$stdout_file" ]]; then
    stdout_rel="${stdout_file#"$repo_root"/}"
  fi
  if [[ -n "$stderr_file" ]]; then
    stderr_rel="${stderr_file#"$repo_root"/}"
  fi

  case_obj="$(jq -c -n \
    --arg id "$id" \
    --arg type "$type" \
    --arg status "$status" \
    --arg message "$message" \
    --arg command "$command_snippet" \
    --argjson durationMs "$duration_ms" \
    --argjson tags "$tags_json" \
    --argjson assertions "$assertions_obj" \
    --arg stdoutFile "$stdout_rel" \
    --arg stderrFile "$stderr_rel" \
    '
    {
      id: $id,
      type: $type,
      status: $status,
      durationMs: $durationMs,
      tags: $tags
    }
    + (if ($command | length) > 0 then { command: $command } else {} end)
    + (if ($message | length) > 0 then { message: $message } else {} end)
    + (if ($assertions | type) == "object" and (($assertions | keys | length) > 0) then { assertions: $assertions } else {} end)
    + (if ($stdoutFile | length) > 0 then { stdoutFile: $stdoutFile } else {} end)
    + (if ($stderrFile | length) > 0 then { stderrFile: $stderrFile } else {} end)
    '
  )"

  cases_json="$(jq -c -n --argjson cur "$cases_json" --argjson item "$case_obj" '$cur + [$item]')"

  if [[ "$fail_fast" == "1" && "$status" == "failed" ]]; then
    break
  fi
done

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"

results_json="$(jq -c -n \
  --argjson version 1 \
  --arg suite "$suite_name_value" \
  --arg runId "$run_id" \
  --arg startedAt "$started_at" \
  --arg finishedAt "$finished_at" \
  --arg suiteFile "${suite_path#"$repo_root"/}" \
  --arg outputDir "${run_dir#"$repo_root"/}" \
  --argjson total "$total" \
  --argjson passed "$passed" \
  --argjson failed "$failed" \
  --argjson skipped "$skipped" \
  --argjson cases "$cases_json" \
  '
  {
    version: $version,
    suite: $suite,
    suiteFile: $suiteFile,
    runId: $runId,
    startedAt: $startedAt,
    finishedAt: $finishedAt,
    outputDir: $outputDir,
    summary: { total: $total, passed: $passed, failed: $failed, skipped: $skipped },
    cases: $cases
  }
  '
)"

if [[ -n "$out_file" ]]; then
  out_abs="$(resolve_path "$out_file")"
  mkdir -p "$(dirname "$out_abs")"
  printf "%s\n" "$results_json" >"$out_abs"
fi

if [[ -n "$junit_file" ]]; then
  junit_abs="$(resolve_path "$junit_file")"
  mkdir -p "$(dirname "$junit_abs")"
  python3 - "$results_json" "$junit_abs" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET

results = json.loads(sys.argv[1])
out_path = sys.argv[2]

suite_name = results.get("suite") or "suite"
summary = results.get("summary") or {}
cases = results.get("cases") or []

testsuite = ET.Element(
    "testsuite",
    {
        "name": suite_name,
        "tests": str(summary.get("total", len(cases))),
        "failures": str(summary.get("failed", 0)),
        "skipped": str(summary.get("skipped", 0)),
    },
)

for case in cases:
    tc = ET.SubElement(
        testsuite,
        "testcase",
        {
            "name": str(case.get("id", "case")),
            "classname": str(case.get("type", "api")),
            "time": str(max(0, int(case.get("durationMs", 0))) / 1000.0),
        },
    )
    status = case.get("status")
    message = case.get("message") or ""
    if status == "skipped":
        ET.SubElement(tc, "skipped", {"message": message})
    elif status == "failed":
        failure = ET.SubElement(tc, "failure", {"message": message or "failed"})
        detail = []
        if case.get("command"):
            detail.append(f"command: {case['command']}")
        if case.get("stdoutFile"):
            detail.append(f"stdoutFile: {case['stdoutFile']}")
        if case.get("stderrFile"):
            detail.append(f"stderrFile: {case['stderrFile']}")
        failure.text = "\n".join(detail) + ("\n" if detail else "")

tree = ET.ElementTree(testsuite)
ET.indent(tree, space="  ", level=0)  # Python 3.9+
tree.write(out_path, encoding="utf-8", xml_declaration=True)
PY
fi

printf "api-test-runner: suite=%s total=%s passed=%s failed=%s skipped=%s outputDir=%s\n" \
  "$suite_name_value" "$total" "$passed" "$failed" "$skipped" "${run_dir#"$repo_root"/}" >&2

printf "%s\n" "$results_json"

if [[ "$failed" -gt 0 ]]; then
  exit 2
fi
exit 0
