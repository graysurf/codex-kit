# Plan: Image processing skill (tools/media/image-processing)

## Overview

This plan adds a new Codex CLI skill under `skills/tools/media/image-processing/` for common image transformations:

- Format conversion (PNG/JPG/WebP)
- Resizing (proportional, scale factor, aspect-ratio driven)
- Rotation (explicit degrees)

Users will describe requests in natural language. When anything is ambiguous, the assistant must ask clarifying questions before running commands (no guessing). After each run, the assistant must respond with a fixed template that includes a clickable output path and a suggested “next time” prompt to repeat the same operation.

## Goals

- Single entrypoint + subcommands (v1):
  - `info`, `auto-orient`, `convert`, `resize`, `rotate`, `crop`, `pad`, `flip`, `flop`, `optimize`.
- Batch support: multiple files and directories, with `--recursive` and `--glob` filters.
- Default pre-upscale enabled for resize: intermediate 2x upscale step before applying the final resize (explicit opt-out).
- Safe outputs by default:
  - No overwriting unless `--overwrite` is set.
  - Allow `--in-place`, but require explicit confirmation (`--yes`) since it is destructive.
- Support metadata and compression controls:
  - `--auto-orient` (default on; `--no-auto-orient` to disable)
  - `--strip-metadata` (optional)
  - `--background` (required when flattening alpha into non-alpha formats, e.g. PNG→JPG)
  - `optimize` options (quality, progressive JPEG, WebP lossless/lossy; with capability detection)
- Provide reproducibility helpers:
  - `--dry-run` prints planned commands and performs no writes
  - `--json` emits a machine summary for assistant outputs and prompt suggestions
  - `--report` writes a Markdown report including before/after sizes and savings ratios when possible

## Non-goals

- Editing/retouching workflows (masks, layers, healing, etc.).
- ML upscaling or “content-aware” transforms.
- Supporting non-raster inputs (PDF/SVG) in v1.

## User workflow (natural language)

1. User describes the desired outcome in natural language.
2. Assistant maps the request to a concrete command invocation.
3. If any ambiguity remains, assistant asks clarifying questions (examples):
   - Aspect ratio implies “crop” vs “pad”
   - Whether overwriting is acceptable
   - Whether `--in-place` is intended
4. Assistant executes the `image-processing` CLI.
5. Assistant responds using the skill’s fixed completion template:
   - Output path(s) as clickable file/folder links
   - Suggested reusable prompt for next time

## Proposed CLI (v1)

Entrypoint:
- `image-processing`

Common flags (shared):
- `--in PATH` (repeatable; file or directory)
- Output mode (exactly one required):
  - `--out PATH` (single output file; only valid when exactly one input file is resolved)
  - `--out-dir PATH` (batch output directory)
  - `--in-place` (modify input file(s); requires `--yes`)
- `--recursive` (when `--in` includes directories)
- `--glob PATTERN` (repeatable; filter candidates, e.g. `*.png`)
- `--overwrite` (allow overwriting output paths)
- `--yes` (confirm destructive operations)
- `--dry-run` (print planned operations only)
- `--report` (write a Markdown report under `out/image-processing/runs/.../report.md`; include path in JSON summary)
- `--auto-orient` / `--no-auto-orient` (default: auto-orient enabled for operations that output files)
- `--strip-metadata` (remove EXIF/XMP/ICC in outputs)
- `--background COLOR` (used for alpha flattening and padding background when needed)
- `--json` (emit JSON run summary on stdout; human output goes to stderr; also writes an artifact under `out/image-processing/`)

