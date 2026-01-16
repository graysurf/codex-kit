#!/usr/bin/env bash
set -euo pipefail

gql_action="call"
invocation_dir="$(pwd -P 2>/dev/null || pwd)"

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

to_env_key() {
	local s="$1"
	s="$(to_upper "$s")"
	s="$(printf "%s" "$s" | sed -E 's/[^A-Z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g')"
	printf "%s" "$s"
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
			echo "gql.sh: warning: ${name} must be true|false (got: ${raw}); treating as false" >&2
			return 1
			;;
	esac
}

parse_int_default() {
	local raw="${1:-}"
	local default_value="${2:-0}"
	local min_value="${3:-}"

	raw="$(trim "$raw")"
	if [[ -z "$raw" ]]; then
		printf "%s" "$default_value"
		return 0
	fi

	if ! [[ "$raw" =~ ^[0-9]+$ ]]; then
		printf "%s" "$default_value"
		return 0
	fi

	if [[ -n "$min_value" && "$raw" -lt "$min_value" ]]; then
		printf "%s" "$min_value"
		return 0
	fi

	printf "%s" "$raw"
}

maybe_relpath() {
	local path="$1"
	local base="$2"

	if [[ "$path" == "$base" ]]; then
		printf "%s" "."
		return 0
	fi

	if [[ "$path" == "$base/"* ]]; then
		printf "%s" "${path#"$base"/}"
		return 0
	fi

	printf "%s" "$path"
}

write_vars_with_min_limit() {
	local in_file="$1"
	local out_file="$2"
	local min_limit="$3"

	if command -v jq >/dev/null 2>&1; then
		jq --argjson min "$min_limit" '
      (.. | objects | select(has("limit") and (.limit | type) == "number" and (.limit < $min)) | .limit) |= $min
    ' "$in_file" >"$out_file"
		return $?
	fi

	if command -v python3 >/dev/null 2>&1; then
		python3 - "$in_file" "$out_file" "$min_limit" <<'PY'
import json
import sys

in_file, out_file, min_limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(in_file, "r", encoding="utf-8") as f:
    data = json.load(f)

def bump_limits(value):
    if isinstance(value, dict):
        for k, v in list(value.items()):
            if k == "limit" and isinstance(v, (int, float)) and not isinstance(v, bool):
                if v < min_limit:
                    value[k] = min_limit
            bump_limits(value.get(k))
        return
    if isinstance(value, list):
        for item in value:
            bump_limits(item)
        return

bump_limits(data)
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
PY
		return $?
	fi

	return 2
}

rotate_file_keep_n() {
	local file="$1"
	local keep="${2:-5}"

	[[ -f "$file" ]] || return 0
	keep="$(parse_int_default "$keep" "5" "1")"

	local i
	for ((i=keep; i>=1; i--)); do
		local src dst
		dst="${file}.${i}"
		if [[ "$i" -eq 1 ]]; then
			src="$file"
		else
			src="${file}.$((i - 1))"
		fi

		[[ -e "$src" ]] || continue
		mv -f "$src" "$dst" 2>/dev/null || true
	done
}

