#!/usr/bin/env bash
set -euo pipefail

die() {
	echo "$1" >&2
	exit 1
}

usage() {
	cat >&2 <<'EOF'
Usage:
  rest-report.sh --case <name> --request <request.request.json> [options]

Options:
  --out <path>           Output report path (default: <repo>/docs/<YYYYMMDD-HHMM>-<case>-api-test-report.md)
  -e, --env <name>       Endpoint preset (requires project setup/rest/endpoints.env)
  -u, --url <url>        Explicit REST base URL
      --token <name>     Token profile name (passed through to rest.sh)
      --run              Execute the request via rest.sh and embed the response
      --response <file>  Use response from a file (use "-" for stdin); formatted with jq
      --no-redact        Do not redact token/password fields in request/response
      --no-command       Do not include the `rest.sh` command snippet in the report
      --project-root <p> Override project root (default: git root or current dir)
      --config-dir <dir> Passed through to rest.sh (REST setup dir containing endpoints.env/tokens.env)

Notes:
  - Requires jq for JSON formatting.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

die "Not implemented yet (PR10 scaffolding)."