Subcommands:
- `info` (format, dimensions, size, alpha, EXIF orientation when available)
- `auto-orient` (apply EXIF orientation to pixels; clears orientation metadata)
- `convert --to png|jpg|webp [--quality INT] [--background COLOR] [--strip-metadata]`
- `resize [--width INT] [--height INT] [--scale NUMBER] [--aspect W:H --fit contain|cover|stretch] [--no-pre-upscale]`
- `rotate --degrees INT` (positive = clockwise)
- `crop` (rect crop, center crop, aspect crop)
- `pad --width INT --height INT` (extend canvas to target size)
- `flip` (vertical mirror)
- `flop` (horizontal mirror)
- `optimize` (re-encode for size/quality; JPEG/WebP focused in v1)

Aspect ratio semantics:
- `--aspect W:H` must be paired with:
  - exactly one of `--width` or `--height` (or both, but must match the aspect), and
  - an explicit `--fit contain|cover|stretch`.
- `--fit contain|cover|stretch` is only valid when a target box is fully specified:
  - either `--width` + `--height`, or
  - `--aspect` plus one of `--width`/`--height` (so the other dimension can be computed).

Pre-upscale semantics (default on):
- Default: pre-upscale factor is 2.
- Behavior: apply an intermediate 2x enlarge step before the final resize. Final output dimensions must still match the explicit resize target.

## Output contract (script)

- Human-readable summary on stderr (inputs, outputs, warnings) to keep stdout clean when `--json` is used.
- Machine summary when `--json` is set (stdout is JSON only):
  - `schema_version` (integer)
  - `run_id` (string, stable for the run)
  - `cwd` (string)
  - `operation` (string)
  - `backend` (string; detected toolchain)
  - `report_path` (string or null; repo-relative when possible)
  - `inputs` (array of objects with resolved paths and detected metadata when available)
  - `outputs` (array of objects with resolved paths and before/after metadata when available)
  - `commands` (array of executed command strings)
  - `skipped` (array of reasons/paths)
  - `collisions` (array of output-path collisions and the resolution)
  - `warnings` (array of warning strings)
- Always write a stable artifact under:
  - `out/image-processing/runs/YYYYMMDD-HHMMSS/summary.json`

## Assistant completion template (fixed)

This is an assistant response template (documented in the skill) used after a successful run:

- Output:
  - `PATH` (file) or `PATH` (folder)
- Next prompt:
  - A single prompt sentence that restates the operation with concrete paths/options.
- Notes (optional):
  - Any warnings (skipped files, overwrite avoidance, missing optional tools)

## Risks / gotchas

- In-place edits are destructive; must require explicit confirmation and should be loudly summarized.
- Default pre-upscale can be slow on large images; ensure there is a clear opt-out flag.
- Tool availability can differ by environment; implement capability detection and actionable errors.
- This repo does not appear to require a centralized “skill registry”, but confirm no extra index docs need updating.

## Rollback plan

- Remove the new skill directory `skills/tools/media/image-processing/`.
- Remove any doc references that were added.
- Validate repo state:
  - `scripts/check.sh --contracts --skills-layout --plans --tests`

## Sprint 1: Scaffold + contracts + run summary

**Goal**: create the skill skeleton, lock down the contract/docs, and build a safe CLI skeleton with a stable run summary format.

### Task 1.1: Scaffold the new skill directory

- **Complexity**: 3
- **Location**:
  - `skills/tools/media/image-processing/SKILL.md`
  - `skills/tools/media/image-processing/tests/test_tools_media_image_processing.py`
- **Description**: Use the existing `create-skill` scaffolder to generate the skill skeleton at `skills/tools/media/image-processing/`, then update the generated metadata (title/description) to match this skill’s purpose.
- **Dependencies**: none
- **Acceptance criteria**:
  - The new directory exists with `SKILL.md`, `references/`, and `tests/`.
  - Skill contract validation passes for the new `SKILL.md`.
  - Skill layout audit passes for the new skill directory.
- **Validation**:
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh --file skills/tools/media/image-processing/SKILL.md`
  - `$AGENTS_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh --skill-dir skills/tools/media/image-processing`
  - `scripts/test.sh -k tools_media_image_processing`

### Task 1.2: Write the skill docs (CLI + assistant workflow + response template)

- **Complexity**: 5
- **Location**:
  - `skills/tools/media/image-processing/SKILL.md`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
  - `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
