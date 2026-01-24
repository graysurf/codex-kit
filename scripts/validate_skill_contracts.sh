#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export CODEX_HOME="${CODEX_HOME:-$repo_root}"

exec "$CODEX_HOME/skills/tools/devex/skill-governance/scripts/validate-skill-contracts.sh" "$@"