append_gql_history() {
	local exit_code="$1"

	[[ "${gql_action:-call}" == "call" ]] || return 0

	if ! bool_from_env "${GQL_HISTORY_ENABLED:-}" "GQL_HISTORY_ENABLED" "true"; then
		return 0
	fi

	local op_raw="${operation_file:-}"
	[[ -n "$op_raw" ]] || return 0

	local setup="${setup_dir:-}"
	[[ -n "$setup" && -d "$setup" ]] || return 0

	local history_file="${GQL_HISTORY_FILE:-}"
	if [[ -z "$history_file" ]]; then
		history_file="$setup/.gql_history"
	elif [[ "$history_file" != /* ]]; then
		history_file="$setup/$history_file"
	fi

	local history_dir
	history_dir="$(dirname "$history_file")"
	mkdir -p "$history_dir" 2>/dev/null || true

	local lock_dir="${history_file}.lock"
	if ! mkdir "$lock_dir" 2>/dev/null; then
		return 0
	fi

	local max_mb rotate_keep
	max_mb="$(parse_int_default "${GQL_HISTORY_MAX_MB:-}" "10" "0")"
	rotate_keep="$(parse_int_default "${GQL_HISTORY_ROTATE_COUNT:-}" "5" "1")"

	if [[ "$max_mb" -gt 0 && -f "$history_file" ]]; then
		local bytes max_bytes
		bytes="$(wc -c <"$history_file" 2>/dev/null || printf "0")"
		bytes="$(parse_int_default "$bytes" "0" "0")"
		max_bytes=$((max_mb * 1024 * 1024))
		if [[ "$bytes" -ge "$max_bytes" ]]; then
			rotate_file_keep_n "$history_file" "$rotate_keep"
		fi
	fi

	local log_url=true
	if ! bool_from_env "${GQL_HISTORY_LOG_URL_ENABLED:-}" "GQL_HISTORY_LOG_URL_ENABLED" "true"; then
		log_url=false
	fi

	local stamp
	stamp="$(date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || date)"

	local setup_rel
	setup_rel="$(maybe_relpath "$setup" "$invocation_dir")"

	local endpoint_label=''
	local endpoint_value=''
	if [[ -n "${explicit_url:-}" ]]; then
		endpoint_label="url"
		endpoint_value="$explicit_url"
	elif [[ "${env_name:-}" =~ ^https?:// ]]; then
		endpoint_label="url"
		endpoint_value="$env_name"
	elif [[ -n "${env_name:-}" ]]; then
		endpoint_label="env"
		endpoint_value="$env_name"
	elif [[ -n "${gql_env_default:-}" ]]; then
		endpoint_label="env"
		endpoint_value="$gql_env_default"
	else
		endpoint_label="url"
		endpoint_value="${gql_url:-}"
	fi

	local auth_label="none"
	local jwt_for_log=''
	if [[ "${jwt_profile_selected:-false}" == "false" && -n "${ACCESS_TOKEN:-}" ]]; then
		auth_label="access_token"
	elif [[ "${jwt_profile_selected:-false}" == "true" ]]; then
		auth_label="jwt"
		jwt_for_log="${jwt_name:-}"
	fi

	local script_abs script_cmd
	script_abs="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
	script_cmd="$script_abs"
	if [[ -n "${CODEX_HOME:-}" && "$script_abs" == "${CODEX_HOME%/}/"* ]]; then
		script_cmd="\$CODEX_HOME/${script_abs#"${CODEX_HOME%/}"/}"
	fi

	local config_arg op_arg vars_arg
	config_arg="$setup"
	op_arg="$op_raw"
	vars_arg="${variables_file:-}"

	{
		printf "# %s exit=%s setup_dir=%s" "$stamp" "$exit_code" "$setup_rel"
		if [[ -n "$endpoint_label" ]]; then
			if [[ "$endpoint_label" == "url" && "$log_url" == "false" ]]; then
				printf " url=<omitted>"
			else
				printf " %s=%s" "$endpoint_label" "$endpoint_value"
			fi
		fi
		if [[ "$auth_label" == "jwt" && -n "$jwt_for_log" ]]; then
			printf " jwt=%s" "$jwt_for_log"
		elif [[ "$auth_label" == "access_token" ]]; then
			printf " auth=ACCESS_TOKEN"
		fi
		printf "\n"

		printf '%s \\\n' "$script_cmd"
		printf '  --config-dir %q \\\n' "$config_arg"

		if [[ "$endpoint_label" == "env" && -n "$endpoint_value" ]]; then
			printf '  --env %q \\\n' "$endpoint_value"
		elif [[ "$endpoint_label" == "url" && -n "$endpoint_value" && "$log_url" == "true" ]]; then
			printf '  --url %q \\\n' "$endpoint_value"
		fi

		if [[ "$auth_label" == "jwt" && -n "$jwt_for_log" ]]; then
			printf '  --jwt %q \\\n' "$jwt_for_log"
		fi

		printf '  %q' "$op_arg"
		if [[ -n "$vars_arg" ]]; then
			printf ' \\\n  %q \\\n' "$vars_arg"
			printf '| jq .\n'
		else
			printf ' \\\n| jq .\n'
		fi
		printf "\n"
	} >>"$history_file"

	rmdir "$lock_dir" 2>/dev/null || true
}

on_exit() {
	local exit_code=$?
	set +e
	set +u
	[[ -n "${variables_file_request_tmp:-}" ]] && rm -f "${variables_file_request_tmp:-}" 2>/dev/null || true
	append_gql_history "$exit_code" || true
}

trap 'on_exit' EXIT

usage() {
	cat >&2 <<'EOF'
Usage:
  gql.sh [--env <name> | --url <url>] [--jwt <name>] <operation.graphql> [variables.json]

Options:
  -e, --env <name>       Use endpoint preset from endpoints.env (e.g. local/staging/dev)
  -u, --url <url>        Use an explicit GraphQL endpoint URL
      --jwt <name>        Select JWT profile name (default: from GQL_JWT_NAME; otherwise none)
      --config-dir <dir> GraphQL setup dir (searches upward for endpoints.env/jwts.env; default: operation dir or ./setup/graphql)
      --list-envs         Print available env names from endpoints.env, then exit
      --list-jwts         Print available JWT profile names from jwts(.local).env, then exit
      --no-history        Disable writing to .gql_history for this run

Environment variables:
  GQL_URL        Explicit GraphQL endpoint URL (overridden by --env/--url)
  ACCESS_TOKEN   If set (and no JWT profile is selected), sends Authorization: Bearer <token>
  GQL_JWT_NAME   JWT profile name (same as --jwt)
  GQL_VARS_MIN_LIMIT        If variables JSON contains numeric `limit` fields (including nested pagination inputs), bump them to at least N (default: 5; 0 disables)
  GQL_HISTORY_ENABLED=false          Disable local command history (default: enabled)
  GQL_HISTORY_FILE         Override history file path (default: <setup_dir>/.gql_history)
  GQL_HISTORY_LOG_URL_ENABLED=false  Omit URL in history entries (default: included)
  GQL_HISTORY_MAX_MB       Rotate when file exceeds size in MB (default: 10; 0 disables)
  GQL_HISTORY_ROTATE_COUNT Number of rotated files to keep (default: 5)

Notes:
  - Project presets live under: setup/graphql/endpoints.env (+ optional endpoints.local.env overrides).
  - JWT presets live under: setup/graphql/jwts.env (+ optional jwts.local.env with real tokens).
  - If the selected JWT is missing/empty, gql.sh falls back to running login.graphql under setup/graphql/
    (supports both setup/graphql/login.graphql and setup/graphql/operations/login.graphql) to fetch a token.
  - Prefers xh or HTTPie if available; falls back to curl (requires jq).
  - Prints response body only.
EOF
}

env_name=""
explicit_url=""
jwt_name_arg=""
config_dir=""
list_envs=false
list_jwts=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		-e|--env)
			env_name="${2:-}"
			[[ -n "$env_name" ]] || die "Missing value for --env"
			shift 2
			;;
		-u|--url)
			explicit_url="${2:-}"
			[[ -n "$explicit_url" ]] || die "Missing value for --url"
			shift 2
			;;
		--jwt)
			jwt_name_arg="${2:-}"
			[[ -n "$jwt_name_arg" ]] || die "Missing value for --jwt"
			shift 2
			;;
		--config-dir)
			config_dir="${2:-}"
			[[ -n "$config_dir" ]] || die "Missing value for --config-dir"
			shift 2
			;;
		--list-envs)
			list_envs=true
			shift
			;;
		--list-jwts)
			list_jwts=true
			shift
			;;
			--no-history)
				GQL_HISTORY_ENABLED=false
				shift
				;;
		--)
			shift
			break
			;;
		-*)
			die "Unknown option: $1"
			;;
		*)
			break
			;;
	esac
done

operation_file="${1:-}"
variables_file="${2:-}"

gql_env_default=""
gql_jwt_name_default=""

list_available_envs() {
	local file="$1"
	[[ -f "$file" ]] || return 0

	while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
		raw_line="${raw_line%$'\r'}"
		local line
		line="$(trim "$raw_line")"
		[[ "$line" =~ ^(export[[:space:]]+)?GQL_URL_([A-Za-z0-9_]+)[[:space:]]*= ]] || continue
		printf "%s\n" "$(to_lower "${BASH_REMATCH[2]}")"
	done < "$file" | sort -u
}

list_available_jwts() {
	local file="$1"
	[[ -f "$file" ]] || return 0

	while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
		raw_line="${raw_line%$'\r'}"
		local line
		line="$(trim "$raw_line")"
		[[ "$line" =~ ^(export[[:space:]]+)?GQL_JWT_([A-Za-z0-9_]+)[[:space:]]*= ]] || continue
		local jwt_name
		jwt_name="$(to_lower "${BASH_REMATCH[2]}")"
		[[ "$jwt_name" == "name" ]] && continue
		printf "%s\n" "$jwt_name"
	done < "$file" | sort -u
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

resolve_setup_dir() {
	local seed=''
	local config_dir_explicit=false

	if [[ -n "$config_dir" ]]; then
		seed="$config_dir"
		config_dir_explicit=true
	elif [[ -n "$operation_file" ]]; then
		seed="$(dirname "$operation_file")"
	else
		seed="."
	fi

	local seed_abs=''
	seed_abs="$(cd "$seed" 2>/dev/null && pwd -P || true)"
	[[ -n "$seed_abs" ]] || return 1

	local found=''
	found="$(find_upwards_for_file "$seed_abs" "endpoints.env" 2>/dev/null || true)"
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

	if [[ "$config_dir_explicit" == "true" ]]; then
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
endpoints_file=""
endpoints_local_file=""

if [[ -n "$setup_dir" && -f "$setup_dir/endpoints.env" ]]; then
	endpoints_file="$setup_dir/endpoints.env"
	endpoints_local_file="$setup_dir/endpoints.local.env"
fi

if [[ -n "$setup_dir" && -d "$setup_dir" ]]; then
	setup_dir="$(cd "$setup_dir" 2>/dev/null && pwd -P || echo "$setup_dir")"
fi

jwts_file=""
jwts_local_file=""
if [[ -n "$setup_dir" ]]; then
	jwts_file="$setup_dir/jwts.env"
	jwts_local_file="$setup_dir/jwts.local.env"
elif [[ -f "setup/graphql/jwts.env" || -f "setup/graphql/jwts.local.env" ]]; then
	jwts_file="setup/graphql/jwts.env"
	jwts_local_file="setup/graphql/jwts.local.env"
fi

if [[ "$list_envs" == "true" ]]; then
	gql_action="list_envs"
	[[ -n "$endpoints_file" ]] || die "endpoints.env not found (expected under setup/graphql/)"
	{
		list_available_envs "$endpoints_file"
		[[ -f "$endpoints_local_file" ]] && list_available_envs "$endpoints_local_file"
		true
	} | sort -u
	exit 0
fi

if [[ "$list_jwts" == "true" ]]; then
	gql_action="list_jwts"
	[[ -n "$jwts_file" && -f "$jwts_file" || -n "$jwts_local_file" && -f "$jwts_local_file" ]] || die "jwts(.local).env not found (expected under setup/graphql/)"
	{
		[[ -n "$jwts_file" && -f "$jwts_file" ]] && list_available_jwts "$jwts_file"
		[[ -n "$jwts_local_file" && -f "$jwts_local_file" ]] && list_available_jwts "$jwts_local_file"
		true
	} | sort -u
	exit 0
fi

if [[ -z "$operation_file" ]]; then
	usage
	exit 1
fi

if [[ ! -f "$operation_file" ]]; then
	die "Operation file not found: $operation_file"
fi

if [[ -n "$variables_file" && ! -f "$variables_file" ]]; then
	die "Variables file not found: $variables_file"
fi

if [[ -n "$endpoints_file" ]]; then
	gql_env_default="$(read_env_var_from_files "GQL_ENV_DEFAULT" "$endpoints_file" "$endpoints_local_file" 2>/dev/null || true)"
fi

gql_url=""

if [[ -n "$explicit_url" ]]; then
	gql_url="$explicit_url"
elif [[ "$env_name" =~ ^https?:// ]]; then
	gql_url="$env_name"
elif [[ -n "$env_name" ]]; then
	[[ -n "$endpoints_file" ]] || die "endpoints.env not found (expected under setup/graphql/)"
	env_key="$(to_env_key "$env_name")"
	gql_url="$(read_env_var_from_files "GQL_URL_${env_key}" "$endpoints_file" "$endpoints_local_file" 2>/dev/null || true)"
	if [[ -z "$gql_url" ]]; then
		available_envs="$(
			{
				list_available_envs "${endpoints_file:-/dev/null}"
				[[ -f "$endpoints_local_file" ]] && list_available_envs "$endpoints_local_file"
				true
			} | tr '\n' ' '
		)"
		available_envs="$(trim "$available_envs")"
		die "Unknown --env '$env_name' (available: ${available_envs:-none})"
	fi
elif [[ -n "${GQL_URL:-}" ]]; then
	gql_url="$GQL_URL"
elif [[ -n "$gql_env_default" ]]; then
	env_key="$(to_env_key "$gql_env_default")"
	gql_url="$(read_env_var_from_files "GQL_URL_${env_key}" "$endpoints_file" "$endpoints_local_file" 2>/dev/null || true)"
	[[ -n "$gql_url" ]] || die "GQL_ENV_DEFAULT is '$gql_env_default' but no matching GQL_URL_* was found."
else
	gql_url="http://localhost:6700/graphql"
fi

if [[ -n "$jwts_file" ]]; then
	gql_jwt_name_default="$(read_env_var_from_files "GQL_JWT_NAME" "$jwts_file" "$jwts_local_file" 2>/dev/null || true)"
fi

jwt_name_env="$(trim "${GQL_JWT_NAME:-}")"
jwt_name_file="$(trim "$gql_jwt_name_default")"
jwt_profile_selected=false
if [[ -n "$jwt_name_arg" ]]; then
	jwt_profile_selected=true
elif [[ -n "$jwt_name_env" ]]; then
	jwt_profile_selected=true
elif [[ -n "$jwt_name_file" ]]; then
	jwt_profile_selected=true
fi

jwt_name=""
if [[ "$jwt_profile_selected" == "true" ]]; then
	jwt_name="${jwt_name_arg:-${jwt_name_env:-${jwt_name_file:-default}}}"
	jwt_name="$(to_lower "$jwt_name")"
fi

access_token=""
if [[ "$jwt_profile_selected" == "false" ]]; then
	if [[ -n "${ACCESS_TOKEN:-}" ]]; then
		access_token="$ACCESS_TOKEN"
	fi
else
	jwt_key="$(to_env_key "$jwt_name")"
	access_token="$(read_env_var_from_files "GQL_JWT_${jwt_key}" "$jwts_file" "$jwts_local_file" 2>/dev/null || true)"
fi

detect_client() {
	if command -v xh >/dev/null 2>&1; then
		printf "%s" "xh"
		return 0
	fi
	if command -v http >/dev/null 2>&1; then
		printf "%s" "http"
		return 0
	fi
	if command -v curl >/dev/null 2>&1; then
		printf "%s" "curl"
		return 0
	fi
	return 1
}

client="$(detect_client 2>/dev/null || true)"
[[ -n "$client" ]] || die "Missing HTTP client: xh, http, or curl is required."

abs_path() {
	local p="$1"
	local dir base
	dir="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
	base="$(basename "$p")"
	printf "%s/%s" "$dir" "$base"
}

extract_root_field_name() {
	local file="$1"
	awk '
		BEGIN { in_sel = 0 }
		{
			line = $0
			sub(/\r$/, "", line)
			sub(/^[[:space:]]+/, "", line)
			if (line ~ /^#/) next
			if (!in_sel) {
				if (index(line, "{") > 0) {
					in_sel = 1
				}
				next
			}
			if (line ~ /^$/) next
			if (line ~ /^}/) next
			if (match(line, /^[_A-Za-z][_0-9A-Za-z]*/)) {
				print substr(line, RSTART, RLENGTH)
				exit
			}
		}
	' "$file"
}