- **Description**: Document the v1 CLI contract (subcommands, flags, defaults), the assistant “ask before acting” workflow for ambiguous requests, and a fixed completion response template that always includes output paths and a suggested reusable prompt.
- **Dependencies**:
  - Task 1.1
- **Acceptance criteria**:
  - `SKILL.md` has concrete `Prereqs`, `Inputs`, `Outputs`, `Exit codes`, and `Failure modes` that match the planned CLI.
  - The references include at least three end-to-end examples (natural language request + resulting CLI invocation).
  - The response template is copy-pasteable and stable.
- **Validation**:
  - `scripts/check.sh --contracts --skills-layout`

### Task 1.3: Implement the CLI skeleton + run summary artifact

- **Complexity**: 6
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Ensure `image-processing` is installed in `PATH` (from `/Users/terry/Project/graysurf/nils-cli/crates/image-processing`), then document and validate its v1 subcommands/flags and `--json` run summary behavior.
- **Dependencies**:
  - Task 1.1
- **Acceptance criteria**:
  - `--help` prints usage and available subcommands.
  - Unknown flags fail with exit code 2 and an actionable error message.
  - If none (or more than one) of `--out`, `--out-dir`, `--in-place` is provided, the command fails with exit code 2.
  - `--in-place` without `--yes` fails with exit code 2.
  - `--dry-run` performs no writes and prints planned actions.
  - `--json` emits valid JSON (stdout contains JSON only; any human output goes to stderr) and writes `out/image-processing/runs/.../summary.json`.
  - Missing required tools fails with exit code 1 and an actionable error message (including the detected/required commands).
- **Validation**:
  - `command -v image-processing`
  - `image-processing --help`
  - `image-processing convert --help`

### Task 1.4: Add tiny fixture images for tests and validation

- **Complexity**: 2
- **Location**:
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png`
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60.jpg`
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60.webp`
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60_alpha.png`
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60_exif_orientation_6.jpg`
- **Description**: Add small deterministic fixture images (including a non-square image and an alpha PNG) to support CLI validation and functional tests without relying on external downloads.
- **Dependencies**:
  - Task 1.1
- **Acceptance criteria**:
  - Fixtures are small and deterministic (suitable for git).
  - At least one fixture has alpha and at least one is non-square for rotation testing.
  - The EXIF-orientation fixture has a non-default EXIF orientation value (e.g., 6) for `auto-orient` tests.
- **Validation**:
  - `file skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png`
  - `identify -format "%m %wx%h\n" skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png`
  - `identify -format "%[EXIF:Orientation]\n" skills/tools/media/image-processing/assets/fixtures/fixture_80x60_exif_orientation_6.jpg`

## Sprint 2: Core transforms (convert / resize / rotate) + batch mapping

**Goal**: implement the core required transforms with consistent batch handling and a stable summary output.

### Task 2.1: Implement shared input expansion + output mapping

- **Complexity**: 7
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Implement shared logic to expand `--in` paths into a stable list of input files, apply optional `--glob` filtering, and map each input to an output path according to `--out`, `--out-dir`, `--overwrite`, and `--in-place` rules. Ensure collisions are detected and reported.
- **Dependencies**:
  - Task 1.3
- **Acceptance criteria**:
  - Directories are supported (with `--recursive`).
  - `--glob` filters candidates (repeatable).
  - Exactly one output mode is required (`--out`, `--out-dir`, or `--in-place`).
  - `--out` is rejected when more than one input file is resolved.
  - Outputs are deterministic and collisions are handled (fail or skip unless `--overwrite`).
  - `--in-place` requires `--yes` and is clearly summarized.
- **Validation**:
  - `image-processing convert --in skills/tools/media/image-processing/assets/fixtures --recursive --glob '*.png' --to webp --out-dir out/image-processing/validate --dry-run --json`

### Task 2.2: Implement `convert` (PNG/JPG/WebP)

- **Complexity**: 6
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Implement format conversion with ImageMagick as the primary backend, supporting `png`, `jpg`, and `webp` targets. Add `--quality` where applicable and require `--background` when converting an alpha input into a format that cannot represent alpha (e.g., PNG to JPG).
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - Converting the fixture set produces outputs with the expected formats and extensions.
  - Batch conversion respects `--out-dir` and preserves basenames.
  - Alpha-to-JPG without `--background` fails loudly (no implicit guessing).
  - Alpha-to-JPG with `--background` is documented and deterministic.
  - `--strip-metadata` removes EXIF/XMP/ICC data from outputs (validated via EXIF Orientation on the fixture).
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing convert --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --to webp --out out/image-processing/validate/fixture_80x60.webp --json`
  - `identify -format "%m %wx%h\n" out/image-processing/validate/fixture_80x60.webp`
  - `! image-processing convert --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60_alpha.png --to jpg --out out/image-processing/validate/fixture_80x60_alpha.jpg --json`
  - `image-processing convert --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60_alpha.png --to jpg --background white --out out/image-processing/validate/fixture_80x60_alpha.jpg --json`

