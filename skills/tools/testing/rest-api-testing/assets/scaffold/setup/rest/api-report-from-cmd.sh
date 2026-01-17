#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CODEX_HOME:-}" ]]; then
  echo "api-report-from-cmd.sh: CODEX_HOME is not set (expected a codex-kit install path)" >&2
  exit 2
fi

exec "$CODEX_HOME/commands/api-report-from-cmd" "$@"
