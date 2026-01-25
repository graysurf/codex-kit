---
name: image-processing
description: Process images (convert/resize/crop/optimize) via ImageMagick
---

# Image Processing

## Contract

Prereqs:

- Run inside a git work tree (recommended; enables stable `out/` paths).
- `python3` available on `PATH`.
- ImageMagick:
  - `magick` (preferred), or
  - `convert` + `identify`.
- Optional (used by `optimize` when available; otherwise falls back):
  - WebP: `cwebp` + `dwebp`
  - JPEG: `cjpeg` + `djpeg`

Inputs:

- Natural-language user intent (assistant translates into a command).
- One or more input paths via `--in` (file or directory).
- For output-producing subcommands: exactly one output mode:
  - `--out <file>` (single input only), or
  - `--out-dir <dir>` (batch), or
  - `--in-place --yes` (destructive).

Outputs:

- Processed image file(s) under the chosen output mode.
- Optional artifacts under `out/image-processing/runs/<run_id>/`:
  - `summary.json` (when `--json` or `--report` is used)
  - `report.md` (when `--report` is used)
- Assistant response (outside the script) must include:
  - Output file/folder paths as clickable links (inline code)
  - A suggested “next time” prompt to repeat the same task

Exit codes:

- `0`: success
- `1`: failure
- `2`: usage error

Failure modes:

- Missing required tools (`python3`, ImageMagick).
- Invalid or ambiguous flags (missing output mode, missing required params).
- Output collisions in batch mode (multiple inputs map to the same output).
- Output already exists without `--overwrite`.
- Disallowed operations:
  - `--in-place` without `--yes`
  - Alpha → JPEG without `--background`

## Scripts (only entrypoints)

- `$CODEX_HOME/skills/tools/media/image-processing/scripts/image-processing.sh`

## Usage

See:
- `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`

## Assistant behavior (must-follow)

- Users will describe requirements in natural language.
- If anything is ambiguous, ask clarifying questions before running commands. Do not guess.
- After completion, always respond using the fixed template in `ASSISTANT_RESPONSE_TEMPLATE.md`.