### Task 2.3: Implement `resize` (scale/width/height/aspect) with default pre-upscale

- **Complexity**: 8
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Implement resize operations that support proportional resizing (`--width`, `--height`), scale factor (`--scale`), and aspect-ratio-driven resizing (`--aspect` with an explicit `--fit contain|cover|stretch`). Default pre-upscale is enabled (2x) and can be disabled with `--no-pre-upscale`. Final output dimensions must match the explicit resize target.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - `--scale 2` doubles dimensions for the non-square fixture.
  - `--width` preserves aspect ratio when `--height` is not provided.
  - `--aspect` requires an explicit `--fit` and produces the expected dimensions.
  - `--fit stretch` produces exactly the requested output dimensions.
  - Pre-upscale does not change the final output dimensions for a given explicit resize target.
  - `--no-pre-upscale` is supported and documented.
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing resize --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --scale 2 --out out/image-processing/validate/fixture_160x120.png --json`
  - `identify -format "%wx%h\n" out/image-processing/validate/fixture_160x120.png`

### Task 2.4: Implement `rotate` (explicit degrees)

- **Complexity**: 5
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Implement rotation by explicit degrees (positive = clockwise). Ensure batch mode works and rotation is reflected in output dimensions for the non-square fixture (e.g., 90 degrees swaps width/height).
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - Rotating the non-square fixture by 90 degrees swaps width and height.
  - Output mapping and overwrite/in-place safety rules are enforced.
  - Rotation behavior is documented with at least one example.
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing rotate --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --degrees 90 --out out/image-processing/validate/fixture_rotated.png --json`
  - `identify -format "%wx%h\n" out/image-processing/validate/fixture_rotated.png`

### Task 2.5: Add `info` for debug and batch reporting

- **Complexity**: 4
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Add an `info` subcommand that prints image metadata useful for validation and debugging (format, dimensions, alpha presence, and orientation when available). Support `--json` so the assistant can include details in notes when needed.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - `info` runs without modifying files.
  - Output includes format and dimensions for fixture images.
  - Batch `info` produces one record per input.
- **Validation**:
  - `image-processing info --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --json`

### Task 2.6: Implement `auto-orient` (EXIF) with safe defaults

