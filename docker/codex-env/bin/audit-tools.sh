#!/usr/bin/env bash
set -euo pipefail

zsh_kit_dir="${ZSH_KIT_DIR:-/opt/zsh-kit}"
zsh_kit_config_dir="${zsh_kit_dir%/}/config"

required_list="${zsh_kit_config_dir%/}/tools.list"
optional_list="${zsh_kit_config_dir%/}/tools.optional.list"

if [[ ! -f "$required_list" ]]; then
  echo "error: tools.list not found: $required_list" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "error: brew not found on PATH" >&2
  exit 1
fi

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

entries_tsv="$(
  BREW_REQUIRED_LISTS="$(printf '%s\n' "${brew_required_lists[@]}")" \
  BREW_OPTIONAL_LISTS="$(printf '%s\n' "${brew_optional_lists[@]}")" \
  APT_REQUIRED_LISTS="$(printf '%s\n' "${apt_required_lists[@]}")" \
  APT_OPTIONAL_LISTS="$(printf '%s\n' "${apt_optional_lists[@]}")" \
  python3 - <<-'PY'
	import os
	from pathlib import Path

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
	brew_optional = lists_from_env("BREW_OPTIONAL_LISTS")
	apt_required = lists_from_env("APT_REQUIRED_LISTS")
	apt_optional = lists_from_env("APT_OPTIONAL_LISTS")

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

while IFS=$'\t' read -r tool pkg_name source manager; do
  [[ -z "${tool:-}" ]] && continue

  status="unknown"
  notes="unknown"

  case "$manager" in
    brew)
      set +e
      out="$(brew install -n "$pkg_name" 2>&1)"
      rc=$?
      set -e

      status="brew:fail"
      notes="$(echo "$out" | head -n 1 | tr '\t' ' ')"

      if [[ $rc -eq 0 ]]; then
        if echo "$out" | grep -qi "Would install .*cask"; then
          status="brew:cask-dryrun"
        else
          status="brew:ok-dryrun"
        fi
        notes="ok"
      fi
      ;;
    apt)
      status="apt:declared"
      notes="apt-get install ${pkg_name}"
      ;;
  esac

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$tool" "$pkg_name" "$source" "$manager" "$status" "$notes"
done <<<"$entries_tsv"
