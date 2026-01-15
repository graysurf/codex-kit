#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/check.sh [--no-tests] [--] [pytest args...]

Runs repo-local lint checks (shell + python), then runs the pytest suite.

Setup:
  .venv/bin/pip install -r requirements-dev.txt

Examples:
  scripts/check.sh
  scripts/check.sh -- -m script_smoke
  scripts/check.sh --no-tests
USAGE
}

run_tests=1
pytest_args=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --no-tests)
      run_tests=0
      shift
      ;;
    --)
      shift
      pytest_args+=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

lint_rc=0
test_rc=0

set +e
scripts/lint.sh
lint_rc=$?
set -e

if [[ "$lint_rc" -ne 0 ]]; then
  echo "error: lint failed (exit=$lint_rc)" >&2
fi

if [[ "$run_tests" -eq 1 ]]; then
  set +e
  scripts/test.sh "${pytest_args[@]}"
  test_rc=$?
  set -e

  if [[ "$test_rc" -ne 0 ]]; then
    echo "error: pytest failed (exit=$test_rc)" >&2
  fi
fi

if [[ "$lint_rc" -ne 0 || "$test_rc" -ne 0 ]]; then
  exit 1
fi