- **Complexity**: 6
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Implement EXIF-based auto-orientation for common “phone photo” cases. Provide a dedicated `auto-orient` subcommand and make auto-orient enabled by default for all subcommands that write output files. Support `--no-auto-orient` to disable. Ensure that `auto-orient` results are reflected in the JSON summary and that orientation metadata is normalized/cleared after applying it.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - Running `auto-orient` on the EXIF-orientation fixture rotates pixels and normalizes orientation metadata (e.g., EXIF Orientation becomes empty or `1`).
  - With `--strip-metadata`, the output contains no EXIF Orientation tag.
  - Auto-orient is enabled by default for output-producing subcommands; `--no-auto-orient` disables it.
  - Behavior is documented with at least one example and a “when to disable” note.
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing auto-orient --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60_exif_orientation_6.jpg --out out/image-processing/validate/fixture_auto_oriented.jpg --json`
  - `identify -format "%wx%h %[EXIF:Orientation]\n" out/image-processing/validate/fixture_auto_oriented.jpg`

### Task 2.7: Implement `flip` / `flop` (mirror)

- **Complexity**: 4
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Add `flip` and `flop` subcommands (vertical/horizontal mirror). Ensure they work in batch mode and obey output safety rules. Include the executed commands in the JSON summary.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - `flip` and `flop` run successfully on fixture images and preserve dimensions.
  - Output mapping and overwrite/in-place safety rules are enforced.
  - Behavior is documented with at least one example for each.
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing flip --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --out out/image-processing/validate/fixture_flip.png --json`
  - `image-processing flop --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --out out/image-processing/validate/fixture_flop.png --json`
  - `identify -format "%wx%h\n" out/image-processing/validate/fixture_flip.png`
  - `identify -format "%wx%h\n" out/image-processing/validate/fixture_flop.png`

## Sprint 3: Crop/pad + optimize + reporting

**Goal**: implement common layout transforms (crop/pad), compression optimizations, and reusable reporting for batch work.

### Task 3.1: Implement `crop` (rect / center / aspect)

- **Complexity**: 7
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Add a `crop` subcommand supporting (a) explicit rect crop, (b) center crop by target dimensions, and (c) aspect crop (e.g., 1:1, 16:9) using an explicit gravity/anchor. Do not guess: require enough flags to unambiguously define the crop region.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - Rect crop produces an output with the expected dimensions.
  - Aspect crop (e.g., 1:1) produces the expected output dimensions on the non-square fixture.
  - Output mapping and overwrite/in-place safety rules are enforced.
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing crop --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --aspect 1:1 --out out/image-processing/validate/fixture_square.png --json`
  - `identify -format "%wx%h\n" out/image-processing/validate/fixture_square.png`

### Task 3.2: Implement `pad` / `extent` (canvas)

- **Complexity**: 6
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Add a `pad` subcommand to extend the canvas to a target width/height (extent). Do not guess: if the target dimensions are smaller than the input, fail (user should use `crop` or `resize --fit cover`). Use `--background` when output cannot support transparency.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - Padding produces exactly the requested output dimensions.
  - If output format cannot represent alpha, missing `--background` fails loudly.
  - Output mapping and overwrite/in-place safety rules are enforced.
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing pad --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --width 100 --height 100 --out out/image-processing/validate/fixture_padded.png --json`
  - `identify -format "%wx%h\n" out/image-processing/validate/fixture_padded.png`

### Task 3.3: Add `--report` (Markdown) with before/after size deltas

