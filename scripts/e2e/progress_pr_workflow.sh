#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper: delegate to the canonical skill entrypoint.
resolve_root() {
  if [[ -n "${CODEX_HOME:-}" && -d "${CODEX_HOME}" ]]; then
    printf "%s" "${CODEX_HOME%/}"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  printf "%s" "$(cd "${script_dir}/../.." && pwd -P)"
}

repo_root="$(resolve_root)"
canonical="${repo_root}/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh"

if [[ ! -f "$canonical" ]]; then
  echo "error: canonical progress workflow script not found: $canonical" >&2
  exit 1
fi

exec "$canonical" "$@"
