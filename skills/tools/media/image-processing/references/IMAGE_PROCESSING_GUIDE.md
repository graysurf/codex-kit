# Image Processing Guide

Entrypoint:

```bash
image-processing --help
```

## Design rules (important)

- Output-producing subcommands require **exactly one** output mode:
  - `--out <file>` (single input only), or
  - `--out-dir <dir>` (batch), or
  - `--in-place --yes` (destructive).
- By default, the CLI refuses to overwrite outputs. Use `--overwrite` to replace.
- Only `convert` changes formats. Other subcommands keep the input format/extension.
- `resize` defaults to a 2x pre-upscale step before the final resize; disable with `--no-pre-upscale`.
- Auto orientation is enabled by default for output-producing subcommands; disable with `--no-auto-orient`.
- When `--json` is used, stdout is JSON only (logs go to stderr).

## Common flags

- Inputs:
  - `--in <path>` (repeatable; file or directory)
  - `--recursive` (when `--in` is a directory)
  - `--glob '*.png'` (repeatable; filter directory candidates)
- Output mode:
  - `--out <file>` / `--out-dir <dir>` / `--in-place --yes`
  - `--overwrite`
- Output behavior:
  - `--strip-metadata` (remove EXIF/XMP/ICC)
  - `--background <color>` (required when flattening alpha into JPEG; used for padding background)
- Reproducibility:
  - `--dry-run` (no image outputs written)
  - `--json` (machine summary)
  - `--report` (writes `report.md` under `out/image-processing/runs/<run_id>/`)

## Subcommands

### `info`

Outputs per-file metadata (format, dimensions, size, alpha, EXIF orientation when available).

```bash
image-processing \
  info --in path/to/image.png --json | python3 -m json.tool
```

### `auto-orient`

Applies EXIF orientation to pixels and normalizes orientation metadata.

```bash
image-processing \
  auto-orient --in path/to/photo.jpg --out out/photo.jpg --json
```

### `convert`

Convert between `png`, `jpg`, and `webp`.

```bash
image-processing \
  convert --in path/to/image.png --to webp --out out/image.webp --json
```

Alpha → JPEG requires `--background`:

```bash
image-processing \
  convert --in path/to/alpha.png --to jpg --background white --out out/alpha.jpg --json
```

### `resize`

Supports:
- `--scale <number>` (e.g. `2`)
- `--width <px>` / `--height <px>` (proportional when only one is provided)
- `--aspect W:H` with explicit `--fit contain|cover|stretch` (box-based)

Examples:

```bash
# Scale 2x (proportional)
image-processing \
  resize --in path/to/image.png --scale 2 --out out/image_2x.png --json

# Fit to a 1600x900 box via cover (crop to fill)
image-processing \
  resize --in path/to/image.png --width 1600 --height 900 --fit cover --out out/image_1600x900.png --json
```

### `rotate`

Rotate by degrees clockwise.

```bash
image-processing \
  rotate --in path/to/image.png --degrees 90 --out out/rot90.png --json
```

### `crop`

Choose **exactly one** crop mode:
- `--rect 'WxH+X+Y'`
- `--size 'WxH'` (uses `--gravity`, default `center`)
- `--aspect W:H` (largest possible crop; uses `--gravity`, default `center`)

```bash
image-processing \
  crop --in path/to/image.png --aspect 1:1 --out out/square.png --json
```

### `pad`

Extend canvas to a target size (must be ≥ input dimensions):

```bash
image-processing \
  pad --in path/to/image.png --width 1200 --height 630 --out out/padded.png --json
```

### `flip` / `flop`

```bash
image-processing \
  flip --in path/to/image.png --out out/flip.png --json

image-processing \
  flop --in path/to/image.png --out out/flop.png --json
```

### `optimize`

Re-encode JPEG/WebP (format does not change). Uses `cjpeg`/`cwebp` when available.

```bash
image-processing \
  optimize --in path/to/image.jpg --quality 85 --out out/image.jpg --json
```
