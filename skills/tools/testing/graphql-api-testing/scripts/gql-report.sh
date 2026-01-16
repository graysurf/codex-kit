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
			echo "gql-report.sh: warning: ${name} must be true|false (got: ${raw}); treating as false" >&2
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

slugify() {
	local s="$1"
	s="$(printf "%s" "$s" | tr '[:upper:]' '[:lower:]')"
	s="$(printf "%s" "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
	printf "%s" "$s"
}

usage() {
	cat >&2 <<'EOF'
Usage:
  gql-report.sh --case <name> --op <operation.graphql> [--vars <variables.json>] [options]

Options:
  --out <path>           Output report path (default: <repo>/docs/<YYYYMMDD-HHMM>-<case>-api-test-report.md)
  -e, --env <name>       Endpoint preset (requires project setup/graphql/endpoints.env)
  -u, --url <url>        Explicit GraphQL endpoint URL
      --jwt <name>       JWT profile name (passed through to gql.sh)
      --run              Execute the request via gql.sh and embed the response
      --response <file>  Use response from a file (use "-" for stdin); formatted with jq
      --allow-empty      Allow generating a report with an empty/no-data response (or as a draft without --run/--response)
      --no-redact        Do not redact token/password fields in variables/response
      --no-command       Do not include the `gql.sh` command snippet in the report
      --no-command-url   When using --url, omit the URL value in the command snippet
      --project-root <p> Override project root (default: git root or current dir)
      --config-dir <dir> Passed through to gql.sh (GraphQL setup dir containing endpoints.env/jwts.env)

Environment variables:
  GQL_REPORT_DIR          Default output directory when --out is not set.
                          If relative, it is resolved against <project root>.
                          Default: <project root>/docs
  GQL_ALLOW_EMPTY_ENABLED=true  Same as --allow-empty (default: disabled)
  GQL_VARS_MIN_LIMIT      If variables JSON contains numeric `limit` fields (including nested pagination inputs), bump them to at least N (default: 5; 0 disables)
  GQL_REPORT_INCLUDE_COMMAND_ENABLED=false  Omit the `gql.sh` command snippet in the report (default: included)
  GQL_REPORT_COMMAND_LOG_URL_ENABLED=false Omit URL value in the command snippet when --url is used (default: included)

Notes:
  - Requires jq for JSON formatting.
  - Prefers to keep secrets out of reports (redacts by default).
EOF
}

case_name=""
operation_file=""
variables_file=""
response_file=""
out_file=""
env_name=""
explicit_url=""
jwt_name=""
run_request=false
redact=true
allow_empty=false
include_command=true
include_command_url=true
project_root=""
config_dir=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		--case)
			case_name="${2:-}"
			shift 2
			;;
		--op|--operation)
			operation_file="${2:-}"
			shift 2
			;;
		--vars|--variables)
			variables_file="${2:-}"
			shift 2
			;;
		--response)
			response_file="${2:-}"
			shift 2
			;;
		--out)
			out_file="${2:-}"
			shift 2
			;;
		-e|--env)
			env_name="${2:-}"
			shift 2
			;;
			-u|--url)
				explicit_url="${2:-}"
				shift 2
				;;
			--jwt)
				jwt_name="${2:-}"
				shift 2
				;;
			--run)
				run_request=true
				shift
				;;
			--allow-empty|--expect-empty)
				allow_empty=true
				shift
				;;
		--no-redact)
			redact=false
			shift
			;;
		--no-command)
			include_command=false
			shift
			;;
		--no-command-url)
			include_command_url=false
			shift
			;;
		--redact)
			redact=true
			shift
			;;
		--project-root)
			project_root="${2:-}"
			shift 2
			;;
		--config-dir)
			config_dir="${2:-}"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			die "Unknown argument: $1"
			;;
	esac
done

