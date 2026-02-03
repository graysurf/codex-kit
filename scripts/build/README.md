# `bundle-wrapper.zsh`

Bundle a zsh “wrapper script” into a single, standalone executable by inlining its sourced files (and optionally embedding runtime tools).

## Usage

```zsh
zsh -f $CODEX_HOME/scripts/build/bundle-wrapper.zsh --input <wrapper> --output <path> [--entry <fn>]
```

The bundler sets sensible defaults if missing:

- `ZDOTDIR` (default: `$HOME/.config/zsh`)
- `ZSH_CONFIG_DIR` (default: `$ZDOTDIR/config`)
- `ZSH_BOOTSTRAP_SCRIPT_DIR` (default: `$ZDOTDIR/bootstrap`)
- `ZSH_SCRIPT_DIR` (default: `$ZDOTDIR/scripts`)

## Maintenance

This script is intended to stay in sync with the upstream `bundle-wrapper.zsh` used by your zsh wrapper/tooling.

If you update the upstream version locally, you can vendor it into this repo with:

```zsh
cp "$HOME/.config/zsh/tools/bundle-wrapper.zsh" $CODEX_HOME/scripts/build/bundle-wrapper.zsh
$CODEX_HOME/scripts/test.sh tests/test_script_smoke_bundle_wrapper.py
```

## Supported wrapper patterns

- Simple `source <path>` / `. <path>` lines (static paths only)
  - Disallows command substitution / process substitution in paths (`$()`, backticks, `<( )`, `>( )`)
  - Supports `$VAR` / `${VAR}` expansions only when the variable is bound
- `typeset -a sources=(...)` where entries are relative to `$ZSH_SCRIPT_DIR`
- `typeset -a exec_sources=(...)` where entries are relative to `$ZDOTDIR` (unless absolute)
  - Each entry is embedded as a function; calling it writes the tool to a temp file, executes it, then deletes it (best-effort)

## Notes

- If `--input` already looks like bundled output (has `# Bundled from:` and `# --- BEGIN ...` markers), the script copies it to `--output` and rewrites the first `# Bundled from:` line.
- Output always starts with a shebang + minimal env exports, then the inlined sources.
- When copying an already-bundled script, `--entry` is ignored (and can be omitted).

## Examples

### Re-bundle an already-bundled script (copy mode)

```zsh
zsh -f $CODEX_HOME/scripts/build/bundle-wrapper.zsh \
  --input "$HOME/.codex/scripts/project-resolve" \
  --output scripts/project-resolve
```

### Bundle a minimal wrapper (sources + embedded tool)

```zsh
tmp="$(mktemp -d)"
mkdir -p "$tmp/zdotdir/scripts/lib" "$tmp/zdotdir/tools"

cat >"$tmp/zdotdir/scripts/lib/hello.zsh" <<'EOF'
hello_main() {
  print -r -- "hello-main"
  echo-tool "arg1"
}
EOF

cat >"$tmp/zdotdir/tools/echo-tool.zsh" <<'EOF'
#!/usr/bin/env -S zsh -f
print -r -- "tool:${1-}"
EOF

cat >"$tmp/wrapper.zsh" <<'EOF'
#!/usr/bin/env -S zsh -f
typeset -a sources=(
  "lib/hello.zsh"
)
typeset -a exec_sources=(
  "tools/echo-tool.zsh"
)
EOF

ZDOTDIR="$tmp/zdotdir" \
ZSH_SCRIPT_DIR="$tmp/zdotdir/scripts" \
zsh -f $CODEX_HOME/scripts/build/bundle-wrapper.zsh \
  --input "$tmp/wrapper.zsh" \
  --output "$tmp/bundled.zsh" \
  --entry hello_main

zsh -f "$tmp/bundled.zsh"
```
