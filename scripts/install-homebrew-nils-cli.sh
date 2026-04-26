#!/usr/bin/env bash
set -euo pipefail

MIN_NILS_CLI_VERSION="0.8.0"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: install-homebrew-nils-cli.sh

Install Homebrew if needed, then install nils-cli via Homebrew with retries.
Intended for CI bootstrap steps.

Enforces nils-cli >= ${MIN_NILS_CLI_VERSION} for both agent-docs and plan-issue;
exits non-zero if the installed binaries are older.
EOF
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  echo "error: unsupported arguments: $*" >&2
  echo "hint: use --help" >&2
  exit 2
fi

version_at_least() {
  local have="$1"
  local want="$2"
  [[ "$(printf '%s\n%s\n' "$want" "$have" | sort -V | head -n 1)" == "$want" ]]
}

extract_semver() {
  printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

assert_nils_cli_floor() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "error: $bin not found on PATH after install" >&2
    return 1
  fi
  local raw version
  raw="$("$bin" --version 2>/dev/null || true)"
  version="$(extract_semver "$raw")"
  if [[ -z "$version" ]]; then
    echo "error: unable to parse $bin version from: $raw" >&2
    return 1
  fi
  if ! version_at_least "$version" "$MIN_NILS_CLI_VERSION"; then
    echo "error: $bin $version is below required floor $MIN_NILS_CLI_VERSION; run 'brew upgrade nils-cli'" >&2
    return 1
  fi
  echo "info: $bin $version satisfies floor $MIN_NILS_CLI_VERSION"
}

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
  NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
HOMEBREW_CELLAR="$("$BREW_BIN" --cellar)"
HOMEBREW_REPOSITORY="$("$BREW_BIN" --repository)"
export HOMEBREW_PREFIX="$BREW_PREFIX"
export HOMEBREW_CELLAR
export HOMEBREW_REPOSITORY
export PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:${PATH}"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  {
    echo "${BREW_PREFIX}/bin"
    echo "${BREW_PREFIX}/sbin"
  } >>"$GITHUB_PATH"
fi

retry 3 5 env HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" tap sympoies/tap

if ! "$BREW_BIN" list nils-cli >/dev/null 2>&1; then
  retry 3 5 env HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" install nils-cli
else
  echo "info: nils-cli already installed; verifying version floor"
fi

assert_nils_cli_floor agent-docs
assert_nils_cli_floor plan-issue
