#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(cd -- "${script_dir}/.." && pwd)"
repo_root="${AGENT_HOME:-$(cd -- "${skill_root}/../../../.." && pwd)}"

cd "$repo_root"
exec python3 "$skill_root/bin/heuristic_error_inbox.py" "$@"