- **Complexity**: 6
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
  - `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
- **Description**: Implement `--report` to write a Markdown report for the run under `out/image-processing/runs/.../report.md` and include its path in the JSON summary. The report must include inputs, outputs, executed commands, and before/after file sizes (and % savings) when outputs exist.
- **Dependencies**:
  - Task 1.3
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - `--report` writes a Markdown report file and reports the path in `report_path` in JSON.
  - For non-dry runs, the report includes before/after sizes and savings ratios.
  - For `--dry-run`, the report includes planned commands and input sizes (but clearly indicates outputs were not written).
  - Report paths live under `out/` (never `/tmp`).
- **Validation**:
  - `rm -rf out/image-processing/validate && mkdir -p out/image-processing/validate`
  - `image-processing convert --in skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png --to webp --out out/image-processing/validate/fixture_80x60.webp --report --json > out/image-processing/validate/summary.json`
  - `python3 -c 'import json,os; j=json.load(open(\"out/image-processing/validate/summary.json\")); p=j.get(\"report_path\"); assert p and p.startswith(\"out/\") and os.path.isfile(p)'`

### Task 3.4: Implement `optimize` (JPEG/WebP) with capability detection

- **Complexity**: 7
- **Location**:
  - `image-processing`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
- **Description**: Add an `optimize` subcommand that re-encodes JPEG/WebP with better encoders when available (`cjpeg`, `cwebp`) and falls back to ImageMagick when they are not. Support quality and (where applicable) progressive JPEG and WebP lossless/lossy options. Include encoder selection in the JSON summary.
- **Dependencies**:
  - Task 2.1
  - Task 1.4
- **Acceptance criteria**:
  - The script detects encoder availability via `command -v`.
  - The summary JSON reports which encoder was used per file.
  - Missing optional encoders does not fail the run (it falls back).
- **Validation**:
  - `image-processing optimize --help`

## Sprint 4: Functional tests + docs polish

**Goal**: add CI-safe functional tests and final docs that teach prompt reuse.

### Task 4.1: Add functional pytest coverage for all subcommands

- **Complexity**: 9
- **Location**:
  - `skills/tools/media/image-processing/tests/test_tools_media_image_processing.py`
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60.png`
  - `skills/tools/media/image-processing/assets/fixtures/fixture_80x60_exif_orientation_6.jpg`
- **Description**: Extend the per-skill pytest tests beyond contract checks to cover `--help` and at least one happy-path execution for each subcommand: `info`, `auto-orient`, `convert`, `resize`, `rotate`, `crop`, `pad`, `flip`, `flop`, `optimize`. Tests should write outputs under `out/tests/` and skip gracefully if required tools are missing. Include negative tests for safety failures and “no guessing” errors (e.g., alpha→JPG without `--background`, missing output mode) plus a positive `--strip-metadata` case (e.g., EXIF Orientation removed).
- **Dependencies**:
  - Task 2.2
  - Task 2.3
  - Task 2.4
  - Task 2.5
  - Task 2.6
  - Task 2.7
  - Task 3.1
  - Task 3.2
  - Task 3.3
  - Task 3.4
- **Acceptance criteria**:
  - Tests pass on machines with ImageMagick installed.
  - Tests skip (not fail) with a clear reason when ImageMagick is missing.
  - Outputs are written under `out/` and namespaced to avoid collisions.
  - Tests cover safety failures (`--in-place` without `--yes`, overwrite avoidance without `--overwrite`).
  - Tests cover “no guessing” failures (e.g., missing `--background` when required, missing output mode).
- **Validation**:
  - `scripts/test.sh -k tools_media_image_processing`

### Task 4.2: Final docs polish and examples for prompt reuse

- **Complexity**: 5
- **Location**:
  - `skills/tools/media/image-processing/SKILL.md`
  - `skills/tools/media/image-processing/references/IMAGE_PROCESSING_GUIDE.md`
  - `skills/tools/media/image-processing/references/ASSISTANT_RESPONSE_TEMPLATE.md`
- **Description**: Ensure the docs include multiple examples that show (1) the natural-language request, (2) the exact command used, and (3) the assistant completion template including the suggested reusable prompt. Include examples for crop/pad/optimize and mention when the assistant should ask clarifying questions.
- **Dependencies**:
  - Task 4.1
- **Acceptance criteria**:
  - Docs include at least five full examples covering convert, resize, rotate, crop, and optimize.
  - The completion template is stable and used consistently across examples.
  - Skill contract validation still passes after doc edits.
- **Validation**:
  - `scripts/check.sh --contracts --skills-layout --tests`
