# Reference 03: Arc/Spotify/Finder Matrix Routine

Goal: mirror matrix-style real-app checks from `e2e_real_apps`.

## Source test reference

- `crates/macos-agent/tests/e2e_real_apps.rs`
- `crates/macos-agent/tests/real_apps/matrix.rs`
- `crates/macos-agent/tests/real_apps/cross_app.rs`

## Quick usage

```bash
OPS="$CODEX_HOME/skills/tools/macos-agent-ops/scripts/macos-agent-ops.sh"

# 0) Stabilize input source once
"$OPS" input-source --id abc

# 1) Run app readiness checks sequentially (window activate + wait app-active)
"$OPS" app-check --app Arc --timeout-ms 15000
"$OPS" app-check --app Spotify --timeout-ms 15000
"$OPS" app-check --app Finder --timeout-ms 12000

# 2) Run AX probes to validate selector traversal
"$OPS" ax-check --app Arc --role AXWindow --max-depth 4 --limit 40
"$OPS" ax-check --app Spotify --role AXWindow --max-depth 4 --limit 40
"$OPS" ax-check --app Finder --role AXWindow --max-depth 4 --limit 40
```

## Suggested scheduled check pattern

1. Run `doctor` once.
2. Run the 3 `app-check` commands above.
3. Run the 3 `ax-check` commands above.
4. If any command fails with `wait app-active` timeout, capture current active window screenshot:

```bash
BIN="$($CODEX_HOME/skills/tools/macos-agent-ops/scripts/macos-agent-ops.sh where)"
"$BIN" --format json observe screenshot --active-window \
  --path "$CODEX_HOME/out/macos-agent-matrix-failure.png"
```

## Common stabilization notes

- Close Control Center/Spotlight overlays before matrix runs.
- Avoid keyboard/mouse activity while checks are active.
- If Spotify launch is flaky, clear stale updater processes before rerun.
- If typing mismatches appear, rerun `"$OPS" input-source --id abc`.
