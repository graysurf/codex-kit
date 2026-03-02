# agent-workspace-launcher

This folder links to upstream `graysurf/agent-workspace-launcher`, now a host-native CLI runtime.

Upstream repository: [graysurf/agent-workspace-launcher](https://github.com/graysurf/agent-workspace-launcher)

## Command contract

- Primary command: `agent-workspace-launcher`
- Alias command: `awl`
- Runtime does not require `docker run` or a container backend for normal usage.

## Quick try (Homebrew)

```sh
brew tap sympoies/tap
brew install agent-workspace-launcher

agent-workspace-launcher --help
awl --help
```

## Quick try (from source)

```sh
git clone https://github.com/graysurf/agent-workspace-launcher.git
cd agent-workspace-launcher
cargo build --release -p agent-workspace --bin agent-workspace-launcher

./target/release/agent-workspace-launcher --help
ln -sf "$(pwd)/target/release/agent-workspace-launcher" "$HOME/.local/bin/awl"
awl --help
```

## Optional shell wrappers

If you want `aw*` shorthand aliases in your shell:

```sh
source scripts/awl.zsh   # zsh
# or
source scripts/awl.bash  # bash
```

## Lifecycle examples

```sh
agent-workspace-launcher create OWNER/REPO
agent-workspace-launcher ls
agent-workspace-launcher exec <workspace>
agent-workspace-launcher rm <workspace> --yes
```

## Migration note

Legacy `cws` wrappers are removed. Use `agent-workspace-launcher` or `awl`.
