#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex_home="${CODEX_HOME:-$repo_root}"

exec "${codex_home}/skills/tools/devex/skill-governance/scripts/validate_skill_contracts.sh" "$@"
