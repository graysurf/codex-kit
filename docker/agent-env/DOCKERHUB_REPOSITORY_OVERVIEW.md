# agent-env

`agent-env` is a development container based on **Ubuntu 24.04**. It is designed to stay close to the `zsh-kit + agent-kit` workflow and works well for AI Agent/Codex-style CLI environments.

## Quick Start

```sh
docker pull graysurf/agent-env:linuxbrew
docker run --rm -it graysurf/agent-env:linuxbrew zsh -l
```

Mount your current directory into the container:

```sh
docker run --rm -it \
  -v "$PWD":/work \
  -w /work \
  graysurf/agent-env:linuxbrew zsh -l
```

## Tags

- `latest`: latest stable release
- `linuxbrew`: recommended explicit baseline tag
- `sha-<short>`: immutable CI-generated version tag

## Key Features

- Ubuntu 24.04 + zsh + Linuxbrew
- Built-in tool installation flow with `brew -> apt -> release binary` fallback
- Uses `tini` as PID 1 (signal forwarding and zombie reaping)
- Multi-arch images: `linux/amd64`, `linux/arm64`
- Supports isolated workspaces (named volumes) via `agent-workspace`

## Build (Local)

```sh
docker build -f Dockerfile -t agent-env:linuxbrew .
```

Source checkout policy:
- `zsh-kit` and `agent-kit` are always cloned from the `main` branch during image build.
- Image defaults: `ZSH_KIT_DIR=~/.config/zsh`, `AGENT_KIT_DIR=~/.agents`.
- `AGENT_HOME` is runtime-configurable (not pinned via Dockerfile `ENV`).

Common build args:

- `INSTALL_TOOLS=0`: skip tool installation (faster builds)
- `INSTALL_OPTIONAL_TOOLS=0`: install required tools only
- `INSTALL_VSCODE=0`: skip VS Code CLI installation
- `PREFETCH_ZSH_PLUGINS=0`: skip zsh plugin prefetch
- `ZSH_PLUGIN_FETCH_RETRIES=10`: increase plugin fetch retries

## Source & Docs

- Source: [https://github.com/graysurf/agent-kit](https://github.com/graysurf/agent-kit)
- Docker docs: [https://github.com/graysurf/agent-kit/tree/main/docker/agent-env](https://github.com/graysurf/agent-kit/tree/main/docker/agent-env)
