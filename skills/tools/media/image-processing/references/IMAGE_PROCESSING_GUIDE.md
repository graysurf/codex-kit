# Image Processing Guide

Entrypoint:

```bash
image-processing --help
```

## Design rules (important)

- The CLI has exactly two subcommands: `convert` and `svg-validate`.
- By default, the CLI refuses to overwrite outputs. Use `--overwrite` to replace.
- `convert` is SVG-first: it requires `--from-svg` and does not accept `--in`.
- `svg-validate` requires exactly one `--in` and an explicit `--out` ending in `.svg`.
- When `--json` is used, stdout is JSON only (logs go to stderr).

## Common flags

- Inputs:
  - `convert`: `--from-svg <path>`
  - `svg-validate`: `--in <path>` (exactly one)
- Output:
  - `--out <file>` (required)
  - `--overwrite` (optional)
- Convert target:
  - `--to png|webp|svg` (required for `convert`)
  - `--width`, `--height` (optional, raster targets only)
- Reproducibility:
  - `--dry-run` (no image outputs written)
  - `--json` (machine summary)
  - `--report` (writes `report.md` under `out/image-processing/runs/<run_id>/`)

## Subcommands

### `convert`

Render trusted SVG input to `png`, `webp`, or `svg`.

```bash
image-processing \
  convert \
  --from-svg path/to/icon.svg \
  --to webp \
  --out out/icon.webp \
  --json

image-processing \
  convert \
  --from-svg path/to/icon.svg \
  --to png \
  --out out/icon@2x.png \
  --width 512 \
  --height 512 \
  --json
```

Rules:

- Must include `--from-svg`, `--to`, and `--out`.
- Must not include `--in`.
- `--out` extension must match `--to`.
- `--to svg` does not support `--width`/`--height`.

### `svg-validate`

Validate and sanitize one SVG input into one SVG output.

```bash
image-processing \
  svg-validate \
  --in path/to/input.svg \
  --out out/input.cleaned.svg \
  --json
```

Rules:

- Requires exactly one `--in`.
- Requires `--out`, and output must be `.svg`.
- Does not support convert-only flags (`--from-svg`, `--to`, `--width`, `--height`).

## Known removed subcommands

The following legacy subcommands are no longer supported and now return usage errors:

- `info`
- `auto-orient`
- `resize`
- `rotate`
- `crop`
- `pad`
- `flip`
- `flop`
- `optimize`
```
