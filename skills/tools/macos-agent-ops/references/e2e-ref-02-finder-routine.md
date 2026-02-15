# Reference 02: Finder Routine Flow

Goal: mirror core behavior from Finder scenario in `e2e_real_apps`.

## Source test reference

- `crates/macos-agent/tests/e2e_real_apps.rs`
- `crates/macos-agent/tests/real_apps/finder.rs`

## Quick usage

```bash
OPS="$AGENTS_HOME/skills/tools/macos-agent-ops/scripts/macos-agent-ops.sh"
BIN="$($OPS where)"

# 1) Ensure input source + app foreground readiness
"$OPS" input-source --id abc
"$OPS" app-check --app Finder

# 2) New window and navigate home
"$BIN" --format json input hotkey --mods cmd --key n
"$BIN" --format json wait window-present --app Finder --timeout-ms 10000 --poll-ms 60
"$BIN" --format json input hotkey --mods cmd,shift --key h

# 3) AX probe for deterministic selector checks
"$OPS" ax-check --app Finder --role AXWindow --max-depth 3 --limit 20

# 4) Capture evidence
"$BIN" --format json observe screenshot --active-window \
  --path "$AGENTS_HOME/out/finder-routine-active-window.png"
```

## What this catches

- Window activation failures.
- Window presence polling instability.
- Input source drift before keyboard actions.
- AX tree lookup regressions before selector-driven flows.
- Screenshot capture permission regressions.
