#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/test.sh [pytest args...]

Runs the local pytest suite using the repo venv when available.

Setup:
  .venv/bin/pip install -r requirements-dev.txt

Examples:
  scripts/test.sh
  scripts/test.sh -m script_regression -k chrome-devtools-mcp
USAGE
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

python="${repo_root}/.venv/bin/python"
if [[ ! -x "$python" ]]; then
  python="$(command -v python3 || true)"
fi
if [[ -z "$python" ]]; then
  echo "error: python not found; create a venv at .venv/ and install requirements-dev.txt" >&2
  exit 1
fi

if ! "$python" -c "import pytest" >/dev/null 2>&1; then
  echo "error: pytest not installed for: $python" >&2
  echo "hint: run: .venv/bin/pip install -r requirements-dev.txt" >&2
  exit 1
fi

export CODEX_HOME="${CODEX_HOME:-$repo_root}"
exec "$python" -m pytest "$@"
