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

- The subcommand (`convert` or `svg-validate`)
- Exact input path(s) (`--from-svg` for convert, `--in` for svg-validate)
- Exact output path (`--out`)
- Any non-default flags (e.g., `--width`, `--height`, `--overwrite`, `--report`, `--dry-run`)

Example:

```text
Convert `assets/icons/logo.svg` to WebP and write to `out/image-processing/logo.webp` with `--report`.
```
