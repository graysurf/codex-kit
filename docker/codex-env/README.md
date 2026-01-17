# Docker Codex env (Ubuntu 24.04)

This folder defines a Linux container development environment intended to mirror the macOS `zsh-kit` + `codex-kit` workflow as closely as practical.

## Build

```sh
docker build -f docker/codex-env/Dockerfile -t codex-env:ubuntu24 .
```

Build-time pinning (recommended):

```sh
docker build -f docker/codex-env/Dockerfile -t codex-env:ubuntu24 \
  --build-arg ZSH_KIT_REF=main \
  --build-arg CODEX_KIT_REF=main \
  .
```

Build with tools preinstalled (can be slow; installs optional tools by default):

```sh
docker build -f docker/codex-env/Dockerfile -t codex-env:ubuntu24-tools \
  --build-arg INSTALL_TOOLS=1 \
  .
```

Notes:
- Tools are installed from `zsh-kit/config/tools*.list` files (OS-specific files are picked based on `uname`).
- `visual-studio-code` cannot be installed via Linuxbrew; on Linux, `tools.optional.linux.apt.list` declares `code::code` and `INSTALL_VSCODE=1` uses the Microsoft apt repo to install it.
- `mitmproxy` is installed via `apt` on Linux (declared in `tools.optional.linux.apt.list`).

## Tool audit (Ubuntu 24.04)

Runs `brew install -n` across brew-managed entries and prints a TSV report (also includes apt-declared entries):

```sh
docker run --rm codex-env:ubuntu24 /opt/codex-env/bin/audit-tools.sh | sed -n '1,40p'
```

## Interactive shell

```sh
docker run --rm -it codex-env:ubuntu24 zsh -l
```
