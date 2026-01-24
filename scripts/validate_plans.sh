#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex_home="${CODEX_HOME:-$repo_root}"

exec "${codex_home}/skills/workflows/plan/plan-tooling/scripts/validate_plans.sh" "$@"
