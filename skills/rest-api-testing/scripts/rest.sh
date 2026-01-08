#!/usr/bin/env bash
set -euo pipefail

die() {
	echo "$1" >&2
	exit 1
}

usage() {
	cat >&2 <<'EOF'
Usage:
  rest.sh [--env <name> | --url <url>] [--token <name>] <request.request.json>

Options:
  -e, --env <name>       Use endpoint preset from endpoints.env (e.g. local/staging/dev)
  -u, --url <url>        Use an explicit REST base URL
      --token <name>     Select token profile name (default: "default")
      --config-dir <dir> REST setup dir (searches upward for endpoints.env/tokens.env; default: request dir or ./setup/rest)
      --no-history        Disable writing to .rest_history for this run

Environment variables:
  REST_URL        Explicit REST base URL (overridden by --env/--url)
  ACCESS_TOKEN    If set (and no token profile is selected), sends Authorization: Bearer <token>
  REST_TOKEN_NAME Token profile name (same as --token)
  REST_HISTORY    Enable/disable local command history (default: 1)

Request schema (JSON only):
  {
    "method": "GET",
    "path": "/health",
    "query": {},
    "headers": {},
    "body": {},
    "expect": { "status": 200, "jq": ".ok == true" }
  }

Notes:
  - Project presets live under: setup/rest/endpoints.env (+ optional endpoints.local.env overrides).
  - Token presets live under: setup/rest/tokens.env (+ optional tokens.local.env with real tokens).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

die "Not implemented yet (PR10 scaffolding)."
