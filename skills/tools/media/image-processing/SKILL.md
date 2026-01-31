---
name: image-processing
description: Process images (convert/resize/crop/optimize) via ImageMagick
---

# Image Processing

Translate a user’s natural-language request into a safe invocation of the `image-processing` CLI.

## Contract

Prereqs:

- Run inside a git work tree (recommended; enables stable `out/` paths).
- `image-processing` binary available in `PATH` (built from `/Users/terry/Project/graysurf/nils-cli/crates/image-processing`).
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

- Missing required tools (`image-processing` binary, ImageMagick).
- Invalid or ambiguous flags (missing output mode, missing required params).
- Output collisions in batch mode (multiple inputs map to the same output).
- Output already exists without `--overwrite`.
- Disallowed operations:
  - `--in-place` without `--yes`
  - Alpha → JPEG without `--background`

## Guidance

### Preferences (optional; honor when provided)

- Output mode: `--out` / `--out-dir` / `--in-place --yes`
- Format: `png` / `jpg` / `webp`
- Geometry intent: width/height/scale/aspect, `--fit contain|cover|stretch`, `--gravity`
- Quality / metadata: `--quality`, `--strip-metadata`, `--background` (required for alpha → JPEG)
- Reproducibility: `--dry-run`, `--json`, `--report`

### Policies (must-follow per request)

1) If underspecified: ask must-have questions first
   - Use: `skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`
   - Ask 1–5 “Need to know” questions with explicit defaults.
   - Do not run commands until the user answers or explicitly approves assumptions.

2) Single entrypoint (do not bypass)
   - Only run: `image-processing` (must be in `PATH`)
   - Do not call ImageMagick binaries directly unless debugging the `image-processing` CLI itself.

3) Output mode gate (exactly one)
   - For output-producing subcommands, require exactly one of:
     - `--out <file>` (single input only)
     - `--out-dir <dir>` (batch)
     - `--in-place --yes` (destructive; requires explicit user intent)

4) Completion response (fixed)
   - After a successful run, respond using:
     - `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
   - Include clickable output path(s) and a one-sentence “next prompt” that repeats the same task with concrete paths/options.

## References

- `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
