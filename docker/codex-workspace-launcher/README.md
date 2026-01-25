# codex-workspace-launcher

This folder links to the upstream `codex-workspace-launcher` project, a Docker-based launcher that creates Codex-ready workspaces (including prompts, skills, and common CLI tools) for any repository.

Upstream repository: [graysurf/codex-workspace-launcher](https://github.com/graysurf/codex-workspace-launcher)

## Quick try: launch a `codex-env` workspace

This is the fastest way to spin up a workspace container backed by `graysurf/codex-env` without cloning the launcher repository.

### zsh

```sh
mkdir -p "$HOME/.config/codex-workspace-launcher"
curl -fsSL https://raw.githubusercontent.com/graysurf/codex-workspace-launcher/main/scripts/cws.zsh \
  -o "$HOME/.config/codex-workspace-launcher/cws.zsh"
source "$HOME/.config/codex-workspace-launcher/cws.zsh"

# Create a workspace container for any repo you want to work on:
cws create OWNER/REPO

# Find the workspace name printed by `create`, or list and then exec into it:
cws ls
cws exec <name|container>
```

### bash

```sh
mkdir -p "$HOME/.config/codex-workspace-launcher"
curl -fsSL https://raw.githubusercontent.com/graysurf/codex-workspace-launcher/main/scripts/cws.bash \
  -o "$HOME/.config/codex-workspace-launcher/cws.bash"
source "$HOME/.config/codex-workspace-launcher/cws.bash"

cws create OWNER/REPO
cws ls
cws exec <name|container>
```

Cleanup:

```sh
cws rm <name|container> --yes
```
