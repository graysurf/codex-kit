#!/usr/bin/env bash
set -euo pipefail

zsh_kit_dir="${ZSH_KIT_DIR:-/opt/zsh-kit}"
zsh_kit_config_dir="${zsh_kit_dir%/}/config"

required_list="${zsh_kit_config_dir%/}/tools.list"
optional_list="${zsh_kit_config_dir%/}/tools.optional.list"

install_optional_tools="${INSTALL_OPTIONAL_TOOLS:-1}"
install_vscode="${INSTALL_VSCODE:-1}"

if [[ ! -f "$required_list" ]]; then
  echo "error: tools.list not found: $required_list" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "error: brew not found on PATH" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "error: sudo not found on PATH" >&2
  exit 1
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

os="$(uname -s)"

brew_required_lists=("$required_list")
brew_optional_lists=("$optional_list")
apt_required_lists=()
apt_optional_lists=()

case "$os" in
  Linux)
    [[ -f "${zsh_kit_config_dir%/}/tools.linux.list" ]] && brew_required_lists+=("${zsh_kit_config_dir%/}/tools.linux.list")
    [[ -f "${zsh_kit_config_dir%/}/tools.optional.linux.list" ]] && brew_optional_lists+=("${zsh_kit_config_dir%/}/tools.optional.linux.list")
    [[ -f "${zsh_kit_config_dir%/}/tools.linux.apt.list" ]] && apt_required_lists+=("${zsh_kit_config_dir%/}/tools.linux.apt.list")
    [[ -f "${zsh_kit_config_dir%/}/tools.optional.linux.apt.list" ]] && apt_optional_lists+=("${zsh_kit_config_dir%/}/tools.optional.linux.apt.list")
    ;;
  Darwin)
    [[ -f "${zsh_kit_config_dir%/}/tools.macos.list" ]] && brew_required_lists+=("${zsh_kit_config_dir%/}/tools.macos.list")
    [[ -f "${zsh_kit_config_dir%/}/tools.optional.macos.list" ]] && brew_optional_lists+=("${zsh_kit_config_dir%/}/tools.optional.macos.list")
    ;;
esac

apt_updated=0
apt_update_once() {
  if [[ "$os" != "Linux" ]]; then
    return 0
  fi
  if (( apt_updated )); then
    return 0
  fi
  sudo apt-get update -y >/dev/null
  apt_updated=1
}

install_code_via_apt() {
  if [[ "$install_vscode" != "1" ]]; then
    echo "skip: vscode (INSTALL_VSCODE != 1)" >&2
    return 0
  fi

  apt_update_once

  if command -v code >/dev/null 2>&1; then
    return 0
  fi

  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  sudo chmod 0644 /etc/apt/keyrings/packages.microsoft.gpg

  local arch
  arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y code

  code --version >/dev/null
}

install_mitmproxy_via_apt() {
  apt_update_once
  sudo apt-get install -y mitmproxy
  mitmproxy --version >/dev/null
}

entries_tsv="$(
  BREW_REQUIRED_LISTS="$(printf '%s\n' "${brew_required_lists[@]}")" \
  BREW_OPTIONAL_LISTS="$(printf '%s\n' "${brew_optional_lists[@]}")" \
  APT_REQUIRED_LISTS="$(printf '%s\n' "${apt_required_lists[@]}")" \
  APT_OPTIONAL_LISTS="$(printf '%s\n' "${apt_optional_lists[@]}")" \
  python3 - "$install_optional_tools" <<-'PY'
	import sys
	import os
	from pathlib import Path

	include_optional = sys.argv[1] == "1"

	def lists_from_env(env_name: str):
	  return [Path(p) for p in os.environ.get(env_name, "").splitlines() if p.strip()]

	def iter_entries(paths, manager: str, source: str):
	  for path in paths:
	    if not path.exists():
	      continue
	    for raw in path.read_text(encoding="utf-8").splitlines():
	      line = raw.strip()
	      if not line or line.startswith("#"):
	        continue
	      parts = raw.split("::")
	      tool = (parts[0] or "").strip()
	      pkg_name = (parts[1] if len(parts) >= 2 else "").strip() or tool
	      if not tool:
	        continue
	      yield tool, pkg_name, source, manager

	brew_required = lists_from_env("BREW_REQUIRED_LISTS")
	brew_optional = lists_from_env("BREW_OPTIONAL_LISTS") if include_optional else []
	apt_required = lists_from_env("APT_REQUIRED_LISTS")
	apt_optional = lists_from_env("APT_OPTIONAL_LISTS") if include_optional else []

	seen = set()

	def emit(entries):
	  for tool, pkg, source, manager in entries:
	    if tool in seen:
	      continue
	    seen.add(tool)
	    print(f"{tool}\t{pkg}\t{source}\t{manager}")

	emit(iter_entries(brew_required, "brew", "required"))
	emit(iter_entries(brew_optional, "brew", "optional"))
	emit(iter_entries(apt_required, "apt", "required"))
	emit(iter_entries(apt_optional, "apt", "optional"))
PY
)"

missing_required=0
missing_optional=0

while IFS=$'\t' read -r tool pkg_name source manager; do
  [[ -z "${tool:-}" ]] && continue

  case "$tool" in
    code)
      if [[ "$manager" == "brew" ]]; then
        if brew install "$pkg_name"; then
          if command -v code >/dev/null 2>&1; then
            continue
          fi
        fi
      fi
      if ! install_code_via_apt; then
        echo "warn: failed to install via apt: tool=$tool pkg_name=$pkg_name source=$source" >&2
        if [[ "$source" == "required" ]]; then
          missing_required=1
        else
          missing_optional=1
        fi
      fi
      continue
      ;;
    mitmproxy)
      if ! install_mitmproxy_via_apt; then
        echo "warn: failed to install via apt: tool=$tool pkg_name=$pkg_name source=$source" >&2
        if [[ "$source" == "required" ]]; then
          missing_required=1
        else
          missing_optional=1
        fi
      fi
      continue
      ;;
  esac

  case "$manager" in
    brew)
      if brew install "$pkg_name"; then
        continue
      fi
      echo "warn: failed to install via brew: tool=$tool pkg_name=$pkg_name source=$source" >&2
      ;;
    apt)
      if [[ "$os" != "Linux" ]]; then
        echo "warn: apt entry on non-Linux host: tool=$tool pkg_name=$pkg_name source=$source" >&2
      elif ! command -v apt-get >/dev/null 2>&1; then
        echo "warn: apt-get not found for apt entry: tool=$tool pkg_name=$pkg_name source=$source" >&2
      elif command -v "$tool" >/dev/null 2>&1; then
        continue
      else
        apt_update_once
        if sudo apt-get install -y "$pkg_name"; then
          continue
        fi
        echo "warn: failed to install via apt: tool=$tool pkg_name=$pkg_name source=$source" >&2
      fi
      ;;
    *)
      echo "warn: unknown manager=$manager tool=$tool pkg_name=$pkg_name source=$source" >&2
      ;;
  esac

  if [[ "$source" == "required" ]]; then
    missing_required=1
  else
    missing_optional=1
  fi
done <<<"$entries_tsv"

if (( missing_required )); then
  echo "error: missing required tools (see warnings above)" >&2
  exit 1
fi

if (( missing_optional )); then
  echo "warning: missing optional tools (see warnings above)" >&2
fi
