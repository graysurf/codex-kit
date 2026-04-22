# Zsh Shell Environment Contract

## Scope

- Canonical shell environment contract for automation and agent sessions on this machine.
- Applies when commands, tools, or workflows depend on user-provided environment variables.

## Contract

- Canonical automation shell is `zsh`.
- Assume agent-run commands may execute in non-login, non-interactive `zsh`.
- Treat `~/.zshenv` as the bootstrap entrypoint and `$ZDOTDIR/.zshenv` as the canonical home-level env entrypoint.
- Required runtime env may live in env-related files under `$ZDOTDIR/`, but it must be reachable through that `.zshenv` bootstrap chain.
- Do not rely on `.zprofile` or `.zshrc` for machine-critical env needed by automation.
- On this machine, `ZDOTDIR` is expected to resolve to `$HOME/.config/zsh`.
- Do not assume every file under `$ZDOTDIR/` is loaded automatically; only the startup files for the
  current shell mode and anything they source are in scope.

## Startup model

1. `zsh` loads `~/.zshenv` for all normal shell modes.
2. If `~/.zshenv` sets `ZDOTDIR`, it must explicitly source `$ZDOTDIR/.zshenv` when that file is the real environment entrypoint.
3. Non-login, non-interactive `zsh` should still receive all machine-critical env from that `.zshenv` chain.
4. `.zprofile` and `.zshrc` are optional interactive or login customizations only.

## Authoring rules

- Keep `.zshenv` minimal, silent, and deterministic.
- Allow exports, small path setup, and explicit `source` of other env-only files.
- Do not put prompts, banners, aliases, completion, weather, quotes, network calls, or other interactive behavior in `.zshenv`.
- If a tool must work from agents, automation, scripts, or clean `zsh -c` probes, its required env must not depend on `.zprofile` or `.zshrc`.

## Diagnosis order

1. Inspect `~/.zshenv`.
2. Inspect `$ZDOTDIR/.zshenv`.
3. Inspect env-related files under `$ZDOTDIR/` that are sourced from that bootstrap chain.
4. Verify with a clean non-login probe before blaming the tool:

```bash
env -i \
  HOME="$HOME" \
  USER="$USER" \
  LOGNAME="$USER" \
  PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  SHELL="$(command -v zsh)" \
  zsh -c 'env | sort'
```

## Validation checklist

- [ ] Required env is visible from non-login, non-interactive `zsh -c`.
- [ ] Machine-critical env does not depend on `.zprofile` or `.zshrc`.
- [ ] `~/.zshenv` remains silent and safe for automation.
