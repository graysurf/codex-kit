# Codex Cloud Setup Runbook

Status: Active  
Last updated: 2026-02-09

Use this runbook to provision a Codex Cloud-ready Ubuntu environment aligned with the `docker/codex-env` conventions in this repository.

## Scope

This setup does the following:

- Installs base system dependencies
- Installs Homebrew and `nils-cli`
- Installs `zsh-kit` to `/opt/zsh-kit` on branch `nils-cli`
- Clones or syncs `codex-kit` to `$HOME/.codex` on branch `main`
- Applies shell environment variables (idempotent append to `$HOME/.bashrc`)
- Runs optional tool-install and zsh-plugin prefetch scripts when available
- Installs Rust toolchain (`rustup-init` preferred, `rustup` fallback)

## Prerequisites

- Ubuntu 24.04 (or compatible Debian/Ubuntu image)
- Internet access to GitHub/Homebrew endpoints
- User with `sudo` privileges (script auto-falls back if `sudo` is unavailable)

## One-Time Setup

1. Create a file named `setup-codex-cloud.sh`.
2. Paste the script below.
3. Run:

```bash
chmod +x setup-codex-cloud.sh
./setup-codex-cloud.sh
```

4. Reload your shell after completion:

```bash
source "$HOME/.bashrc"
```

```bash
#!/usr/bin/env bash
set -euo pipefail

SUDO=""
command -v sudo >/dev/null 2>&1 && SUDO="sudo"

export DEBIAN_FRONTEND=noninteractive

append_rc() { grep -qxF "$1" ~/.bashrc 2>/dev/null || echo "$1" >> ~/.bashrc; }

# --- Base deps (include sudo because install-tools.sh expects it) ---
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  ca-certificates curl file git openssh-client gnupg locales tzdata zsh \
  python3 python3-venv python3-pip build-essential procps rsync unzip xz-utils sudo \
  && $SUDO rm -rf /var/lib/apt/lists/*

# --- Homebrew ---
if [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  NONINTERACTIVE=1 /bin/bash -lc "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
/home/linuxbrew/.linuxbrew/bin/brew --version

BREW_SHELLENV='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
append_rc "$BREW_SHELLENV"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# --- nils-cli (graysurf/tap) ---
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew tap graysurf/tap
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install nils-cli

# --- zsh-kit -> /opt/zsh-kit (Method A: match Dockerfile expectations) ---
$SUDO mkdir -p /opt
if [[ -d /opt/zsh-kit/.git ]]; then
  $SUDO git -C /opt/zsh-kit fetch origin --tags
else
  $SUDO git clone https://github.com/graysurf/zsh-kit.git /opt/zsh-kit
fi
$SUDO git -C /opt/zsh-kit checkout nils-cli

# Optional: if origin/nils-cli exists, hard reset to it (keeps it up to date)
if $SUDO git -C /opt/zsh-kit show-ref --verify --quiet refs/remotes/origin/nils-cli; then
  $SUDO git -C /opt/zsh-kit reset --hard origin/nils-cli
fi

# --- codex-kit -> ~/.codex (keep synced to origin/main) ---
if [[ -d "$HOME/.codex/.git" ]]; then
  git -C "$HOME/.codex" fetch origin
  git -C "$HOME/.codex" checkout main
  git -C "$HOME/.codex" reset --hard origin/main
else
  git clone https://github.com/graysurf/codex-kit.git "$HOME/.codex"
fi

# --- Environment (aligned with Dockerfile); append to bashrc idempotently ---
append_rc 'export ZSH_KIT_DIR="/opt/zsh-kit"'
append_rc 'export CODEX_KIT_DIR="$HOME/.codex"'
append_rc 'export ZDOTDIR="/opt/zsh-kit"'
append_rc 'export ZSH_FEATURES="codex,opencode"'
append_rc 'export ZSH_BOOT_WEATHER_ENABLED=false'
append_rc 'export ZSH_BOOT_QUOTE_ENABLED=false'
append_rc 'export CODEX_HOME="$HOME/.codex"'

# Export for current run (so install-tools.sh sees them)
export ZSH_KIT_DIR="/opt/zsh-kit"
export CODEX_KIT_DIR="$HOME/.codex"
export ZDOTDIR="/opt/zsh-kit"
export ZSH_FEATURES="codex,opencode"
export ZSH_BOOT_WEATHER_ENABLED=false
export ZSH_BOOT_QUOTE_ENABLED=false
export CODEX_HOME="$HOME/.codex"

# --- Optional install / prefetch scripts (run if present & executable) ---
if [[ -x "$HOME/.codex/docker/codex-env/bin/install-tools.sh" ]]; then
  INSTALL_OPTIONAL_TOOLS=1 INSTALL_VSCODE=1 "$HOME/.codex/docker/codex-env/bin/install-tools.sh"
fi

if [[ -x "$HOME/.codex/docker/codex-env/bin/prefetch-zsh-plugins.sh" ]]; then
  ZSH_PLUGIN_FETCH_RETRIES=5 "$HOME/.codex/docker/codex-env/bin/prefetch-zsh-plugins.sh"
fi

# --- Rust (prefer rustup-init; fallback to rustup) ---
if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install rustup-init; then
  rustup-init -y
else
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install rustup
  append_rc 'export PATH="$(brew --prefix rustup)/bin:$PATH"'
  export PATH="$(brew --prefix rustup)/bin:$PATH"
  rustup default stable
fi

rustc --version && cargo --version
```

## Maintenance Script

Run this periodically (for example weekly) to update Homebrew packages and resync `codex-kit`:

```bash
#!/usr/bin/env bash
brew update && brew upgrade
git -C ~/.codex fetch origin && git -C ~/.codex checkout main && git -C ~/.codex reset --hard origin/main
```

## Verification

Run the following commands:

```bash
brew --version
nils --version || nils-cli --version
echo "$CODEX_HOME"
zsh --version
rustc --version
cargo --version
```

Expected outcome:

- All commands return successfully.
- `CODEX_HOME` prints `$HOME/.codex`.

## Usage Summary

- First-time machine setup: run the One-Time Setup script.
- Ongoing upkeep: run the Maintenance Script.
- If environment variables are not visible in current shell, run `source "$HOME/.bashrc"`.

## Operational Notes

- The setup and maintenance flows intentionally use `git reset --hard` for branch alignment.
- Any uncommitted local changes under `$HOME/.codex` or `/opt/zsh-kit` will be discarded.
- If you maintain local customizations, back up or branch before running these scripts.
