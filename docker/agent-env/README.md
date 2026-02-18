# Docker Agent env (Ubuntu 24.04)

This folder defines a Linux container development environment intended to mirror the [zsh-kit](https://github.com/graysurf/zsh-kit) and [agent-kit](https://github.com/graysurf/agent-kit) workflow as closely as practical, targeting headless Ubuntu Server hosts.

## Build

Run from the repo root (Dockerfile is at the repo root).

```sh
docker build -f Dockerfile -t agent-env:linuxbrew .
```

Source checkout policy:
- `zsh-kit` and `agent-kit` are always cloned from the `main` branch during image build.
- Image defaults: `ZSH_KIT_DIR=~/.config/zsh`, `AGENT_KIT_DIR=~/.agents`.
- `AGENT_HOME` is intentionally runtime-configurable (not pinned via Dockerfile `ENV`).

Build without installing tools (fast path):

```sh
docker build -f Dockerfile -t agent-env:linuxbrew \
  --build-arg INSTALL_TOOLS=0 \
  .
```

Build without optional tools (required only):

```sh
docker build -f Dockerfile -t agent-env:linuxbrew \
  --build-arg INSTALL_OPTIONAL_TOOLS=0 \
  .
```

Skip VS Code install (even when optional tools are enabled):

```sh
docker build -f Dockerfile -t agent-env:linuxbrew \
  --build-arg INSTALL_VSCODE=0 \
  .
```

Skip Zsh plugin prefetch (useful for offline builds or flaky GitHub):

```sh
docker build -f Dockerfile -t agent-env:linuxbrew \
  --build-arg PREFETCH_ZSH_PLUGINS=0 \
  .
```

Tune plugin clone retries (default: 5):

```sh
docker build -f Dockerfile -t agent-env:linuxbrew \
  --build-arg ZSH_PLUGIN_FETCH_RETRIES=10 \
  .
```

Notes:
- Tools are installed from the zsh-kit config lists resolved by `docker/agent-env/bin/install-tools.sh` (OS-specific files are picked based on `uname`).
- The image uses `tini` as PID 1 for signal forwarding and zombie reaping.
- `visual-studio-code` cannot be installed via Linuxbrew; on Linux, `tools.optional.linux.apt.list` declares `code::code` and `INSTALL_VSCODE=1` uses the Microsoft apt repo to install it.
- `mitmproxy` is installed via `apt` on Linux (declared in `tools.optional.linux.apt.list`).
- On first container start, the entrypoint seeds `$AGENT_HOME` from the bundled agent-kit checkout (`$AGENT_KIT_DIR`) if the volume is empty.

## Fallback policy

Install order is `brew` > `apt` > release binary. Linux apt fallbacks live in the zsh-kit config lists resolved by `docker/agent-env/bin/install-tools.sh`:

- `tools.linux.apt.list` (required)
- `tools.optional.linux.apt.list` (optional)

If a brew install fails on Linux, add a matching apt entry or explicitly remove the tool from the brew list.

## Known deltas vs macOS

- No `g*` GNU coreutils shims are provided; use the Linux default command names.

## Publish to Docker Hub

Prereqs:
- `docker login` already completed.
- Local image exists: `agent-env:linuxbrew`.

CI publish (auto):
- GitHub Actions workflow: `Publish agent-env image` (runs on `docker` and supports `workflow_dispatch`).
- Requires repo secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.
- Publishes: `graysurf/agent-env:{linuxbrew,latest,sha-<short>}`.
- Multi-arch: `linux/amd64` + `linux/arm64`.
- Runner note: the GitHub-hosted ARM64 runners use partner labels like `ubuntu-24.04-arm` / `ubuntu-22.04-arm`. If you need a different label, set the GitHub Actions repo variable `ARM64_RUNNER`.

Tag and push:

```sh
DOCKERHUB_USER=your-dockerhub-username

docker tag agent-env:linuxbrew "${DOCKERHUB_USER}/agent-env:linuxbrew"
docker tag agent-env:linuxbrew "${DOCKERHUB_USER}/agent-env:latest"

docker push "${DOCKERHUB_USER}/agent-env:linuxbrew"
docker push "${DOCKERHUB_USER}/agent-env:latest"
```

Verify pull:

```sh
docker pull "${DOCKERHUB_USER}/agent-env:linuxbrew"
```

## Publish to GitHub Container Registry (GHCR)

Prereqs:
- `docker login ghcr.io` already completed (PAT with `write:packages`, or publish via GitHub Actions).
- Local image exists: `agent-env:linuxbrew`.

Tag and push:

```sh
GHCR_OWNER=your-github-username-or-org
read -s GH_TOKEN  # paste a PAT with write:packages (input hidden)
printf '%s\n' "$GH_TOKEN" | docker login ghcr.io -u "$GHCR_OWNER" --password-stdin
unset GH_TOKEN

docker tag agent-env:linuxbrew "ghcr.io/${GHCR_OWNER}/agent-env:linuxbrew"
docker tag agent-env:linuxbrew "ghcr.io/${GHCR_OWNER}/agent-env:latest"

docker push "ghcr.io/${GHCR_OWNER}/agent-env:linuxbrew"
docker push "ghcr.io/${GHCR_OWNER}/agent-env:latest"
```

Verify pull:

```sh
docker pull "ghcr.io/${GHCR_OWNER}/agent-env:linuxbrew"
```

Notes:
- The root `Dockerfile` sets OCI labels (including `org.opencontainers.image.source`) so the GHCR package can link back to this repo.
- CI publish: run the GitHub Actions workflow `Publish agent-env image` (runs on `docker` and supports `workflow_dispatch`; publishes to `ghcr.io/<owner>/agent-env`).
- Multi-arch: CI publishes `linux/amd64` + `linux/arm64` so Apple Silicon hosts can pull without `--platform`.
- Runner note: the GitHub-hosted ARM64 runners use partner labels like `ubuntu-24.04-arm` / `ubuntu-22.04-arm`. If you need a different label, set the GitHub Actions repo variable `ARM64_RUNNER`.

## Workspace launcher (isolated, no host workspace)

`docker-compose.yml` defaults to bind-mounting a host workspace into `/work` (convenient for local iteration).
If you want a fully isolated workspace that lives only inside Docker (named volumes; no host workspace folder created),
use the launcher script.

Pull the prebuilt image (skip if you already built locally):

```sh
docker pull graysurf/agent-env:linuxbrew
# or:
docker pull ghcr.io/graysurf/agent-env:linuxbrew
```

If you see `pull access denied`, the image may not be public under that namespace yet. Options:
- Run `docker login` (Docker Hub) or `docker login ghcr.io` (GHCR) and retry.
- Or use your own tag: `./docker/agent-env/bin/agent-workspace up <repo> --image DOCKERHUB_USER/agent-env:linuxbrew`

Start a new workspace from a repo input (supports `git@github.com:...` and normalizes to HTTPS clone):

```sh
./docker/agent-env/bin/agent-workspace up git@github.com:graysurf/agent-kit.git
```

Notes:
- `create` is an alias of `up` (wrappers may prefer `create`).
- Capabilities / version:

```sh
./docker/agent-env/bin/agent-workspace --version
./docker/agent-env/bin/agent-workspace capabilities
./docker/agent-env/bin/agent-workspace --supports output-json
```

- Machine-readable output: add `--output json` (stdout-only JSON; all human output goes to stderr).

```sh
./docker/agent-env/bin/agent-workspace create --no-clone --name ws-foo --output json
```

Private repos: provide a host token for the initial clone (not stored as a container env var):

```sh
read -s GH_TOKEN
export GH_TOKEN
./docker/agent-env/bin/agent-workspace up git@github.com:OWNER/REPO.git --setup-git
unset GH_TOKEN
```

Notes:
- Drop `--setup-git` if you only need the initial clone.
- `--setup-git` stores auth in the container config (gh or git helper), not as an env var.

Codex profiles (`codex-use`):

- Auto (during `up`): `./docker/agent-env/bin/agent-workspace up <repo> --secrets-dir ~/.config/codex_secrets --codex-profile personal`
- Manual: `docker exec -it <workspace> zsh -lic 'codex-use personal'`

Notes:
- Secrets are opt-in for the launcher: pass `--secrets-dir <host-path>` to mount secrets into the container.
  - Recommended host path: `~/.config/codex_secrets`
  - Default mount path: `/home/agent/codex_secrets` (override with `--secrets-mount` or `DEFAULT_SECRETS_MOUNT=<container-path>`).
  - When secrets are mounted, `agent-workspace` sets `CODEX_SECRET_DIR=<container-path>` inside the workspace.
- If you want to force-disable secrets, pass `--no-secrets` (overrides `--secrets-dir`).

Start a VS Code tunnel (macOS client attaches via VS Code Tunnels):

```sh
./docker/agent-env/bin/agent-workspace tunnel <workspace-name-or-container>
```

Machine output (requires `--detach`):

```sh
./docker/agent-env/bin/agent-workspace tunnel <workspace-name-or-container> --detach --output json
```

Common operations:

```sh
./docker/agent-env/bin/agent-workspace ls
./docker/agent-env/bin/agent-workspace shell <workspace-name-or-container>
./docker/agent-env/bin/agent-workspace stop <workspace-name-or-container>
./docker/agent-env/bin/agent-workspace rm <workspace-name-or-container>           # removes volumes by default
# ./docker/agent-env/bin/agent-workspace rm <workspace-name-or-container> --keep-volumes
```

SSH cloning:

- `agent-workspace` currently uses HTTPS cloning. If you need SSH agent forwarding, use Compose with `docker/agent-env/docker-compose.ssh.yml`.

## GitHub auth (token or SSH)

Option A: GitHub token via `gh` login (recommended for `gh`)

```sh
docker compose up --build
docker compose exec -it agent-env gh auth login
docker compose exec -it agent-env gh auth status
docker compose exec -it agent-env gh auth setup-git
```

Option B: SSH agent forwarding

```sh
export SSH_AUTH_SOCK=/path/to/ssh-agent.sock
export SSH_KNOWN_HOSTS_PATH=/path/to/known_hosts

docker compose -f docker-compose.yml -f docker/agent-env/docker-compose.ssh.yml up --build
docker compose exec -it agent-env ssh -T git@github.com
```

## Codex secrets (codex-use)

Mount the host codex secrets directory (contains `_codex-secret.zsh` + `*.json` profiles) to `/home/agent/codex_secrets`,
then run `codex-use <profile>` inside the container to copy a profile into the active auth file.

```sh
export CODEX_SECRET_DIR_HOST=~/.config/codex_secrets
docker compose -f docker-compose.yml -f docker/agent-env/docker-compose.secrets.yml up --build
docker compose exec -it agent-env zsh -lic 'codex-use personal'
```

Notes:
- `docker-compose.secrets.yml` mounts `CODEX_SECRET_DIR_HOST` at `/home/agent/codex_secrets` and sets `CODEX_SECRET_DIR` in-container.
- The secrets directory is mounted read-write by default because `codex-use` syncs auth back to secrets.

## Compose (recommended)

```sh
WORKSPACE_DIR=/path/to/workspace docker compose up --build
```

Run an interactive shell:

```sh
docker compose run --rm agent-env zsh -l
```

Run two isolated environments (each gets its own named volumes):

```sh
docker compose -p env-a up --build
docker compose -p env-b up --build
```

## Local bind-mount mode (zsh-kit / agent-kit)

Use the override file to mount local checkouts read-only:

```sh
ZSH_KIT_DIR=/path/to/zsh-kit \
AGENT_KIT_DIR=/path/to/agent-kit \
WORKSPACE_DIR=/path/to/workspace \
docker compose -f docker-compose.yml -f docker/agent-env/docker-compose.local.yml up --build
```

Notes:
- `ZSH_KIT_DIR` (host path) is mounted to `/home/agent/.config/zsh` inside the container.
- `AGENT_KIT_DIR` (host path) is mounted to `/home/agent/.agent-kit-src`, and the local override sets container `AGENT_KIT_DIR` to that mount.

## VS Code tunnel (macOS client)

Requires `code` in the container (default when optional tools are installed).

```sh
docker compose exec -it agent-env code tunnel
```

## Tool audit (Ubuntu 24.04)

Runs `brew install -n` across brew-managed entries and prints a TSV report (also includes apt-declared entries):

```sh
docker run --rm agent-env:linuxbrew /opt/agent-env/bin/audit-tools.sh | sed -n '1,40p'
```

## Interactive shell

```sh
docker run --rm -it agent-env:linuxbrew zsh -l
```
