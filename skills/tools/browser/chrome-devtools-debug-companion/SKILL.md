---
name: chrome-devtools-debug-companion
description: Use the chrome-devtools MCP server as a debugging companion to Playwright for browser-specific root-cause analysis (console, network, rendering, storage, and performance). Use when Playwright exposes a failure or flaky behavior and deeper Chrome runtime inspection is needed.
---

# Chrome DevTools Debug Companion

## Contract

Prereqs:

- `mcp_servers.chrome-devtools` must be available and connectable.
- A reproducible target flow (URL + steps) or existing evidence from Playwright (trace, screenshot, failing step, error message).

Inputs:

- Target URL/environment and reproduction steps.
- Problem signal (error text, failing UI behavior, network symptom, performance symptom, or flaky step).
- Optional Playwright artifacts (trace/video/screenshot/log) to narrow investigation.

Outputs:

- A root-cause oriented debug summary backed by observed browser evidence.
- Actionable remediation suggestions and a Playwright follow-up check list.

Exit codes:

- N/A (interactive MCP workflow; no repo scripts)

Failure modes:

- `mcp_servers.chrome-devtools` is missing/unavailable/times out (must stop and report; no non-browser fallback).
- The issue cannot be reproduced in a comparable environment (auth walls, feature flags, data dependency, geo/device mismatch).

## Purpose

- This skill is no longer a site-search workflow.
- It is a Chrome-focused debug companion that complements Playwright by exposing low-level runtime evidence during investigation.

## Playwright vs DevTools (Decision Table)

| Situation | Primary tool | Companion tool | Why |
| --- | --- | --- | --- |
| Deterministic user-flow regression in CI | Playwright | DevTools only when needed | Playwright gives stable, repeatable end-to-end verification. |
| Chrome-only bug (rendering, runtime, extension, CSP, cache, service worker) | DevTools | Playwright | DevTools offers deeper Chrome runtime visibility. |
| Flaky step found in Playwright | Playwright + DevTools | Both required | Use Playwright to isolate failing step and DevTools to inspect live runtime causes. |
| Performance triage for Chromium path | DevTools | Playwright | DevTools provides network/runtime timing detail; Playwright confirms regression checks. |

## Workflow

1. **Start from reproducible evidence**
   - Prefer existing Playwright evidence first (failed step, trace, screenshot, error text).
   - If no evidence exists, ask for URL + exact reproduction steps before debugging.

2. **Reproduce in `mcp_servers.chrome-devtools`**
   - Open the target page and replay the smallest flow that still reproduces the issue.
   - Keep one tab dedicated to reproduction and one tab for comparison (baseline route or prior state) when useful.

3. **Capture layered diagnostics**
   - Console: errors/warnings with message, stack, and repeat count.
   - Network: failed/slow requests, status codes, response headers, payload clues, and request initiator chain.
   - Rendering/UI: DOM state, computed style, layout shifts, visibility/overlap issues, and event-target mismatches.
   - Runtime/perf: long tasks, waterfall bottlenecks, resource contention, and script hotspots.
   - Storage/session context: cookies, local/session storage, cache/service worker side effects when relevant.

4. **Isolate root cause**
   - Validate one hypothesis at a time (for example: blocked API, race condition, stale cache, CSS stacking context, hydration mismatch).
   - Prefer smallest reversible toggles and record what changed and what did not.

5. **Hand off fix guidance + verification plan**
   - Provide root cause statement, impacted scope, suggested fix direction, and residual risk.
   - Include Playwright follow-up checks to prevent regressions after the fix.

## Command Patterns

Use these concise prompt patterns when running the skill:

```text
Open <url> in chrome-devtools, reproduce <issue>, then list console errors with stack traces.
```

```text
Inspect network for <failing action>; return failed/slow requests with method, status, URL, and initiator.
```

```text
Diagnose why <element/interaction> fails: verify DOM presence, computed style, overlap, and event target path.
```

```text
Profile page load for <route>; report largest bottlenecks and one prioritized optimization candidate.
```

## Guardrails

- Do not position this skill as a Playwright replacement; use it as a diagnostic complement.
- Do not claim a root cause without direct browser evidence observed during this run.
- If reproducing requires sensitive data or privileged access, ask for safe redaction/approval boundaries first.
- If MCP browser control is unavailable, stop and report the exact blocker and next enablement step.
