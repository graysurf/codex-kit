# Docker Codex env (Ubuntu 24.04)

This folder defines a Linux container development environment intended to mirror the macOS `zsh-kit` + `codex-kit` workflow as closely as practical, targeting headless Ubuntu Server hosts.

## Build

Run from the repo root (Dockerfile is at the repo root).

```sh
docker build -f Dockerfile -t codex-env:linuxbrew .
```

Build-time pinning (recommended):

```sh
docker build -f Dockerfile -t codex-env:linuxbrew \
  --build-arg ZSH_KIT_REF=main \
  --build-arg CODEX_KIT_REF=main \
  .
```

Build without installing tools (fast path):

```sh
docker build -f Dockerfile -t codex-env:linuxbrew \
  --build-arg INSTALL_TOOLS=0 \
  .
```

Notes:
- Tools are installed from `zsh-kit/config/tools*.list` files (OS-specific files are picked based on `uname`).
- `visual-studio-code` cannot be installed via Linuxbrew; on Linux, `tools.optional.linux.apt.list` declares `code::code` and `INSTALL_VSCODE=1` uses the Microsoft apt repo to install it.
- `mitmproxy` is installed via `apt` on Linux (declared in `tools.optional.linux.apt.list`).
- On first container start, the entrypoint seeds `$CODEX_HOME` from the pinned `/opt/codex-kit` checkout if the volume is empty.

## Compose (recommended)

```sh
WORKSPACE_DIR=/path/to/workspace docker compose up --build
```

Run an interactive shell:

```sh
docker compose run --rm codex-env zsh -l
```

Run two isolated environments (each gets its own named volumes):

```sh
docker compose -p env-a up --build
docker compose -p env-b up --build
```

## VS Code tunnel (macOS client)

Requires `code` in the container (default when optional tools are installed).

```sh
docker compose exec -it codex-env code tunnel
```

## Tool audit (Ubuntu 24.04)

Runs `brew install -n` across brew-managed entries and prints a TSV report (also includes apt-declared entries):

```sh
docker run --rm codex-env:linuxbrew /opt/codex-env/bin/audit-tools.sh | sed -n '1,40p'
```

## Interactive shell

```sh
docker run --rm -it codex-env:linuxbrew zsh -l
```
