# Codex Workspace Quick Start

Short guide to create a new workspace and connect with VS Code.

## 1) Create a new workspace (example repo)

```sh
./docker/codex-env/bin/codex-workspace up graysurf/codex-kit --name codex-kit
```

For private repos, export a token on the host before running `up`:

```sh
export GH_TOKEN=your_token
./docker/codex-env/bin/codex-workspace up graysurf/codex-kit --name codex-kit
```

Find workspace names later:

```sh
./docker/codex-env/bin/codex-workspace ls
```

## 2) Connect with VS Code (Dev Containers)

1. Install the VS Code extensions: "Docker" and "Dev Containers".
2. Cmd+Shift+P -> "Dev Containers: Attach to Running Container..."
3. Pick `codex-ws-codex-kit`.
4. Open `/work/graysurf/codex-kit`.

## 3) Connect with VS Code (Remote Tunnels)

Use a short workspace name (<= 20 chars) so the tunnel name is valid.

Start the tunnel:

```sh
./docker/codex-env/bin/codex-workspace tunnel codex-kit --detach
```

If prompted, complete the device login inside the container:

```sh
docker exec -it codex-ws-codex-kit code tunnel user login --provider github
```

Connect from VS Code:

1. Cmd+Shift+P -> "Remote Tunnels: Connect to Tunnel..."
2. Select `codex-kit`.

## 4) Clean up

```sh
./docker/codex-env/bin/codex-workspace stop codex-kit
./docker/codex-env/bin/codex-workspace rm codex-kit --volumes
```
