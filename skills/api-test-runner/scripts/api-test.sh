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

to_upper() {
  printf "%s" "$1" | tr '[:lower:]' '[:upper:]'
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
  API_TEST_ALLOW_WRITES=1  Same as --allow-writes
  API_TEST_OUTPUT_DIR      Base output dir (default: <repo>/out/api-test-runner)
  API_TEST_REST_URL        Default REST URL when suite/case omits url
  API_TEST_GQL_URL         Default GraphQL URL when suite/case omits url
  API_TEST_SUITES_DIR      Override suites dir for --suite (e.g. tests/api/suites)

Notes:
  - Requires: git, jq, python3
  - Runs from any subdir inside the repo; paths are resolved relative to repo root.
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
invocation_dir="$(pwd -P 2>/dev/null || pwd)"
cd "$repo_root"

[[ -z "$suite_name" || -z "$suite_file" ]] || die "Use only one of --suite or --suite-file"
[[ -n "$suite_name" || -n "$suite_file" ]] || die "Missing suite (use --suite or --suite-file)"

rest_runner_abs="${repo_root%/}/tests/tools/rest-api-testing/scripts/rest.sh"
gql_runner_abs="${repo_root%/}/tests/tools/graphql-api-testing/scripts/gql.sh"
if [[ ! -f "$rest_runner_abs" ]]; then
  rest_runner_abs="${repo_root%/}/skills/rest-api-testing/scripts/rest.sh"
fi
if [[ ! -f "$gql_runner_abs" ]]; then
  gql_runner_abs="${repo_root%/}/skills/graphql-api-testing/scripts/gql.sh"
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

allow_writes_env="$(to_lower "$(trim "${API_TEST_ALLOW_WRITES:-0}")")"
if [[ "$allow_writes_env" == "1" || "$allow_writes_env" == "true" || "$allow_writes_env" == "yes" ]]; then
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

# Best-effort: strip block and line comments, then inspect the first operation keyword.
text = re.sub(r"/\\*.*?\\*/", " ", text, flags=re.S)
text = re.sub(r"^\\s*#.*$", " ", text, flags=re.M)
text = re.sub(r"^\\s*//.*$", " ", text, flags=re.M)
text = text.strip()

m = re.match(r"^(query|mutation|subscription)\\b", text, flags=re.I)
if not m:
  sys.exit(1)

op = m.group(1).lower()
sys.exit(0 if op == "mutation" else 1)
PY
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
run_started_ms="$(now_ms)"

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
        stdout_file="$run_dir/${safe_id}.response.json"
        stderr_file="$run_dir/${safe_id}.stderr.log"

        cmd=("$rest_runner_abs" "--config-dir" "$rest_config_dir")
        if [[ "$effective_no_history" == "true" ]]; then
          cmd+=("--no-history")
        fi
        if [[ -n "$rest_url" ]]; then
          cmd+=("--url" "$rest_url")
        elif [[ -n "$effective_env" ]]; then
          cmd+=("--env" "$effective_env")
        fi
        if [[ -n "$rest_token" ]]; then
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

          args="$(printf "%q " "${cmd[@]:1}" | sed -E 's/[[:space:]]+$//')"
          if [[ -n "$args" ]]; then
            printf "%s %s" "$runner" "$args"
          else
            printf "%s" "$runner"
          fi
        )"

        if ! "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
          rc=$?
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

          login_args="$(printf "%q " "${login_cmd[@]:1}" | sed -E 's/[[:space:]]+$//')"
          main_args="$(printf "%q " "${main_cmd[@]:1}" | sed -E 's/[[:space:]]+$//')"
          token_expr_q="$(printf "%q" "$token_jq")"

          printf 'ACCESS_TOKEN="$('
          printf 'REST_TOKEN_NAME= ACCESS_TOKEN= %s %s | jq -r %s' "$runner" "$login_args" "$token_expr_q"
          printf ')" REST_TOKEN_NAME= %s %s' "$runner" "$main_args"
        )"

        login_stdout_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.login.json)"
        login_stderr_tmp="$(mktemp 2>/dev/null || mktemp -t api-test.login.stderr)"
        rc=0

        if ! REST_TOKEN_NAME="" ACCESS_TOKEN="" "${login_cmd[@]}" >"$login_stdout_tmp" 2>"$login_stderr_tmp"; then
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
            rc=0
            stdout_file="$run_dir/${safe_id}.response.json"
            if ! REST_TOKEN_NAME="" ACCESS_TOKEN="$token" "${main_cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
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
        stdout_file="$run_dir/${safe_id}.response.json"
        stderr_file="$run_dir/${safe_id}.stderr.log"

        cmd=("$gql_runner_abs" "--config-dir" "$gql_config_dir")
        if [[ "$effective_no_history" == "true" ]]; then
          cmd+=("--no-history")
        fi
        if [[ -n "$gql_url" ]]; then
          cmd+=("--url" "$gql_url")
        elif [[ -n "$effective_env" ]]; then
          cmd+=("--env" "$effective_env")
        fi
        if [[ -n "$gql_jwt" ]]; then
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

          args="$(printf "%q " "${cmd[@]:1}" | sed -E 's/[[:space:]]+$//')"
          if [[ -n "$args" ]]; then
            printf "%s %s" "$runner" "$args"
          else
            printf "%s" "$runner"
          fi
        )"

        if ! "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
          rc=$?
        fi

        default_no_errors="NOT_EVALUATED"
        jq_assert="NOT_EVALUATED"

        if [[ "$rc" == "0" ]]; then
          if jq -e '(.errors? | length // 0) == 0' "$stdout_file" >/dev/null 2>&1; then
            default_no_errors="passed"
          else
            default_no_errors="failed"
          fi

          if [[ -n "$expect_jq" ]]; then
            if jq -e "$expect_jq" "$stdout_file" >/dev/null 2>&1; then
              jq_assert="passed"
            else
              jq_assert="failed"
            fi
          fi
        fi

        assertions_obj="$(jq -c -n --arg dne "$default_no_errors" --arg jqstate "$jq_assert" '
          { defaultNoErrors: $dne } + (if $jqstate == "NOT_EVALUATED" then {} else { jq: $jqstate } end)
        ')"

        if [[ "$rc" != "0" ]]; then
          status="failed"
          failed=$((failed + 1))
          message="graphql_runner_failed"
        else
          if [[ "$default_no_errors" != "passed" ]]; then
            status="failed"
            failed=$((failed + 1))
            message="graphql_errors_present"
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

run_finished_ms="$(now_ms)"
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
