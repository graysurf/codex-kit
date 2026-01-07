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

to_env_key() {
	local s="$1"
	s="$(to_upper "$s")"
	s="$(printf "%s" "$s" | sed -E 's/[^A-Z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g')"
	printf "%s" "$s"
}

usage() {
	cat >&2 <<'EOF'
Usage:
  gql.sh [--env <name> | --url <url>] [--jwt <name>] <operation.graphql> [variables.json]

Options:
  -e, --env <name>       Use endpoint preset from endpoints.env (e.g. local/staging/dev)
  -u, --url <url>        Use an explicit GraphQL endpoint URL
      --jwt <name>        Select JWT profile name (default: "default")
      --config-dir <dir> GraphQL setup dir (searches upward for endpoints.env/jwts.env; default: operation dir or ./setup/graphql)
      --list-envs         Print available env names from endpoints.env, then exit
      --list-jwts         Print available JWT profile names from jwts(.local).env, then exit

Environment variables:
  GQL_URL        Explicit GraphQL endpoint URL (overridden by --env/--url)
  ACCESS_TOKEN   If set (and no JWT profile is selected), sends Authorization: Bearer <token>
  GQL_JWT_NAME   JWT profile name (same as --jwt)

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

	local value=""
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
	local seed=""
	local config_dir_explicit=false

	if [[ -n "$config_dir" ]]; then
		seed="$config_dir"
		config_dir_explicit=true
	elif [[ -n "$operation_file" ]]; then
		seed="$(dirname "$operation_file")"
	else
		seed="."
	fi

	local seed_abs=""
	seed_abs="$(cd "$seed" 2>/dev/null && pwd -P || true)"
	[[ -n "$seed_abs" ]] || return 1

	local found=""
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
	[[ -n "$endpoints_file" ]] || die "endpoints.env not found (expected under setup/graphql/)"
	{
		list_available_envs "$endpoints_file"
		[[ -f "$endpoints_local_file" ]] && list_available_envs "$endpoints_local_file"
		true
	} | sort -u
	exit 0
fi

if [[ "$list_jwts" == "true" ]]; then
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

jwt_name="${jwt_name_arg:-${jwt_name_env:-${jwt_name_file:-default}}}"
jwt_name="$(to_lower "$jwt_name")"

access_token=""
if [[ "$jwt_profile_selected" == "false" && -n "${ACCESS_TOKEN:-}" ]]; then
	access_token="$ACCESS_TOKEN"
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
	local login_op=""
	local login_vars=""
	local login_dir=""

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

if [[ -z "$access_token" ]]; then
	access_token="$(maybe_auto_login "$jwt_name" 2>/dev/null || true)"
fi
graphql_request "$gql_url" "$access_token" "$operation_file" "$variables_file"
