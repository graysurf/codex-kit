---
name: image-processing
description: Validate SVG inputs and convert trusted SVG to png/webp/svg
---

# Image Processing

Translate a user’s natural-language request into a safe invocation of the `image-processing` CLI.

## Contract

Prereqs:

- Run inside a git work tree (recommended; enables stable `out/` paths).
- `image-processing` available on `PATH` (install via `brew install nils-cli`).
- No external image binaries required for standard use.

Inputs:

- Natural-language user intent (assistant translates into a command).
- Exactly one operation:
  - `convert`: `--from-svg <path>` + `--to png|webp|svg` + `--out <file>`
  - `svg-validate`: exactly one `--in <path>` + `--out <file.svg>`
- Optional sizing for raster convert output: `--width` / `--height`.
- Optional output controls: `--overwrite`, `--dry-run`, `--json`, `--report`.

Outputs:

- One output file per invocation.
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

- Missing required tool (`image-processing` binary).
- Invalid or ambiguous flags (missing required params, unsupported combinations).
- Output already exists without `--overwrite`.
- Invalid convert contract:
  - missing `--from-svg` / `--to` / `--out`
  - `--in` used with `convert`
  - `--out` extension mismatch vs `--to`
  - `--to svg` with `--width`/`--height`
- Invalid `svg-validate` contract:
  - missing or repeated `--in`
  - missing `--out`
  - convert-only flags like `--to`/`--width`/`--height`

## Guidance

### Preferences (optional; honor when provided)

- Operation: `convert` or `svg-validate`.
- Target format (for `convert`): `png` / `webp` / `svg`.
- Raster sizing (for `convert --to png|webp`): `--width`, `--height`.
- Reproducibility/audit flags: `--dry-run`, `--json`, `--report`, `--overwrite`.

### Policies (must-follow per request)

1) If underspecified: ask must-have questions first
   - Use: `skills/workflows/conversation/ask-questions-if-underspecified/SKILL.md`
   - Ask 1–5 “Need to know” questions with explicit defaults.
   - Do not run commands until the user answers or explicitly approves assumptions.

2) Single entrypoint (do not bypass)
   - Only run: `image-processing` (from `PATH`; install via `brew install nils-cli`)
   - Do not call ImageMagick binaries directly unless debugging the `image-processing` CLI itself.

3) Contract gate (exactly one operation path)
   - `convert`: require `--from-svg`, `--to`, `--out`; forbid `--in`.
   - `svg-validate`: require exactly one `--in` and `--out`; forbid `--to`/`--width`/`--height`.

4) Completion response (fixed)
   - After a successful run, respond using:
     - `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
   - Include clickable output path(s) and a one-sentence “next prompt” that repeats the same task with concrete paths/options.

## References

- `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
