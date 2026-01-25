# Assistant completion template (fixed)

Use this template after a successful image-processing run.

```text
Output:
- `<output file or folder path>`

Next prompt:
- "<a single-sentence prompt that repeats the same task with concrete paths/options>"

Notes:
- Report (if used): `<out/image-processing/runs/<run_id>/report.md>`
- Summary (if `--json`/`--report` used): `<out/image-processing/runs/<run_id>/summary.json>`
- Warnings (if any): <short list>
```

## Prompt guidance (for reuse)

A good “next prompt” should include:

- The subcommand (convert/resize/rotate/crop/pad/flip/flop/optimize)
- Exact input path(s)
- Exact output mode (`--out`/`--out-dir`/`--in-place --yes`)
- Any non-default flags (e.g., `--no-auto-orient`, `--no-pre-upscale`, `--background`, `--strip-metadata`, `--report`)

Example:

```text
Convert `assets/fixtures/fixture_80x60.png` to WebP and write to `out/image-processing/validate/fixture.webp` with a report.
```
