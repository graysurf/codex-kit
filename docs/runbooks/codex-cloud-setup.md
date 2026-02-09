# Codex Cloud Setup Runbook (Ubuntu Minimal Binary Profile)

Status: Active  
Last updated: 2026-02-09

Use this runbook to provision a Codex Cloud Ubuntu environment with only the CLI binaries needed for agent workflows.  
This profile intentionally avoids `zsh-kit` and skips large optional bootstrap bundles (for example `nvim`).

## Dependency Sources

This runbook is derived from:

1. [CLI_TOOLS.md](../../CLI_TOOLS.md)
2. [graysurf/nils-cli/BINARY_DEPENDENCIES.md](https://github.com/graysurf/nils-cli/blob/main/BINARY_DEPENDENCIES.md)

## Scope

This setup does the following:

- Installs Ubuntu-native binary dependencies for Codex agent and `nils-cli` workflows
- Installs Linuxbrew only to install/upgrade `nils-cli`
- Adds Ubuntu command-name compatibility links (`fdfind` -> `fd`, `batcat` -> `bat`, `git-delta` -> `delta`)
- Does not install `zsh-kit`
- Does not run `install-tools.sh` or other broad optional bundles

## Prerequisites

- Ubuntu 24.04 (or compatible Debian/Ubuntu)
- Internet access to Ubuntu package mirrors, GitHub, and Homebrew endpoints
- User with `sudo` privileges (script auto-falls back if `sudo` is unavailable)

## One-Time Setup

1. Create `setup-codex-cloud-minimal.sh`.
2. Paste the script below.
3. Run:

```bash
chmod +x setup-codex-cloud-minimal.sh
./setup-codex-cloud-minimal.sh
```

4. Reload shell startup config:

```bash
source "$HOME/.bashrc"
source "$HOME/.profile" 2>/dev/null || true
source "$HOME/.bash_profile" 2>/dev/null || true
```

```bash
#!/usr/bin/env bash
set -euo pipefail

SUDO=""
command -v sudo >/dev/null 2>&1 && SUDO="sudo"
export DEBIAN_FRONTEND=noninteractive

append_line() {
  local file="$1"
  local line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >>"$file"
}

append_shell_rc() {
  local line="$1"
  append_line "$HOME/.bashrc" "$line"
  append_line "$HOME/.profile" "$line"
  append_line "$HOME/.bash_profile" "$line"
}

resolve_brew_bin() {
  command -v brew >/dev/null 2>&1 && command -v brew && return 0
  [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && echo "/home/linuxbrew/.linuxbrew/bin/brew" && return 0
  [[ -x "$HOME/.linuxbrew/bin/brew" ]] && echo "$HOME/.linuxbrew/bin/brew" && return 0
  [[ -x /opt/homebrew/bin/brew ]] && echo "/opt/homebrew/bin/brew" && return 0
  [[ -x /usr/local/bin/brew ]] && echo "/usr/local/bin/brew" && return 0
  return 1
}

install_optional_apt() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    $SUDO apt-get install -y --no-install-recommends "$pkg"
  else
    echo "skip: apt package '$pkg' not available in current sources" >&2
  fi
}

# Ubuntu-native core binaries from CLI_TOOLS.md + BINARY_DEPENDENCIES.md
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  ca-certificates curl git file jq tree fzf ripgrep fd-find \
  imagemagick ffmpeg python3 python3-venv python3-pip \
  build-essential procps rsync unzip xz-utils tzdata

# Optional but useful binaries when available in current apt sources
for pkg in yq bat git-delta gh; do
  install_optional_apt "$pkg"
done

$SUDO rm -rf /var/lib/apt/lists/*

# Ubuntu command-name compatibility shims
mkdir -p "$HOME/.local/bin"
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi
if ! command -v delta >/dev/null 2>&1 && command -v git-delta >/dev/null 2>&1; then
  ln -sf "$(command -v git-delta)" "$HOME/.local/bin/delta"
fi
append_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'
export PATH="$HOME/.local/bin:$PATH"

# Linuxbrew bootstrap (only needed here for nils-cli)
if ! BREW_BIN="$(resolve_brew_bin)"; then
  NONINTERACTIVE=1 /bin/bash -lc "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(resolve_brew_bin)"
fi
BREW_PREFIX="$("$BREW_BIN" --prefix)"
append_shell_rc "export PATH=\"$BREW_PREFIX/bin:$BREW_PREFIX/sbin:\$PATH\""
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
append_shell_rc "eval \"\$($BREW_BIN shellenv)\""
eval "$("$BREW_BIN" shellenv)"

# nils-cli is required
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew tap graysurf/tap
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install nils-cli

# codex binary is required for codex-agent commands in nils-cli.
# Codex Cloud images normally provide it; warn if missing.
if ! command -v codex >/dev/null 2>&1; then
  echo "warn: 'codex' binary not found. Install Codex from official distribution." >&2
fi

echo "setup complete"
```

## Maintenance Script

Run this periodically (for example weekly) to keep Ubuntu packages and `nils-cli` current:

```bash
#!/usr/bin/env bash
set -euo pipefail

SUDO=""
command -v sudo >/dev/null 2>&1 && SUDO="sudo"

resolve_brew_bin() {
  command -v brew >/dev/null 2>&1 && command -v brew && return 0
  [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && echo "/home/linuxbrew/.linuxbrew/bin/brew" && return 0
  [[ -x "$HOME/.linuxbrew/bin/brew" ]] && echo "$HOME/.linuxbrew/bin/brew" && return 0
  [[ -x /opt/homebrew/bin/brew ]] && echo "/opt/homebrew/bin/brew" && return 0
  [[ -x /usr/local/bin/brew ]] && echo "/usr/local/bin/brew" && return 0
  return 1
}

$SUDO apt-get update
$SUDO apt-get upgrade -y

if BREW_BIN="$(resolve_brew_bin)"; then
  BREW_PREFIX="$("$BREW_BIN" --prefix)"
  export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
  eval "$("$BREW_BIN" shellenv)"
  brew update
  brew upgrade nils-cli || brew upgrade
fi
```

## Verification

Run:

```bash
for c in brew git rg fd jq fzf tree magick ffmpeg nils agent-docs; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "[OK]   $c -> $(command -v "$c")"
  else
    echo "[MISS] $c"
  fi
done

if command -v yq >/dev/null 2>&1; then
  echo "[OK]   yq -> $(command -v yq)"
else
  echo "[INFO] yq is optional in this profile"
fi

if command -v codex >/dev/null 2>&1; then
  echo "[OK]   codex -> $(command -v codex)"
else
  echo "[WARN] codex missing (required only for codex-agent commands)"
fi
```

Expected outcome:

- Core commands return `[OK]`.
- `nils` is available.
- `agent-docs` is available.
- `codex` is available when codex-agent commands are needed.

## Usage Summary

- First-time setup: run the One-Time Setup script.
- Ongoing upkeep: run the Maintenance Script.
- This profile is intentionally minimal and binary-focused for Codex Cloud agent execution.
