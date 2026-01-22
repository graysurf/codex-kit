# Docker Codex env (Ubuntu 24.04)

This folder defines a Linux container development environment intended to mirror the [zsh-kit](https://github.com/graysurf/zsh-kit) and [codex-kit](https://github.com/graysurf/codex-kit) workflow as closely as practical, targeting headless Ubuntu Server hosts.

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
- The image uses `tini` as PID 1 for signal forwarding and zombie reaping.
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

CI publish (auto):
- GitHub Actions workflow: `Publish codex-env image (Docker Hub)` (runs on `main`).
- Requires repo secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.
- Publishes: `graysurf/codex-env:{linuxbrew,latest,sha-<short>}`.
- Multi-arch: `linux/amd64` + `linux/arm64`.
- Runner note: the GitHub-hosted ARM64 runners use partner labels like `ubuntu-24.04-arm` / `ubuntu-22.04-arm`. If you need a different label, set the GitHub Actions repo variable `ARM64_RUNNER`.

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

## Publish to GitHub Container Registry (GHCR)

Prereqs:
- `docker login ghcr.io` already completed (PAT with `write:packages`, or publish via GitHub Actions).
- Local image exists: `codex-env:linuxbrew`.

Tag and push:

```sh
GHCR_OWNER=your-github-username-or-org
GH_TOKEN=your_pat_with_write_packages

echo "$GH_TOKEN" | docker login ghcr.io -u "$GHCR_OWNER" --password-stdin

docker tag codex-env:linuxbrew "ghcr.io/${GHCR_OWNER}/codex-env:linuxbrew"
docker tag codex-env:linuxbrew "ghcr.io/${GHCR_OWNER}/codex-env:latest"

docker push "ghcr.io/${GHCR_OWNER}/codex-env:linuxbrew"
docker push "ghcr.io/${GHCR_OWNER}/codex-env:latest"
```

Verify pull:

```sh
docker pull "ghcr.io/${GHCR_OWNER}/codex-env:linuxbrew"
```

Notes:
- The root `Dockerfile` sets OCI labels (including `org.opencontainers.image.source`) so the GHCR package can link back to this repo.
- CI publish: run the GitHub Actions workflow `Publish codex-env image` (publishes to `ghcr.io/<owner>/codex-env`).
- Multi-arch: CI publishes `linux/amd64` + `linux/arm64` so Apple Silicon hosts can pull without `--platform`.
- Runner note: the GitHub-hosted ARM64 runners use partner labels like `ubuntu-24.04-arm` / `ubuntu-22.04-arm`. If you need a different label, set the GitHub Actions repo variable `ARM64_RUNNER`.

## Workspace launcher (isolated, no host workspace)

`docker-compose.yml` defaults to bind-mounting a host workspace into `/work` (convenient for local iteration).
If you want a fully isolated workspace that lives only inside Docker (named volumes; no host workspace folder created),
use the launcher script.

Pull the prebuilt image (skip if you already built locally):

```sh
docker pull graysurf/codex-env:linuxbrew
# or:
docker pull ghcr.io/graysurf/codex-env:linuxbrew
```

If you see `pull access denied`, the image may not be public under that namespace yet. Options:
- Run `docker login` (Docker Hub) or `docker login ghcr.io` (GHCR) and retry.
- Or use your own tag: `./docker/codex-env/bin/codex-workspace up <repo> --image DOCKERHUB_USER/codex-env:linuxbrew`

Start a new workspace from a repo input (supports `git@github.com:...` and normalizes to HTTPS clone):

```sh
./docker/codex-env/bin/codex-workspace up git@github.com:graysurf/codex-kit.git
```

Notes:
- `create` is an alias of `up` (wrappers may prefer `create`).
- Capabilities / version:

```sh
./docker/codex-env/bin/codex-workspace --version
./docker/codex-env/bin/codex-workspace capabilities
./docker/codex-env/bin/codex-workspace --supports output-json
```

- Machine-readable output: add `--output json` (stdout-only JSON; all human output goes to stderr).

```sh
./docker/codex-env/bin/codex-workspace create --no-clone --name ws-foo --output json
```

Private repos (recommended): export a token on the host before running `up`:

```sh
export GH_TOKEN=your_token
./docker/codex-env/bin/codex-workspace up git@github.com:OWNER/REPO.git
```

Persist token-based git auth (so `git fetch/push` inside the workspace does not prompt):

```sh
export GH_TOKEN=your_token
./docker/codex-env/bin/codex-workspace up git@github.com:OWNER/REPO.git --persist-gh-token --setup-git
```

Notes:
- `--persist-gh-token` injects `GH_TOKEN`/`GITHUB_TOKEN` into the container environment (visible via `docker inspect`).
- `--setup-git` runs `gh auth setup-git` (or a fallback credential helper) inside the workspace.

Codex profiles (`codex-use`):

- Auto (during `up`): `./docker/codex-env/bin/codex-workspace up <repo> --secrets-dir ~/.config/codex_secrets --codex-profile personal`
- Manual: `docker exec -it <workspace> zsh -lic 'codex-use personal'`

Notes:
- Secrets are opt-in for the launcher: pass `--secrets-dir <host-path>` to mount secrets into the container.
  - Recommended host path: `~/.config/codex_secrets`
  - Default mount path: `/home/codex/codex_secrets` (override with `--secrets-mount` or `DEFAULT_SECRETS_MOUNT=<container-path>`).
  - When secrets are mounted, `codex-workspace` sets `CODEX_SECRET_DIR=<container-path>` inside the workspace.
- If you want to force-disable secrets, pass `--no-secrets` (overrides `--secrets-dir`).

Start a VS Code tunnel (macOS client attaches via VS Code Tunnels):

```sh
./docker/codex-env/bin/codex-workspace tunnel <workspace-name-or-container>
```

Machine output (requires `--detach`):

```sh
./docker/codex-env/bin/codex-workspace tunnel <workspace-name-or-container> --detach --output json
```

Common operations:

```sh
./docker/codex-env/bin/codex-workspace ls
./docker/codex-env/bin/codex-workspace shell <workspace-name-or-container>
./docker/codex-env/bin/codex-workspace stop <workspace-name-or-container>
./docker/codex-env/bin/codex-workspace rm <workspace-name-or-container>           # removes volumes by default
# ./docker/codex-env/bin/codex-workspace rm <workspace-name-or-container> --keep-volumes
```

SSH cloning:

- `codex-workspace` currently uses HTTPS cloning. If you need SSH agent forwarding, use Compose with `docker/codex-env/docker-compose.ssh.yml`.

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
