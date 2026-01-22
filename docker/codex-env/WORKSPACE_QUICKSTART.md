# Codex Workspace Quick Start

Short guide to create a new workspace and connect with VS Code.

## 1) Create a new workspace (example repo)

```sh
./docker/codex-env/bin/codex-workspace create graysurf/codex-kit --name codex-kit
```

Notes:
- `create` is an alias of `up`.

For private repos, export a token on the host before running `create`:

```sh
export GH_TOKEN=your_token
./docker/codex-env/bin/codex-workspace create graysurf/codex-kit --name codex-kit --persist-gh-token --setup-git
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

Optional: machine output (stdout-only JSON; includes `tunnel_name` + `log_path`):

```sh
./docker/codex-env/bin/codex-workspace tunnel codex-kit --detach --output json
```

If this is your first run, you need to complete GitHub device login.

When using `--detach`, the device code is written to the tunnel log. Tail the log and follow the URL:

```sh
docker exec -it codex-ws-codex-kit bash -lc 'tail -f /home/codex/.codex-env/logs/code-tunnel.log'
```

Alternatively, print a new device code by running the login command:

```sh
docker exec -it codex-ws-codex-kit code tunnel user login --provider github
```

Tip: the command/log will show a code like `ABCD-EFGH` — enter that code at https://github.com/login/device (you do not paste it back into the terminal).

Verify the tunnel is connected (expected: `"tunnel":"Connected"` and `"name":"codex-kit"`):

```sh
docker exec -it codex-ws-codex-kit code tunnel status
```

Note: the first VS Code connection may take a few minutes while the VS Code Server is downloaded inside the container (you may see "Downloading VS Code Server...").

Connect from VS Code:

1. Cmd+Shift+P -> "Remote Tunnels: Connect to Tunnel..."
2. Select `codex-kit`.

## 4) Clean up

```sh
./docker/codex-env/bin/codex-workspace stop codex-kit
./docker/codex-env/bin/codex-workspace rm codex-kit
```
