#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: install-homebrew-nils-cli.sh

Install Homebrew if needed, then install nils-cli via Homebrew with retries.
Intended for CI bootstrap steps.
EOF
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  echo "error: unsupported arguments: $*" >&2
  echo "hint: use --help" >&2
  exit 2
fi

retry() {
  local attempts="$1"
  local delay_secs="$2"
  shift 2
  local try=1
  local status=0

  while true; do
    if "$@"; then
      return 0
    fi
    status=$?

    if (( try >= attempts )); then
      echo "error: command failed after ${attempts} attempts: $*" >&2
      return "$status"
    fi

    echo "warn: attempt ${try}/${attempts} failed (exit ${status}): $*" >&2
    sleep "$delay_secs"
    try=$((try + 1))
  done
}

install_homebrew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

resolve_brew_bin() {
  command -v brew >/dev/null 2>&1 && command -v brew && return 0
  [[ -x /opt/homebrew/bin/brew ]] && echo "/opt/homebrew/bin/brew" && return 0
  [[ -x /usr/local/bin/brew ]] && echo "/usr/local/bin/brew" && return 0
  [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && echo "/home/linuxbrew/.linuxbrew/bin/brew" && return 0
  return 1
}

if ! command -v brew >/dev/null 2>&1; then
  retry 3 10 install_homebrew
fi

BREW_BIN="$(resolve_brew_bin || true)"
if [[ -z "$BREW_BIN" ]]; then
  echo "error: brew not found after install" >&2
  exit 1
fi

BREW_PREFIX="$("$BREW_BIN" --prefix)"
export PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:${PATH}"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  {
    echo "${BREW_PREFIX}/bin"
    echo "${BREW_PREFIX}/sbin"
  } >>"$GITHUB_PATH"
fi

retry 3 5 env HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" tap graysurf/tap

if "$BREW_BIN" list nils-cli >/dev/null 2>&1; then
  echo "info: nils-cli already installed"
  exit 0
fi

retry 3 5 env HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" install nils-cli
