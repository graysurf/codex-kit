# Assistant completion template (fixed)

Use this template after a successful screen-record run.

```text
Output:
- `<output file path>`

Next prompt:
- "<a single-sentence prompt that repeats the same capture task with concrete flags/paths>"

Notes:
- Mode: <recording | screenshot>
- Selector: <portal | active-window | window-id | app/window-name | display | display-id>
- Duration: <seconds; recording only>
- Audio: <off|system|mic|both; recording only>
- Image format: <png|jpg|webp; screenshot only>
- If permission failed: run `screen-record --preflight` (or `--request-permission`) and retry
```

## Prompt guidance (for reuse)

A good “next prompt” should include:

- The selector (`--portal`, `--active-window`, `--window-id`, `--app` + optional `--window-name`,
  `--display`, or `--display-id`)
- Mode intent (`recording` vs `screenshot`)
- `--duration` in seconds for recording
- `--audio` for recording (only if non-default)
- The exact `--path` (and `.mov` vs `.mp4` expectation)

Example:

```text
Record the active window for 8 seconds with system audio to `out/screen-record/active-8s.mov`.
```

```text
Capture a screenshot of the active window to `out/screen-record/active.png`.
```