graphql_request() {
	local url="$1"
	local token="${2:-}"
	local op_file="$3"
	local vars_file="${4:-}"

	case "$client" in
		xh)
			local -a args
			args=(--check-status --pretty=none --print=b --json POST "$url")
			[[ -n "$token" ]] && args+=("Authorization:Bearer $token")
			args+=("query=@$op_file")
			[[ -n "$vars_file" ]] && args+=("variables:=@$vars_file")
			xh "${args[@]}"
			;;
		http)
			local -a args
			args=(--check-status --pretty=none --print=b --json POST "$url")
			[[ -n "$token" ]] && args+=("Authorization:Bearer $token")
			args+=("query=@$op_file")
			[[ -n "$vars_file" ]] && args+=("variables:=@$vars_file")
			http "${args[@]}"
			;;
		curl)
			command -v jq >/dev/null 2>&1 || die "curl fallback requires jq."
			local query payload
			query="$(cat "$op_file")"

			if [[ -n "$vars_file" ]]; then
				payload="$(jq -n --arg query "$query" --argjson variables "$(cat "$vars_file")" '{query:$query,variables:$variables}')"
			else
				payload="$(jq -n --arg query "$query" '{query:$query}')"
			fi

			local -a curl_args
			curl_args=(-sS -H "Content-Type: application/json")
			[[ -n "$token" ]] && curl_args+=(-H "Authorization: Bearer $token")
			local body_file status
			body_file="$(mktemp 2>/dev/null || mktemp -t gql.sh)"

			if ! status="$(curl "${curl_args[@]}" -o "$body_file" -w "%{http_code}" -d "$payload" "$url")"; then
				local rc=$?
				[[ -s "$body_file" ]] && cat "$body_file" >&2
				rm -f "$body_file"
				exit "$rc"
			fi

			if [[ ! "$status" =~ ^[0-9]{3}$ ]]; then
				[[ -s "$body_file" ]] && cat "$body_file" >&2
				rm -f "$body_file"
				die "Failed to parse HTTP status code from curl."
			fi

			if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
				[[ -s "$body_file" ]] && cat "$body_file" >&2
				rm -f "$body_file"
				die "HTTP request failed with status $status."
			fi

			cat "$body_file"
			rm -f "$body_file"
			;;
		*)
			die "Unknown HTTP client: $client"
			;;
	esac
}

