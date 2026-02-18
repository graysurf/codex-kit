#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  codex-notify.sh [event_json]

Behavior:
  - Intended for Codex `notify` integration in config.toml.
  - Expects optional event JSON as the first argument.
  - Sends a desktop notification only for `agent-turn-complete` events.
  - Falls back to no-op when notification scripts are unavailable.

Environment:
  CODEX_NOTIFY_MESSAGE      Override message (default: "Task complete")
  CODEX_NOTIFY_LEVEL        Override level (default: success)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

event_payload="${1:-}"
if [[ -n "$event_payload" ]]; then
  case "$event_payload" in
    *agent-turn-complete*)
      ;;
    *)
      exit 0
      ;;
  esac
fi

message="${CODEX_NOTIFY_MESSAGE:-Task complete}"
level="${CODEX_NOTIFY_LEVEL:-success}"

case "$level" in
  info|success|warn|warning|error)
    ;;
  *)
    level="success"
    ;;
esac

self_path="${BASH_SOURCE[0]:-$0}"
self_dir="$(cd "$(dirname "$self_path")" >/dev/null 2>&1 && pwd -P || true)"
if [[ -z "$self_dir" ]]; then
  exit 0
fi

project_notify_abs=""
declare -a project_notify_candidates=()
agent_home="${AGENT_HOME:-${AGENTS_HOME:-}}"

project_notify_candidates+=("${self_dir%/}/project-notify.sh")

if [[ -n "$agent_home" ]]; then
  project_notify_candidates+=("${agent_home%/}/skills/tools/devex/desktop-notify/scripts/project-notify.sh")
  project_notify_candidates+=("${agent_home%/}/scripts/project-notify.sh")
fi

for candidate in "${project_notify_candidates[@]}"; do
  if [[ -f "$candidate" ]]; then
    project_notify_abs="$candidate"
    break
  fi
done

if [[ -z "$project_notify_abs" ]]; then
  exit 0
fi

if [[ -x "$project_notify_abs" ]]; then
  "$project_notify_abs" --message "$message" --level "$level" >/dev/null 2>&1 || true
else
  bash "$project_notify_abs" --message "$message" --level "$level" >/dev/null 2>&1 || true
fi