[[ -n "$case_name" ]] || { usage; exit 1; }
[[ -n "$operation_file" ]] || { usage; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required."

[[ -f "$operation_file" ]] || die "Operation file not found: $operation_file"

if [[ -n "$variables_file" ]]; then
	[[ -f "$variables_file" ]] || die "Variables file not found: $variables_file"
	jq -e . "$variables_file" >/dev/null 2>&1 || die "Variables file is not valid JSON: $variables_file"
fi

if [[ "$run_request" == "true" && -n "$response_file" ]]; then
	die "Use either --run or --response, not both."
fi

if [[ -z "$project_root" ]]; then
	project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
fi

if ! bool_from_env "${GQL_REPORT_INCLUDE_COMMAND_ENABLED:-}" "GQL_REPORT_INCLUDE_COMMAND_ENABLED" "true"; then
	include_command=false
fi

if ! bool_from_env "${GQL_REPORT_COMMAND_LOG_URL_ENABLED:-}" "GQL_REPORT_COMMAND_LOG_URL_ENABLED" "true"; then
	include_command_url=false
fi

if [[ -z "$out_file" ]]; then
	stamp="$(date +%Y%m%d-%H%M)"
	case_slug="$(slugify "$case_name")"
	[[ -n "$case_slug" ]] || case_slug="case"
	report_dir="${GQL_REPORT_DIR:-}"
	if [[ -z "$report_dir" ]]; then
		report_dir="$project_root/docs"
	elif [[ "$report_dir" != /* ]]; then
		report_dir="$project_root/$report_dir"
	fi

	out_file="$report_dir/${stamp}-${case_slug}-api-test-report.md"
fi

mkdir -p "$(dirname "$out_file")"

report_date="$(date +%Y-%m-%d)"
generated_at="$(date +%Y-%m-%dT%H:%M:%S%z)"

redact_jq='
  def redact:
    (.. | objects | select(has("accessToken")) | .accessToken) |= "<REDACTED>"
    | (.. | objects | select(has("refreshToken")) | .refreshToken) |= "<REDACTED>"
    | (.. | objects | select(has("password")) | .password) |= "<REDACTED>";
  redact
'

has_meaningful_data_jq="$(
	cat <<'JQ'
  def is_meta_key($k):
    ($k | tostring | ascii_downcase) as $s
    | ($s == "__typename"
      or $s == "pageinfo"
      or $s == "totalcount"
      or $s == "count"
      or $s == "cursor"
      or $s == "edges"
      or $s == "nodes"
      or $s == "hasnextpage"
      or $s == "haspreviouspage"
      or $s == "startcursor"
      or $s == "endcursor");

  def key_for_path($p):
    if ($p | length) == 0 then
      null
    else
      ($p[-1]) as $last
      | if ($last | type) == "string" then
          $last
        elif ($last | type) == "number"
          and ($p | length) >= 2
          and ($p[-2] | type) == "string" then
          $p[-2]
        else
          null
        end
    end;

  def meaningful_scalar:
    paths(scalars) as $p
    | getpath($p) as $v
    | select($v != null)
    | key_for_path($p) as $k
    | select($k != null)
    | select((is_meta_key($k)) | not);

  (.data? // empty)
  | [ meaningful_scalar ]
  | length > 0
JQ
)"
format_json_file() {
	local file="$1"
	if [[ "$redact" == "true" ]]; then
		jq -S "$redact_jq" "$file"
	else
		jq -S . "$file"
	fi
}

format_json_stdin() {
	if [[ "$redact" == "true" ]]; then
		jq -S "$redact_jq"
	else
		jq -S .
	fi
}

variables_json="{}"
variables_note=""
if [[ -n "$variables_file" ]]; then
	vars_min_limit="$(parse_int_default "${GQL_VARS_MIN_LIMIT:-}" "5" "0")"

	if [[ "$vars_min_limit" -gt 0 ]]; then
		bump_count="$(
			jq --argjson min "$vars_min_limit" '
        [ .. | objects | .limit? | select(type == "number" and (. < $min)) ] | length
      ' "$variables_file" 2>/dev/null || printf "0"
		)"
		bump_count="$(parse_int_default "$bump_count" "0" "0")"
		if [[ "$bump_count" -gt 0 ]]; then
			variables_note="> NOTE: variables normalized: bumped ${bump_count} limit field(s) to at least ${vars_min_limit} (GQL_VARS_MIN_LIMIT)."
		fi

		variables_json="$(
			jq --argjson min "$vars_min_limit" '
        (.. | objects | select(has("limit") and (.limit | type) == "number" and (.limit < $min)) | .limit) |= $min
      ' "$variables_file" | format_json_stdin
		)"
	else
		variables_json="$(format_json_file "$variables_file")"
	fi
fi

response_note=""
response_lang="json"
response_body="{}"
response_raw=""

endpoint_note=""
if [[ -n "$explicit_url" ]]; then
	endpoint_note="Endpoint: --url ${explicit_url}"
elif [[ -n "$env_name" ]]; then
	endpoint_note="Endpoint: --env ${env_name}"
else
	endpoint_note="Endpoint: (implicit; see GQL_URL / GQL_ENV_DEFAULT)"
fi

result_note="Result: (not executed)"
if [[ "$run_request" == "true" ]]; then
	result_note="Result: PASS"
elif [[ -n "$response_file" ]]; then
	result_note="Result: (response provided; request not executed)"
fi

if [[ "$run_request" == "true" ]]; then
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	gql_sh="$script_dir/gql.sh"
	[[ -x "$gql_sh" ]] || die "gql.sh not found or not executable: $gql_sh"

		cmd=("$gql_sh")
		[[ -n "$config_dir" ]] && cmd+=(--config-dir "$config_dir")
		[[ -n "$explicit_url" ]] && cmd+=(--url "$explicit_url")
		[[ -n "$env_name" ]] && [[ -z "$explicit_url" ]] && cmd+=(--env "$env_name")
		[[ -n "$jwt_name" ]] && cmd+=(--jwt "$jwt_name")
		cmd+=("$operation_file")
		[[ -n "$variables_file" ]] && cmd+=("$variables_file")

		response_raw="$("${cmd[@]}")"

	if printf "%s" "$response_raw" | jq -e . >/dev/null 2>&1; then
		response_body="$(printf "%s" "$response_raw" | format_json_stdin)"
	else
		response_lang="text"
		response_body="$response_raw"
	fi
elif [[ -n "$response_file" ]]; then
	if [[ "$response_file" == "-" ]]; then
		response_raw="$(cat)"
	else
		[[ -f "$response_file" ]] || die "Response file not found: $response_file"
		response_raw="$(cat "$response_file")"
	fi

	if printf "%s" "$response_raw" | jq -e . >/dev/null 2>&1; then
		response_body="$(printf "%s" "$response_raw" | format_json_stdin)"
	else
		response_lang="text"
		response_body="$response_raw"
	fi
	else
		response_note="> NOTE: run the operation and replace this section with the real response (formatted JSON)."
	fi

if bool_from_env "${GQL_ALLOW_EMPTY_ENABLED:-}" "GQL_ALLOW_EMPTY_ENABLED" "false"; then
	allow_empty=true
fi

if [[ "$allow_empty" == "false" ]]; then
	if [[ "$run_request" != "true" && -z "$response_file" ]]; then
		die "Refusing to write a report without a real response. Use --run or --response (or pass --allow-empty for an intentionally empty/draft report)."
	fi

	if [[ "$response_lang" != "json" ]]; then
		die "Response is not JSON; refusing to write a no-data report. Re-run with --allow-empty if this is expected."
	fi

	printf "%s" "$response_body" | jq -e "$has_meaningful_data_jq" >/dev/null 2>&1 || die "Response appears to contain no data records; refusing to write report. Adjust query/variables to return at least one record, or pass --allow-empty if an empty result is expected."
fi

operation_content="$(cat "$operation_file")"

command_snippet=""
if [[ "$include_command" == "true" ]]; then
	op_arg="$operation_file"
	vars_arg="$variables_file"

	if [[ "$op_arg" == /* ]]; then
		op_arg="$(maybe_relpath "$op_arg" "$project_root")"
	fi
	if [[ -n "$vars_arg" && "$vars_arg" == /* ]]; then
		vars_arg="$(maybe_relpath "$vars_arg" "$project_root")"
	fi

	config_arg="$config_dir"
	if [[ -n "$config_arg" && "$config_arg" == /* ]]; then
		config_arg="$(maybe_relpath "$config_arg" "$project_root")"
	fi

		command_snippet="$(
			{
				printf '%s \\\n' "\"\$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh\""
				[[ -n "$config_arg" ]] && printf '  --config-dir %q \\\n' "$config_arg"
				if [[ -n "$explicit_url" ]]; then
					if [[ "$include_command_url" == "true" ]]; then
					printf '  --url %q \\\n' "$explicit_url"
				else
					printf '  --url %q \\\n' "<omitted>"
				fi
			fi
			[[ -n "$env_name" && -z "$explicit_url" ]] && printf '  --env %q \\\n' "$env_name"
			[[ -n "$jwt_name" ]] && printf '  --jwt %q \\\n' "$jwt_name"
			printf '  %q' "$op_arg"
			if [[ -n "$vars_arg" ]]; then
				printf ' \\\n  %q \\\n' "$vars_arg"
				printf '| jq .\n'
			else
				printf ' \\\n| jq .\n'
			fi
		} | cat
	)"
fi

	{
		printf "# API Test Report (%s)\n\n" "$report_date"
			printf "## Test Case: %s\n\n" "$case_name"
			if [[ -n "$command_snippet" ]]; then
				printf "## Command\n\n"
				printf "\`\`\`bash\n%s\n\`\`\`\n\n" "$command_snippet"
			fi
			printf "Generated at: %s\n\n" "$generated_at"

		printf "%s\n\n" "$endpoint_note"
		printf "%s\n\n" "$result_note"

			printf "### GraphQL Operation\n\n"
			printf "\`\`\`graphql\n%s\n\`\`\`\n\n" "$operation_content"

			printf "### GraphQL Operation (Variables)\n\n"
			[[ -n "$variables_note" ]] && printf "%s\n\n" "$variables_note"
			printf "\`\`\`json\n%s\n\`\`\`\n\n" "$variables_json"

			printf "### Response\n\n"
			[[ -n "$response_note" ]] && printf "%s\n\n" "$response_note"
			printf "\`\`\`%s\n%s\n\`\`\`\n" "$response_lang" "$response_body"
		} >"$out_file"

printf "%s\n" "$out_file"