maybe_auto_login() {
	[[ -n "$setup_dir" ]] || return 1

	local profile="$1"
	local login_op=''
	local login_vars=''
	local login_dir=''

	local -a candidates
	candidates=("$setup_dir" "$setup_dir/operations" "$setup_dir/ops")

	local dir
	for dir in "${candidates[@]}"; do
		[[ -d "$dir" ]] || continue
		if [[ -f "$dir/login.${profile}.graphql" ]]; then
			login_op="$dir/login.${profile}.graphql"
			login_dir="$dir"
			break
		fi
		if [[ -f "$dir/login.graphql" ]]; then
			login_op="$dir/login.graphql"
			login_dir="$dir"
			break
		fi
	done

	[[ -n "$login_op" && -n "$login_dir" ]] || return 1

	if [[ -f "$login_dir/login.${profile}.variables.local.json" ]]; then
		login_vars="$login_dir/login.${profile}.variables.local.json"
	elif [[ -f "$login_dir/login.${profile}.variables.json" ]]; then
		login_vars="$login_dir/login.${profile}.variables.json"
	elif [[ -f "$login_dir/login.variables.local.json" ]]; then
		login_vars="$login_dir/login.variables.local.json"
	elif [[ -f "$login_dir/login.variables.json" ]]; then
		login_vars="$login_dir/login.variables.json"
	fi

	local op_abs login_abs
	op_abs="$(abs_path "$operation_file" 2>/dev/null || true)"
	login_abs="$(abs_path "$login_op" 2>/dev/null || true)"
	if [[ -n "$op_abs" && -n "$login_abs" && "$op_abs" == "$login_abs" ]]; then
		return 1
	fi

	command -v jq >/dev/null 2>&1 || die "Auto-login requires jq."

	local response root_field token
	response="$(graphql_request "$gql_url" "" "$login_op" "$login_vars")"
	root_field="$(extract_root_field_name "$login_op")"
	[[ -n "$root_field" ]] || die "Failed to determine login root field from: $login_op"

	token="$(
		printf "%s" "$response" |
			jq -r --arg field "$root_field" '
        def token_string:
          select(type=="string" and length>0);
        def find_token:
          .. | objects | (.accessToken? // .token? // empty) | token_string;

        (.data[$field] // empty) as $root
        | if ($root | type) == "string" then
            $root | token_string
          else
            ($root | find_token)
          end
        | limit(1; .)
      '
	)"

	[[ -n "$token" ]] || die "Failed to extract JWT from login response (field: $root_field)."
	printf "%s" "$token"
}

	if [[ "$jwt_profile_selected" == "true" && -z "$access_token" ]]; then
		if ! access_token="$(maybe_auto_login "$jwt_name")"; then
			die "JWT profile '$jwt_name' is selected but no token was found and auto-login is not configured."
		fi
	fi

variables_file_request="$variables_file"
vars_min_limit="$(parse_int_default "${GQL_VARS_MIN_LIMIT:-}" "5" "0")"
if [[ -n "$variables_file_request" && -f "$variables_file_request" && "$vars_min_limit" -gt 0 ]]; then
	variables_file_request_tmp="$(mktemp 2>/dev/null || mktemp -t gql.vars.json)"
	rc=0
	write_vars_with_min_limit "$variables_file_request" "$variables_file_request_tmp" "$vars_min_limit" 2>/dev/null || rc=$?
	if [[ "$rc" -eq 0 ]]; then
		variables_file_request="$variables_file_request_tmp"
	elif [[ "$rc" -eq 2 ]]; then
		rm -f "$variables_file_request_tmp" 2>/dev/null || true
		variables_file_request_tmp=""
	else
		rm -f "$variables_file_request_tmp" 2>/dev/null || true
		variables_file_request_tmp=""
		die "Failed to read variables JSON: $variables_file_request"
	fi
fi

graphql_request "$gql_url" "$access_token" "$operation_file" "$variables_file_request"
