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
      --project-root <p> Override project root (default: git root or current dir)
      --config-dir <dir> Passed through to gql.sh (GraphQL setup dir containing endpoints.env/jwts.env)

Environment variables:
  GQL_REPORT_DIR          Default output directory when --out is not set.
                          If relative, it is resolved against <project root>.
                          Default: <project root>/docs
  GQL_ALLOW_EMPTY         Same as --allow-empty (1/true/yes).

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

has_meaningful_data_jq='
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
'

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
if [[ -n "$variables_file" ]]; then
	variables_json="$(format_json_file "$variables_file")"
fi

response_note=""
response_lang="json"
response_body="{}"
response_raw=""

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
	response_note="> TODO: run the operation and replace this section with the real response (formatted JSON)."
fi

case "${GQL_ALLOW_EMPTY:-}" in
	1|true|TRUE|yes|YES)
		allow_empty=true
		;;
esac

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

	{
		printf "# API Test Report (%s)\n\n" "$report_date"
		printf "## Test Case: %s\n\n" "$case_name"
		printf "Generated at: %s\n\n" "$generated_at"

		printf "### GraphQL Operation\n\n"
		printf '```graphql\n%s\n```\n\n' "$operation_content"

		printf "### GraphQL Operation (Variables)\n\n"
		printf '```json\n%s\n```\n\n' "$variables_json"

		printf "### Response\n\n"
		[[ -n "$response_note" ]] && printf "%s\n\n" "$response_note"
		printf '```%s\n%s\n```\n' "$response_lang" "$response_body"
	} >"$out_file"

printf "%s\n" "$out_file"
