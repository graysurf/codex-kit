#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/semgrep-scan.sh [--profile <local|recommended|security>] [--target <path>] [--] [semgrep args...]

Runs Semgrep with repo-local rules plus selected Semgrep Registry packs.
Writes JSON output to $CODEX_HOME/out/semgrep/ and prints the JSON path to stdout.

Profiles:
  local:        .semgrep.yaml only
  recommended:  .semgrep.yaml + p/ci + p/python + p/github-actions
  security:     recommended + p/security-audit + p/secrets + p/supply-chain + p/command-injection

Examples:
  scripts/semgrep-scan.sh
  scripts/semgrep-scan.sh --profile security
  scripts/semgrep-scan.sh --target skills/automation
  scripts/semgrep-scan.sh -- --exclude tests
USAGE
}

profile="recommended"
target="."
pass_args=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --target)
      target="${2:-}"
      shift 2
      ;;
    --)
      shift
      pass_args+=("$@")
      break
      ;;
    *)
      pass_args+=("$1")
      shift
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

semgrep_bin="${repo_root}/.venv/bin/semgrep"
if [[ ! -x "$semgrep_bin" ]]; then
  semgrep_bin="$(command -v semgrep || true)"
fi
if [[ -z "$semgrep_bin" ]]; then
  echo "error: semgrep not found; install dev dependencies from requirements-dev.txt" >&2
  exit 1
fi

config="${repo_root}/.semgrep.yaml"
if [[ ! -f "$config" ]]; then
  echo "error: missing semgrep config: $config" >&2
  exit 1
fi

configs=(--config "$config")

case "$profile" in
  local)
    ;;
  recommended)
    for cfg in p/ci p/python p/github-actions; do
      configs+=(--config "$cfg")
    done
    ;;
  security)
    for cfg in p/ci p/python p/github-actions p/security-audit p/secrets p/supply-chain p/command-injection; do
      configs+=(--config "$cfg")
    done
    ;;
  *)
    echo "error: unknown --profile: $profile (expected local|recommended|security)" >&2
    exit 2
    ;;
esac

out_dir="${CODEX_HOME:-$repo_root}/out/semgrep"
mkdir -p "$out_dir"
out_json="$out_dir/semgrep-$(basename "$repo_root")-$(date +%Y%m%d-%H%M%S).json"

set +e
"$semgrep_bin" scan \
  "${configs[@]}" \
  --json \
  --metrics=off \
  --disable-version-check \
  "${pass_args[@]}" \
  "$target" >"$out_json"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "error: semgrep scan failed (exit=$rc)" >&2
  echo "note: output json (may be partial): $out_json" >&2
  exit "$rc"
fi

printf "%s\n" "$out_json"
