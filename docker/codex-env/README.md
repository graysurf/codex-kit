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

Build without optional tools (required only):

```sh
docker build -f Dockerfile -t codex-env:linuxbrew \
  --build-arg INSTALL_OPTIONAL_TOOLS=0 \
  .
```

Skip VS Code install (even when optional tools are enabled):

```sh
docker build -f Dockerfile -t codex-env:linuxbrew \
  --build-arg INSTALL_VSCODE=0 \
  .
```

Notes:
- Tools are installed from `zsh-kit/config/tools*.list` files (OS-specific files are picked based on `uname`).
- `visual-studio-code` cannot be installed via Linuxbrew; on Linux, `tools.optional.linux.apt.list` declares `code::code` and `INSTALL_VSCODE=1` uses the Microsoft apt repo to install it.
- `mitmproxy` is installed via `apt` on Linux (declared in `tools.optional.linux.apt.list`).
- On first container start, the entrypoint seeds `$CODEX_HOME` from the pinned `/opt/codex-kit` checkout if the volume is empty.

## Fallback policy

Install order is `brew` > `apt` > release binary. Linux apt fallbacks live in `zsh-kit` config:

- `tools.linux.apt.list` (required)
- `tools.optional.linux.apt.list` (optional)

If a brew install fails on Linux, add a matching apt entry or explicitly remove the tool from the brew list.

## Known deltas vs macOS

- No `g*` GNU coreutils shims are provided; use the Linux default command names.

## Publish to Docker Hub

Prereqs:
- `docker login` already completed.
- Local image exists: `codex-env:linuxbrew`.

Tag and push:

```sh
DOCKERHUB_USER=your-dockerhub-username

docker tag codex-env:linuxbrew "${DOCKERHUB_USER}/codex-env:linuxbrew"
docker tag codex-env:linuxbrew "${DOCKERHUB_USER}/codex-env:latest"

docker push "${DOCKERHUB_USER}/codex-env:linuxbrew"
docker push "${DOCKERHUB_USER}/codex-env:latest"
```

Verify pull:

```sh
docker pull "${DOCKERHUB_USER}/codex-env:linuxbrew"
```

## GitHub auth (token or SSH)

Option A: GitHub token (recommended for `gh`)

```sh
export GH_TOKEN=your_token
export CODEX_SECRET_DIR_HOST=/path/to/codex-secrets/profile

docker compose -f docker-compose.yml -f docker/codex-env/docker-compose.secrets.yml up --build
docker compose exec -it codex-env gh auth status
docker compose exec -it codex-env gh auth setup-git
```

Option B: SSH agent forwarding

```sh
export SSH_AUTH_SOCK=/path/to/ssh-agent.sock
export SSH_KNOWN_HOSTS_PATH=/path/to/known_hosts

docker compose -f docker-compose.yml -f docker/codex-env/docker-compose.ssh.yml up --build
docker compose exec -it codex-env ssh -T git@github.com
```

## Codex secrets (codex-use)

Mount the host `zsh-kit` secrets directory (contains `_codex-secret.zsh` + `*.json` profiles),
then run `codex-use <profile>` inside the container to copy a profile into the active auth file.

```sh
export CODEX_SECRET_DIR_HOST=/path/to/zsh-kit/scripts/_features/codex/secrets
docker compose -f docker-compose.yml -f docker/codex-env/docker-compose.secrets.yml up --build
docker compose exec -it codex-env zsh -lic 'codex-use personal'
```

Notes:
- The secrets directory is mounted read-write by default because `codex-use` syncs auth back to secrets.

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

## Local bind-mount mode (zsh-kit / codex-kit)

Use the override file to mount local checkouts read-only:

```sh
ZSH_KIT_DIR=/path/to/zsh-kit \
CODEX_KIT_DIR=/path/to/codex-kit \
WORKSPACE_DIR=/path/to/workspace \
docker compose -f docker-compose.yml -f docker/codex-env/docker-compose.local.yml up --build
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
