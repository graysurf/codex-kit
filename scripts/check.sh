#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/check.sh [--lint] [--contracts] [--env-bools] [--tests] [--semgrep] [--all] [--] [pytest args...]

Runs repo-local lint checks (shell + python), validates skill contracts, runs env-bools audit, optionally runs Semgrep, and runs pytest.

Setup:
  .venv/bin/pip install -r requirements-dev.txt

Examples:
  scripts/check.sh --all
  scripts/check.sh --lint
  scripts/check.sh --env-bools
  scripts/check.sh --tests -- -m script_smoke
  scripts/check.sh --semgrep
USAGE
}

run_lint=0
run_contracts=0
run_env_bools=0
run_tests=0
run_semgrep=0
seen_pytest_args=0
pytest_args=()
semgrep_summary_limit="${SEMGREP_SUMMARY_LIMIT:-5}"

semgrep_summary() {
  local json_path="${1:-}"
  local limit="${semgrep_summary_limit}"
  local python_bin="${repo_root}/.venv/bin/python"

  if [[ -z "$json_path" ]]; then
    return 0
  fi

  if [[ ! -x "$python_bin" ]]; then
    python_bin="$(command -v python3 || true)"
  fi
  if [[ -z "$python_bin" ]]; then
    echo "warning: python3 not found; skipping semgrep summary" >&2
    return 0
  fi

  "$python_bin" - "$json_path" "$limit" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    limit = int(sys.argv[2])
except Exception:
    limit = 5

try:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception as exc:
    sys.stderr.write(f"semgrep: failed to read {path}: {exc}\n")
    sys.exit(0)

results = data.get("results") or []
count = len(results)
if count == 0:
    sys.stderr.write("semgrep: 0 findings\n")
    sys.exit(0)

sys.stderr.write(f"semgrep: {count} findings (showing up to {limit})\n")
for result in results[:limit]:
    check_id = result.get("check_id") or "unknown"
    path = result.get("path") or "unknown"
    start = result.get("start") or {}
    line = start.get("line")
    location = f"{path}:{line}" if line else path
    message = (result.get("extra") or {}).get("message") or ""
    message = " ".join(message.split())
    if message:
        sys.stderr.write(f"- {check_id} {location} {message}\n")
    else:
        sys.stderr.write(f"- {check_id} {location}\n")
PY
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --lint)
      run_lint=1
      shift
      ;;
    --contracts)
      run_contracts=1
      shift
      ;;
    --env-bools)
      run_env_bools=1
      shift
      ;;
    --tests)
      run_tests=1
      shift
      ;;
    --semgrep)
      run_semgrep=1
      shift
      ;;
    --all)
      run_lint=1
      run_contracts=1
      run_env_bools=1
      run_tests=1
      run_semgrep=1
      shift
      ;;
    --)
      seen_pytest_args=1
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

if [[ "$seen_pytest_args" -eq 1 && "$run_tests" -eq 0 ]]; then
  echo "error: pytest args provided without --tests/--all" >&2
  usage >&2
  exit 2
fi

if [[ "$run_lint" -eq 0 && "$run_contracts" -eq 0 && "$run_env_bools" -eq 0 && "$run_tests" -eq 0 && "$run_semgrep" -eq 0 ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

lint_rc=0
contract_rc=0
env_bools_rc=0
semgrep_rc=0
test_rc=0

if [[ "$run_lint" -eq 1 ]]; then
  set +e
  scripts/lint.sh
  lint_rc=$?
  set -e

  if [[ "$lint_rc" -ne 0 ]]; then
    echo "error: lint failed (exit=$lint_rc)" >&2
  fi
fi

if [[ "$run_contracts" -eq 1 ]]; then
  echo "lint: validate skill contracts" >&2
  set +e
  scripts/validate_skill_contracts.sh
  contract_rc=$?
  set -e

  if [[ "$contract_rc" -ne 0 ]]; then
    echo "error: validate_skill_contracts failed (exit=$contract_rc)" >&2
  fi
fi

if [[ "$run_env_bools" -eq 1 ]]; then
  echo "lint: env bools audit" >&2
  set +e
  zsh -f scripts/audit-env-bools.zsh --check
  env_bools_rc=$?
  set -e

  if [[ "$env_bools_rc" -ne 0 ]]; then
    echo "error: env bools audit failed (exit=$env_bools_rc)" >&2
  fi
fi

if [[ "$run_semgrep" -eq 1 ]]; then
  echo "lint: semgrep scan" >&2
  set +e
  semgrep_json="$(scripts/semgrep-scan.sh)"
  semgrep_rc=$?
  set -e

  if [[ "$semgrep_rc" -ne 0 ]]; then
    echo "error: semgrep scan failed (exit=$semgrep_rc)" >&2
  else
    if [[ -n "$semgrep_json" ]]; then
      printf '%s\n' "$semgrep_json"
    fi
    semgrep_summary "$semgrep_json"
  fi
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

if [[ "$lint_rc" -ne 0 || "$contract_rc" -ne 0 || "$env_bools_rc" -ne 0 || "$semgrep_rc" -ne 0 || "$test_rc" -ne 0 ]]; then
  exit 1
fi
