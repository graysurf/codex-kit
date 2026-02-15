# <Short title describing the primary fix or report>

## Summary

- What this PR does and why it matters.

## Semgrep Scan

- Config entrypoint: `<path>`
- Command: `semgrep scan --config "<path>" --json --metrics=off --disable-version-check .`
- Output JSON (local): `<path under $AGENTS_HOME/out/semgrep/>`

## Top Findings

| Rule ID | Severity | Confidence | Location | Summary | Status |
| --- | --- | --- | --- | --- | --- |
| <rule.id> | error\|warning\|info | high\|medium\|low\|unknown | <path:line> | <one line> | fixed\|open\|deferred |

## Fix Approach (if applicable)

- <key change>

## Testing

- <command> (pass)
- not run (reason)

## Notes / Risk

- <optional>
