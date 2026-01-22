#!/usr/bin/env bash
set -euo pipefail

zsh_kit_dir="${ZSH_KIT_DIR:-/opt/zsh-kit}"
zsh_cache_dir="${ZSH_CACHE_DIR:-${zsh_kit_dir%/}/cache}"
zsh_plugins_dir="${ZSH_PLUGINS_DIR:-${zsh_kit_dir%/}/plugins}"
zsh_plugin_list_file="${ZSH_PLUGIN_LIST_FILE:-${zsh_kit_dir%/}/config/plugins.list}"

retries="${ZSH_PLUGIN_FETCH_RETRIES:-5}"
backoff_seconds="${ZSH_PLUGIN_FETCH_BACKOFF_SECONDS:-2}"

if [[ ! -f "$zsh_plugin_list_file" ]]; then
  echo "error: zsh plugin list not found: $zsh_plugin_list_file" >&2
  exit 1
fi

mkdir -p "$zsh_cache_dir" "$zsh_plugins_dir"

git_clone() {
  local git_url="$1"
  local dest_dir="$2"

  GIT_TERMINAL_PROMPT=0 \
    git -c http.version=HTTP/1.1 \
    clone --depth 1 --single-branch "$git_url" "$dest_dir"
}

update_submodules_if_present() {
  local plugin_dir="$1"
  if [[ -f "$plugin_dir/.gitmodules" ]]; then
    git -C "$plugin_dir" submodule update --init --recursive
  fi
}

line_no=0
while IFS= read -r raw || [[ -n "${raw:-}" ]]; do
  line_no=$((line_no + 1))

  line="${raw%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue

  parts=()
  mapfile -t parts <<<"${line//::/$'\n'}"

  plugin_name="${parts[0]:-}"
  plugin_name="${plugin_name#"${plugin_name%%[![:space:]]*}"}"
  plugin_name="${plugin_name%"${plugin_name##*[![:space:]]}"}"

  if [[ -z "$plugin_name" || "$plugin_name" == "." || "$plugin_name" == ".." ]]; then
    echo "error: invalid plugin name at ${zsh_plugin_list_file}:${line_no}" >&2
    exit 1
  fi
  case "$plugin_name" in
    (*/* | *[!A-Za-z0-9._-]*)
      echo "error: unsafe plugin name at ${zsh_plugin_list_file}:${line_no}: $plugin_name" >&2
      exit 1
      ;;
  esac

  git_url=""
  for part in "${parts[@]:1}"; do
    if [[ "$part" == git=* ]]; then
      git_url="${part#git=}"
    fi
  done

  if [[ -z "$git_url" ]]; then
    echo "warn: skipping plugin without git URL: $plugin_name" >&2
    continue
  fi

  plugin_path="${zsh_plugins_dir%/}/$plugin_name"

  if [[ -d "$plugin_path" && ! -d "$plugin_path/.git" ]]; then
    echo "warn: removing incomplete plugin dir: $plugin_path" >&2
    rm -rf "$plugin_path"
  fi

  if [[ -d "$plugin_path/.git" ]]; then
    continue
  fi

  attempt=1
  while (( attempt <= retries )); do
    echo "🌐 Cloning $plugin_name (attempt $attempt/$retries)" >&2
    if git_clone "$git_url" "$plugin_path"; then
      update_submodules_if_present "$plugin_path"
      break
    fi

    echo "warn: clone failed for $plugin_name; retrying..." >&2
    rm -rf "$plugin_path"
    sleep $((backoff_seconds * attempt))
    attempt=$((attempt + 1))
  done

  if [[ ! -d "$plugin_path/.git" ]]; then
    echo "error: failed to clone plugin after $retries attempts: $plugin_name" >&2
    exit 1
  fi
done <"$zsh_plugin_list_file"

date +%s > "${zsh_cache_dir%/}/plugin.timestamp"
