#!/usr/bin/env python3

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import fnmatch
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import textwrap
import uuid
from pathlib import Path
from typing import Any, Iterable, Literal


SCHEMA_VERSION = 1
SUPPORTED_CONVERT_TARGETS = {"png", "jpg", "webp"}


def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def now_run_id() -> str:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d-%H%M%S")
    short = uuid.uuid4().hex[:6]
    return f"{stamp}-{short}"


def find_repo_root() -> Path:
    # Prefer git, then fall back to CWD.
    try:
        out = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
        if out:
            return Path(out).resolve()
    except Exception:
        pass
    return Path.cwd().resolve()


def ensure_parent_dir(path: Path, *, dry_run: bool) -> None:
    parent = path.parent
    if not parent.exists():
        if dry_run:
            return
        parent.mkdir(parents=True, exist_ok=True)


def parse_aspect(value: str) -> tuple[int, int]:
    m = re.fullmatch(r"\s*(\d+)\s*:\s*(\d+)\s*", value)
    if not m:
        raise ValueError(f"invalid aspect: {value!r} (expected W:H)")
    w = int(m.group(1))
    h = int(m.group(2))
    if w <= 0 or h <= 0:
        raise ValueError(f"invalid aspect: {value!r} (W and H must be > 0)")
    return (w, h)


def parse_geometry(value: str) -> tuple[int, int, int, int]:
    # WxH+X+Y
    m = re.fullmatch(r"\s*(\d+)\s*x\s*(\d+)\s*\+\s*(-?\d+)\s*\+\s*(-?\d+)\s*", value)
    if not m:
        raise ValueError(f"invalid rect geometry: {value!r} (expected WxH+X+Y)")
    w = int(m.group(1))
    h = int(m.group(2))
    x = int(m.group(3))
    y = int(m.group(4))
    if w <= 0 or h <= 0:
        raise ValueError(f"invalid rect geometry: {value!r} (W and H must be > 0)")
    return (w, h, x, y)


def parse_size(value: str) -> tuple[int, int]:
    # WxH
    m = re.fullmatch(r"\s*(\d+)\s*x\s*(\d+)\s*", value)
    if not m:
        raise ValueError(f"invalid size: {value!r} (expected WxH)")
    w = int(m.group(1))
    h = int(m.group(2))
    if w <= 0 or h <= 0:
        raise ValueError(f"invalid size: {value!r} (W and H must be > 0)")
    return (w, h)


def ext_normalize(path: Path) -> str:
    ext = path.suffix.lower().lstrip(".")
    if ext == "jpeg":
        return "jpg"
    return ext


def output_supports_alpha(ext: str) -> bool:
    return ext in {"png", "webp"}


def is_non_alpha_format(ext: str) -> bool:
    return ext in {"jpg"}


@dataclasses.dataclass(frozen=True)
class Toolchain:
    magick: list[str] | None
    convert: list[str] | None
    identify: list[str]
    cwebp: str | None
    dwebp: str | None
    cjpeg: str | None
    djpeg: str | None

    @property
    def primary_backend(self) -> str:
        if self.magick:
            return "imagemagick:magick"
        if self.convert:
            return "imagemagick:convert"
        return "imagemagick:unknown"


def detect_toolchain() -> Toolchain:
    magick = shutil.which("magick")
    convert = shutil.which("convert")
    identify = shutil.which("identify")

    if magick:
        magick_cmd = [magick]
        identify_cmd = [magick, "identify"]
        convert_cmd = None
    elif convert and identify:
        magick_cmd = None
        identify_cmd = [identify]
        convert_cmd = [convert]
    else:
        raise RuntimeError("missing ImageMagick (need `magick` or both `convert` + `identify`)")

    return Toolchain(
        magick=magick_cmd,
        convert=convert_cmd,
        identify=identify_cmd,
        cwebp=shutil.which("cwebp"),
        dwebp=shutil.which("dwebp"),
        cjpeg=shutil.which("cjpeg"),
        djpeg=shutil.which("djpeg"),
    )


@dataclasses.dataclass
class ImageInfo:
    format: str | None = None
    width: int | None = None
    height: int | None = None
    channels: str | None = None
    alpha: bool | None = None
    exif_orientation: str | None = None
    size_bytes: int | None = None


def probe_image(toolchain: Toolchain, path: Path) -> ImageInfo:
    info = ImageInfo()
    try:
        info.size_bytes = path.stat().st_size
    except Exception:
        info.size_bytes = None

    fmt = "%m|%w|%h|%[channels]|%[exif:Orientation]"
    cmd = toolchain.identify + ["-ping", "-format", fmt, str(path)]
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        return info
    raw = proc.stdout.strip()
    if not raw:
        return info
    # identify might output multiple records (multi-frame); take the first line.
    first = raw.splitlines()[0]
    parts = first.split("|")
    if len(parts) >= 1 and parts[0]:
        info.format = parts[0].strip()
    if len(parts) >= 3:
        try:
            info.width = int(parts[1])
            info.height = int(parts[2])
        except Exception:
            pass
    if len(parts) >= 4 and parts[3]:
        info.channels = parts[3].strip()
        info.alpha = "a" in info.channels.lower()
    if len(parts) >= 5 and parts[4]:
        info.exif_orientation = parts[4].strip()
    return info


def expand_inputs(inputs: list[str], *, recursive: bool, globs: list[str]) -> list[Path]:
    if not inputs:
        raise ValueError("missing --in")

    patterns = [g.strip() for g in globs if g.strip()]

    def matches(path: Path) -> bool:
        if not patterns:
            return True
        name = path.name
        return any(fnmatch.fnmatch(name, pat) for pat in patterns)

    out: list[Path] = []
    seen: set[Path] = set()

    for raw in inputs:
        p = Path(raw).expanduser()
        if not p.exists():
            raise ValueError(f"input not found: {raw}")
        if p.is_file():
            rp = p.resolve()
            if matches(rp) and rp not in seen:
                out.append(rp)
                seen.add(rp)
            continue
        if not p.is_dir():
            continue

        if recursive:
            candidates = [Path(root) / f for root, _, files in os.walk(p) for f in files]
        else:
            candidates = [p / child for child in sorted(os.listdir(p))]  # type: ignore[arg-type]

        for c in sorted(candidates, key=lambda x: str(x)):
            if not c.is_file():
                continue
            rp = c.resolve()
            if not matches(rp):
                continue
            if rp in seen:
                continue
            out.append(rp)
            seen.add(rp)

    if not out:
        raise ValueError("no input files resolved from --in/--glob")
    return out


OutputModeName = Literal["out", "out_dir", "in_place"]


@dataclasses.dataclass(frozen=True)
class OutputMode:
    mode: OutputModeName
    out: Path | None
    out_dir: Path | None


def validate_output_mode(
    *,
    subcommand: str,
    out: str | None,
    out_dir: str | None,
    in_place: bool,
    yes: bool,
) -> OutputMode | None:
    if subcommand == "info":
        if out or out_dir or in_place:
            raise ValueError("info does not write outputs; do not pass --out/--out-dir/--in-place")
        return None

    chosen = [bool(out), bool(out_dir), bool(in_place)]
    if sum(1 for x in chosen if x) != 1:
        raise ValueError("must specify exactly one output mode: --out, --out-dir, or --in-place")
    if in_place and not yes:
        raise ValueError("--in-place is destructive and requires --yes")

    if out:
        return OutputMode(mode="out", out=Path(out).expanduser(), out_dir=None)
    if out_dir:
        return OutputMode(mode="out_dir", out=None, out_dir=Path(out_dir).expanduser())
    return OutputMode(mode="in_place", out=None, out_dir=None)


def check_overwrite(path: Path, *, overwrite: bool) -> None:
    if path.exists() and not overwrite:
        raise ValueError(f"output exists (pass --overwrite to replace): {path}")


def safe_write_path(path: Path, *, dry_run: bool) -> Path:
    # Write to a temp file next to the target, then rename.
    if dry_run:
        return path
    suffix = path.suffix
    tmp = path.with_name(f".{path.stem}.tmp-{uuid.uuid4().hex[:8]}{suffix}")
    return tmp


def atomic_replace(tmp: Path, final: Path, *, dry_run: bool) -> None:
    if dry_run:
        return
    tmp.replace(final)


def command_str(argv: list[str]) -> str:
    return " ".join(shlex.quote(a) for a in argv)


def compute_resize_box(
    *,
    orig_w: int,
    orig_h: int,
    scale: float | None,
    width: int | None,
    height: int | None,
    aspect: tuple[int, int] | None,
    fit: str | None,
) -> tuple[int, int, str | None, bool]:
    """
    Returns (target_w, target_h, fit_mode, uses_box).
    - uses_box=False means simple resize to exact dims (scale or one-dimension proportional).
    - uses_box=True means fit-mode box behavior (contain/cover/stretch).
    """
    if scale is not None:
        if width or height or aspect or fit:
            raise ValueError("--scale is mutually exclusive with --width/--height/--aspect/--fit")
        if scale <= 0:
            raise ValueError("--scale must be > 0")
        tw = max(1, int(round(orig_w * scale)))
        th = max(1, int(round(orig_h * scale)))
        return (tw, th, None, False)

    if aspect is None:
        if width is None and height is None:
            raise ValueError("resize requires one of: --scale, --width, --height, or --aspect + size")

        # proportional one-dimension resize
        if width is not None and height is None:
            tw = width
            if tw <= 0:
                raise ValueError("--width must be > 0")
            th = max(1, int(round(orig_h * (tw / orig_w))))
            if fit is not None:
                raise ValueError("--fit is only valid when a target box is fully specified")
            return (tw, th, None, False)

        if height is not None and width is None:
            th = height
            if th <= 0:
                raise ValueError("--height must be > 0")
            tw = max(1, int(round(orig_w * (th / orig_h))))
            if fit is not None:
                raise ValueError("--fit is only valid when a target box is fully specified")
            return (tw, th, None, False)

        # explicit box
        assert width is not None and height is not None
        if width <= 0 or height <= 0:
            raise ValueError("--width/--height must be > 0")
        if fit is None:
            raise ValueError("when using --width + --height, --fit contain|cover|stretch is required")
        if fit not in {"contain", "cover", "stretch"}:
            raise ValueError("--fit must be one of: contain, cover, stretch")
        return (width, height, fit, True)

    # aspect provided: must pair with size + explicit fit
    aw, ah = aspect
    if width is None and height is None:
        raise ValueError("when using --aspect, you must also specify --width or --height")
    if fit is None:
        raise ValueError("when using --aspect, --fit contain|cover|stretch is required")
    if fit not in {"contain", "cover", "stretch"}:
        raise ValueError("--fit must be one of: contain, cover, stretch")

    if width is not None and height is not None:
        # Validate aspect matches.
        if abs((width / height) - (aw / ah)) > 1e-6:
            raise ValueError("--width/--height must match --aspect")
        return (width, height, fit, True)

    if width is not None:
        if width <= 0:
            raise ValueError("--width must be > 0")
        height = max(1, int(round(width * (ah / aw))))
        return (width, height, fit, True)

    assert height is not None
    if height <= 0:
        raise ValueError("--height must be > 0")
    width = max(1, int(round(height * (aw / ah))))
    return (width, height, fit, True)


def require_background(reason: str) -> None:
    raise ValueError(f"{reason} (provide --background <color>)")


def build_magick_cmd(toolchain: Toolchain, input_path: Path) -> list[str]:
    if toolchain.magick:
        return toolchain.magick + [str(input_path)]
    if toolchain.convert:
        return toolchain.convert + [str(input_path)]
    raise RuntimeError("no ImageMagick backend available")


def run_one_magick(
    *,
    toolchain: Toolchain,
    cmd: list[str],
    dry_run: bool,
) -> tuple[int, str, str]:
    if dry_run:
        return (0, "", "")
    proc = subprocess.run(cmd, text=True, capture_output=True)
    return (proc.returncode, proc.stdout, proc.stderr)


def process_items(
    *,
    toolchain: Toolchain,
    repo_root: Path,
    run_dir: Path | None,
    subcommand: str,
    inputs: list[Path],
    output_mode: OutputMode | None,
    overwrite: bool,
    dry_run: bool,
    auto_orient_enabled: bool,
    strip_metadata: bool,
    background: str | None,
    report_enabled: bool,
    json_enabled: bool,
    # subcommand args:
    convert_to: str | None = None,
    quality: int | None = None,
    resize_scale: float | None = None,
    resize_width: int | None = None,
    resize_height: int | None = None,
    resize_aspect: tuple[int, int] | None = None,
    resize_fit: str | None = None,
    no_pre_upscale: bool = False,
    rotate_degrees: int | None = None,
    crop_rect: tuple[int, int, int, int] | None = None,
    crop_size: tuple[int, int] | None = None,
    crop_aspect: tuple[int, int] | None = None,
    crop_gravity: str = "center",
    pad_width: int | None = None,
    pad_height: int | None = None,
    pad_gravity: str = "center",
    optimize_lossless: bool = False,
    optimize_progressive: bool = True,
) -> dict[str, Any]:
    if report_enabled and subcommand == "info":
        raise ValueError("--report is not supported for info")

    if output_mode and output_mode.mode == "out":
        if len(inputs) != 1:
            raise ValueError("--out requires exactly one input file")

    # Resolve output paths for output-producing subcommands.
    planned: list[tuple[Path, Path | None]] = []
    collisions: list[dict[str, str]] = []
    out_by_path: dict[Path, Path] = {}

    def derive_out_path(inp: Path) -> Path:
        assert output_mode is not None
        if output_mode.mode == "in_place":
            return inp
        if output_mode.mode == "out":
            assert output_mode.out is not None
            return output_mode.out

        assert output_mode.mode == "out_dir"
        assert output_mode.out_dir is not None
        out_dir = output_mode.out_dir

        in_ext = ext_normalize(inp)
        out_ext = in_ext

        if subcommand == "convert":
            assert convert_to is not None
            out_ext = convert_to
        elif subcommand == "optimize":
            out_ext = in_ext

        filename = f"{inp.stem}.{out_ext}" if out_ext else inp.name
        return out_dir / filename

    if subcommand != "info":
        assert output_mode is not None
        for inp in inputs:
            out_path = derive_out_path(inp)
            out_abs = out_path.expanduser()
            if not out_abs.is_absolute():
                out_abs = (Path.cwd() / out_abs).resolve()

            if subcommand == "convert" and convert_to:
                ext = ext_normalize(out_abs)
                if ext != convert_to:
                    raise ValueError(f"--out extension must match --to {convert_to}: {out_abs}")

            if subcommand == "optimize":
                in_ext = ext_normalize(inp)
                out_ext = ext_normalize(out_abs)
                if out_ext != in_ext:
                    raise ValueError("optimize does not change formats; output extension must match input")
            elif subcommand != "convert":
                in_ext = ext_normalize(inp)
                out_ext = ext_normalize(out_abs)
                if out_ext != in_ext:
                    raise ValueError("only convert changes formats; output extension must match input")

            if output_mode.mode != "in_place":
                if out_abs in out_by_path:
                    collisions.append(
                        {
                            "path": str(out_abs),
                            "reason": f"multiple inputs map to the same output ({out_abs.name})",
                        }
                    )
                out_by_path[out_abs] = inp

            planned.append((inp, out_abs))

        if collisions:
            raise ValueError("output collisions detected; adjust --out-dir or inputs")

        # Overwrite checks (skip in-place).
        if output_mode.mode != "in_place":
            for _, out_abs in planned:
                assert out_abs is not None
                check_overwrite(out_abs, overwrite=overwrite)

            if report_enabled and run_dir:
                report_path = run_dir / "report.md"
                check_overwrite(report_path, overwrite=overwrite)

    commands: list[str] = []
    warnings: list[str] = []
    skipped: list[dict[str, str]] = []
    items: list[dict[str, Any]] = []

    # Ensure output dirs exist (for non-dry-run and non-in-place).
    if subcommand != "info":
        assert output_mode is not None
        if not dry_run and output_mode.mode == "out_dir":
            assert output_mode.out_dir is not None
            Path(output_mode.out_dir).expanduser().mkdir(parents=True, exist_ok=True)
        if not dry_run and output_mode.mode == "out":
            assert output_mode.out is not None
            ensure_parent_dir(Path(output_mode.out).expanduser(), dry_run=dry_run)

    for inp, out_abs in planned if subcommand != "info" else [(p, None) for p in inputs]:
        input_info = probe_image(toolchain, inp)
        input_alpha = bool(input_info.alpha)
        in_ext = ext_normalize(inp)
        out_ext = ext_normalize(out_abs) if out_abs else ""

        item_cmds: list[str] = []
        item_warnings: list[str] = []
        item_error: str | None = None
        out_info: ImageInfo | None = None

        try:
            if subcommand == "info":
                pass
            elif subcommand == "auto-orient":
                if rotate_degrees is not None:
                    raise ValueError("internal error: rotate_degrees set for auto-orient")
                assert out_abs is not None
                tmp = safe_write_path(out_abs, dry_run=dry_run)
                cmd = build_magick_cmd(toolchain, inp)
                cmd += ["-auto-orient"]
                if strip_metadata:
                    cmd += ["-strip"]
                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or "auto-orient failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand == "convert":
                assert convert_to is not None
                assert out_abs is not None
                if convert_to not in SUPPORTED_CONVERT_TARGETS:
                    raise ValueError(f"unsupported --to: {convert_to} (supported: png|jpg|webp)")
                tmp = safe_write_path(out_abs, dry_run=dry_run)
                cmd = build_magick_cmd(toolchain, inp)
                if auto_orient_enabled:
                    cmd += ["-auto-orient"]

                if convert_to == "jpg":
                    if input_alpha and not background:
                        require_background("alpha input cannot be converted to JPEG without a background")
                    if background:
                        cmd += ["-background", background]
                        cmd += ["-alpha", "remove", "-alpha", "off"]

                if quality is not None:
                    if quality < 0 or quality > 100:
                        raise ValueError("--quality must be 0..100")
                    cmd += ["-quality", str(quality)]

                if strip_metadata:
                    cmd += ["-strip"]

                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or "convert failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand == "resize":
                assert out_abs is not None
                if input_info.width is None or input_info.height is None:
                    raise ValueError("unable to read input dimensions for resize")
                tw, th, fit_mode, uses_box = compute_resize_box(
                    orig_w=input_info.width,
                    orig_h=input_info.height,
                    scale=resize_scale,
                    width=resize_width,
                    height=resize_height,
                    aspect=resize_aspect,
                    fit=resize_fit,
                )

                tmp = safe_write_path(out_abs, dry_run=dry_run)
                cmd = build_magick_cmd(toolchain, inp)
                if auto_orient_enabled:
                    cmd += ["-auto-orient"]

                pre_upscale = not no_pre_upscale
                if pre_upscale:
                    cmd += ["-resize", "200%"]

                if uses_box:
                    assert fit_mode is not None
                    box = f"{tw}x{th}"
                    gravity = "center"
                    if fit_mode == "stretch":
                        cmd += ["-resize", f"{box}!"]
                    elif fit_mode == "cover":
                        cmd += ["-resize", f"{box}^", "-gravity", gravity, "-extent", box]
                    elif fit_mode == "contain":
                        # "contain" emits exactly box size via padding.
                        cmd += ["-resize", box]
                        bg = background
                        if bg is None and output_supports_alpha(out_ext):
                            bg = "none"
                        if bg is None and is_non_alpha_format(out_ext):
                            require_background("contain fit requires padding background for non-alpha outputs")
                        if bg is not None:
                            cmd += ["-background", bg]
                        cmd += ["-gravity", gravity, "-extent", box]
                else:
                    cmd += ["-resize", f"{tw}x{th}!"]

                if strip_metadata:
                    cmd += ["-strip"]

                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or "resize failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand == "rotate":
                assert out_abs is not None
                if rotate_degrees is None:
                    raise ValueError("rotate requires --degrees")
                tmp = safe_write_path(out_abs, dry_run=dry_run)
                cmd = build_magick_cmd(toolchain, inp)
                if auto_orient_enabled:
                    cmd += ["-auto-orient"]

                bg = background
                if rotate_degrees % 90 != 0:
                    if bg is None and output_supports_alpha(out_ext):
                        bg = "none"
                    if bg is None and is_non_alpha_format(out_ext):
                        require_background("non-right-angle rotation requires a background for JPEG outputs")
                    if bg is not None:
                        cmd += ["-background", bg]
                cmd += ["-rotate", str(rotate_degrees)]

                if strip_metadata:
                    cmd += ["-strip"]
                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or "rotate failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand == "crop":
                assert out_abs is not None
                tmp = safe_write_path(out_abs, dry_run=dry_run)
                if input_info.width is None or input_info.height is None:
                    raise ValueError("unable to read input dimensions for crop")

                if sum(1 for x in [crop_rect, crop_size, crop_aspect] if x is not None) != 1:
                    raise ValueError("crop requires exactly one of: --rect, --size, --aspect")

                if crop_rect is not None:
                    cw, ch, cx, cy = crop_rect
                elif crop_size is not None:
                    cw, ch = crop_size
                    cx, cy = (0, 0)
                else:
                    assert crop_aspect is not None
                    aw, ah = crop_aspect
                    target_aspect = aw / ah
                    orig_aspect = input_info.width / input_info.height
                    if orig_aspect > target_aspect:
                        ch = input_info.height
                        cw = max(1, int(round(ch * target_aspect)))
                    else:
                        cw = input_info.width
                        ch = max(1, int(round(cw / target_aspect)))
                    cx, cy = (0, 0)

                if cw <= 0 or ch <= 0:
                    raise ValueError("invalid crop dimensions")
                if cw > input_info.width or ch > input_info.height:
                    raise ValueError("crop size exceeds input dimensions")

                cmd = build_magick_cmd(toolchain, inp)
                if auto_orient_enabled:
                    cmd += ["-auto-orient"]
                if crop_rect is not None:
                    cmd += ["-crop", f"{cw}x{ch}+{cx}+{cy}", "+repage"]
                else:
                    cmd += ["-gravity", crop_gravity, "-crop", f"{cw}x{ch}+{cx}+{cy}", "+repage"]
                if strip_metadata:
                    cmd += ["-strip"]
                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or "crop failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand == "pad":
                assert out_abs is not None
                if pad_width is None or pad_height is None:
                    raise ValueError("pad requires --width and --height")
                if input_info.width is None or input_info.height is None:
                    raise ValueError("unable to read input dimensions for pad")
                if pad_width < input_info.width or pad_height < input_info.height:
                    raise ValueError("pad target must be >= input dimensions (use crop or resize)")
                tmp = safe_write_path(out_abs, dry_run=dry_run)
                cmd = build_magick_cmd(toolchain, inp)
                if auto_orient_enabled:
                    cmd += ["-auto-orient"]

                bg = background
                if bg is None and output_supports_alpha(out_ext):
                    bg = "none"
                if bg is None and is_non_alpha_format(out_ext):
                    require_background("pad requires a background for non-alpha outputs")
                if bg is not None:
                    cmd += ["-background", bg]

                cmd += ["-gravity", pad_gravity, "-extent", f"{pad_width}x{pad_height}"]
                if strip_metadata:
                    cmd += ["-strip"]
                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or "pad failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand in {"flip", "flop"}:
                assert out_abs is not None
                tmp = safe_write_path(out_abs, dry_run=dry_run)
                cmd = build_magick_cmd(toolchain, inp)
                if auto_orient_enabled:
                    cmd += ["-auto-orient"]
                cmd += [f"-{subcommand}"]
                if strip_metadata:
                    cmd += ["-strip"]
                cmd += [str(tmp)]
                item_cmds.append(command_str(cmd))
                rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                if rc != 0:
                    raise RuntimeError(err.strip() or f"{subcommand} failed")
                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            elif subcommand == "optimize":
                assert out_abs is not None
                tmp = safe_write_path(out_abs, dry_run=dry_run)

                if quality is not None and (quality < 0 or quality > 100):
                    raise ValueError("--quality must be 0..100")

                # Determine output format from extension.
                if out_ext == "jpg":
                    if in_ext != "jpg":
                        raise ValueError("optimize for jpg expects jpg input")

                    q = 85 if quality is None else quality

                    if toolchain.cjpeg and toolchain.djpeg:
                        # djpeg -> cjpeg pipeline (metadata stripped implicitly).
                        djpeg_cmd = [toolchain.djpeg, str(inp)]
                        cjpeg_cmd = [toolchain.cjpeg, "-quality", str(q), "-optimize"]
                        if optimize_progressive:
                            cjpeg_cmd += ["-progressive"]
                        cjpeg_cmd += ["-outfile", str(tmp)]

                        item_cmds.append(command_str(djpeg_cmd) + " | " + command_str(cjpeg_cmd))
                        if not dry_run:
                            p1 = subprocess.Popen(djpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                            p2 = subprocess.Popen(
                                cjpeg_cmd,
                                stdin=p1.stdout,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                            )
                            assert p1.stdout is not None
                            p1.stdout.close()
                            _, err2 = p2.communicate()
                            _, err1 = p1.communicate()
                            if p1.returncode != 0:
                                raise RuntimeError((err1 or b"").decode("utf-8", errors="replace").strip() or "djpeg failed")
                            if p2.returncode != 0:
                                raise RuntimeError((err2 or b"").decode("utf-8", errors="replace").strip() or "cjpeg failed")
                    else:
                        cmd = build_magick_cmd(toolchain, inp)
                        if auto_orient_enabled:
                            cmd += ["-auto-orient"]
                        cmd += ["-quality", str(q)]
                        if optimize_progressive:
                            cmd += ["-interlace", "Plane"]
                        if strip_metadata:
                            cmd += ["-strip"]
                        cmd += [str(tmp)]
                        item_cmds.append(command_str(cmd))
                        rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                        if rc != 0:
                            raise RuntimeError(err.strip() or "optimize jpg failed")

                elif out_ext == "webp":
                    if in_ext != "webp":
                        raise ValueError("optimize for webp expects webp input")

                    q = 80 if quality is None else quality
                    if toolchain.cwebp and toolchain.dwebp:
                        # Decode to PAM to preserve alpha, then re-encode.
                        tmp_pam = tmp.parent / f".tmp-{uuid.uuid4().hex[:8]}.pam"
                        dwebp_cmd = [toolchain.dwebp, str(inp), "-pam", "-o", str(tmp_pam)]
                        cwebp_cmd = [toolchain.cwebp]
                        if optimize_lossless:
                            cwebp_cmd += ["-lossless"]
                        else:
                            cwebp_cmd += ["-q", str(q)]
                        if strip_metadata:
                            cwebp_cmd += ["-metadata", "none"]
                        cwebp_cmd += [str(tmp_pam), "-o", str(tmp)]
                        item_cmds.append(command_str(dwebp_cmd))
                        item_cmds.append(command_str(cwebp_cmd))
                        if not dry_run:
                            p1 = subprocess.run(dwebp_cmd, text=True, capture_output=True)
                            if p1.returncode != 0:
                                raise RuntimeError(p1.stderr.strip() or p1.stdout.strip() or "dwebp failed")
                            p2 = subprocess.run(cwebp_cmd, text=True, capture_output=True)
                            if p2.returncode != 0:
                                raise RuntimeError(p2.stderr.strip() or p2.stdout.strip() or "cwebp failed")
                            try:
                                tmp_pam.unlink()
                            except Exception:
                                pass
                    else:
                        cmd = build_magick_cmd(toolchain, inp)
                        if auto_orient_enabled:
                            cmd += ["-auto-orient"]
                        if optimize_lossless:
                            cmd += ["-define", "webp:lossless=true"]
                        else:
                            cmd += ["-quality", str(q)]
                        if strip_metadata:
                            cmd += ["-strip"]
                        cmd += [str(tmp)]
                        item_cmds.append(command_str(cmd))
                        rc, _, err = run_one_magick(toolchain=toolchain, cmd=cmd, dry_run=dry_run)
                        if rc != 0:
                            raise RuntimeError(err.strip() or "optimize webp failed")
                else:
                    raise ValueError("optimize currently supports only jpg/webp outputs")

                if not dry_run:
                    atomic_replace(tmp, out_abs, dry_run=dry_run)
                    out_info = probe_image(toolchain, out_abs)
            else:
                raise ValueError(f"unknown subcommand: {subcommand}")
        except Exception as exc:
            item_error = str(exc)

        for c in item_cmds:
            commands.append(c)

        item: dict[str, Any] = {
            "input_path": maybe_relpath(inp, repo_root),
            "output_path": maybe_relpath(out_abs, repo_root) if out_abs else None,
            "status": "ok" if item_error is None else "error",
            "input_info": dataclasses.asdict(input_info),
            "output_info": dataclasses.asdict(out_info) if out_info else None,
            "commands": item_cmds,
            "warnings": item_warnings,
            "error": item_error,
        }
        items.append(item)

    report_path: str | None = None
    if report_enabled and run_dir is not None:
        report_md = render_report_md(
            run_id=str(run_dir.name),
            subcommand=subcommand,
            items=items,
            commands=commands,
            dry_run=dry_run,
        )
        report_file = run_dir / "report.md"
        report_file.write_text(report_md, encoding="utf-8")
        report_path = maybe_relpath(report_file, repo_root)

    summary = {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_dir.name if run_dir else None,
        "cwd": str(Path.cwd()),
        "operation": subcommand,
        "backend": toolchain.primary_backend,
        "report_path": report_path,
        "dry_run": dry_run,
        "options": {
            "overwrite": overwrite,
            "auto_orient": auto_orient_enabled if subcommand not in {"info", "auto-orient"} else None,
            "strip_metadata": strip_metadata,
            "background": background,
            "report": report_enabled,
        },
        "commands": commands,
        "collisions": collisions,
        "skipped": skipped,
        "warnings": warnings,
        "items": items,
    }

    if run_dir is not None:
        summary_file = run_dir / "summary.json"
        summary_file.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    return summary


def maybe_relpath(path: Path | None, repo_root: Path) -> str | None:
    if path is None:
        return None
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except Exception:
        return path.resolve().as_posix()


def render_report_md(
    *,
    run_id: str,
    subcommand: str,
    items: list[dict[str, Any]],
    commands: list[str],
    dry_run: bool,
) -> str:
    lines: list[str] = []
    lines.append(f"# Image Processing Report ({run_id})")
    lines.append("")
    lines.append(f"- Operation: `{subcommand}`")
    lines.append(f"- Dry run: `{str(dry_run).lower()}`")
    lines.append("")

    lines.append("## Commands")
    for c in commands:
        lines.append(f"- `{c}`")
    lines.append("")

    lines.append("## Results")
    for item in items:
        status = item.get("status")
        inp = item.get("input_path")
        outp = item.get("output_path")
        lines.append(f"- `{status}`: `{inp}` -> `{outp}`")
        in_info = item.get("input_info") or {}
        out_info = item.get("output_info") or {}
        in_size = in_info.get("size_bytes")
        out_size = out_info.get("size_bytes")
        if isinstance(in_size, int):
            lines.append(f"  - input_bytes: {in_size}")
        if isinstance(out_size, int):
            lines.append(f"  - output_bytes: {out_size}")
        if isinstance(in_size, int) and isinstance(out_size, int) and in_size > 0:
            delta = out_size - in_size
            pct = (delta / in_size) * 100.0
            lines.append(f"  - delta_bytes: {delta} ({pct:.2f}%)")
        if item.get("error"):
            lines.append(f"  - error: {item['error']}")
    lines.append("")

    return "\n".join(lines) + "\n"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="image-processing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Batch image transformations (convert/resize/rotate/crop/pad/optimize).",
        epilog=textwrap.dedent(
            """\
            Notes:
              - Output-producing subcommands require exactly one output mode: --out, --out-dir, or --in-place (with --yes).
              - Use --json for machine-readable output (stdout JSON only; logs go to stderr).
            """
        ),
    )

    parser.add_argument("subcommand", choices=[
        "info",
        "auto-orient",
        "convert",
        "resize",
        "rotate",
        "crop",
        "pad",
        "flip",
        "flop",
        "optimize",
    ])

    parser.add_argument("--in", dest="inputs", action="append", default=[], help="Input file or directory (repeatable)")
    parser.add_argument("--recursive", action="store_true", help="Recurse into input directories")
    parser.add_argument("--glob", action="append", default=[], help="Filter candidates by glob (repeatable, e.g. *.png)")

    out_group = parser.add_argument_group("Output mode (required for output-producing subcommands)")
    out_group.add_argument("--out", default=None, help="Single output file path (single input only)")
    out_group.add_argument("--out-dir", default=None, help="Output directory for batch runs")
    out_group.add_argument("--in-place", action="store_true", help="Modify inputs in-place (requires --yes)")

    parser.add_argument("--yes", action="store_true", help="Confirm destructive operations (required for --in-place)")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite outputs if they already exist")
    parser.add_argument("--dry-run", action="store_true", help="Print planned actions; do not write outputs")
    parser.add_argument("--json", action="store_true", help="Emit JSON summary to stdout and write summary.json under out/")
    parser.add_argument("--report", action="store_true", help="Write report.md under out/ and include report_path in JSON")

    parser.add_argument("--no-auto-orient", dest="auto_orient", action="store_false", default=True, help="Disable auto-orient for output-producing operations")
    parser.add_argument("--strip-metadata", action="store_true", help="Remove metadata (EXIF/XMP/ICC) from outputs")
    parser.add_argument("--background", default=None, help="Background color used for alpha flattening/padding when required")

    # Subcommand options
    parser.add_argument("--to", default=None, help="(convert) Target format: png|jpg|webp")
    parser.add_argument("--quality", type=int, default=None, help="(convert/optimize) Quality 0..100")

    parser.add_argument("--scale", type=float, default=None, help="(resize) Scale factor (e.g. 2)")
    parser.add_argument("--width", type=int, default=None, help="(resize/pad) Target width")
    parser.add_argument("--height", type=int, default=None, help="(resize/pad) Target height")
    parser.add_argument("--aspect", default=None, help="(resize/crop) Aspect ratio W:H")
    parser.add_argument("--fit", default=None, help="(resize) contain|cover|stretch (required for box/aspect)")
    parser.add_argument("--no-pre-upscale", action="store_true", help="(resize) Disable the default 2x pre-upscale step")

    parser.add_argument("--degrees", type=int, default=None, help="(rotate) Degrees clockwise")

    parser.add_argument("--rect", default=None, help="(crop) Rect geometry WxH+X+Y")
    parser.add_argument("--size", default=None, help="(crop) Crop size WxH (uses --gravity)")
    parser.add_argument("--gravity", default="center", help="(crop/pad) Gravity/anchor (default: center)")

    parser.add_argument("--lossless", action="store_true", help="(optimize webp) Use lossless encoding")
    parser.add_argument("--no-progressive", dest="progressive", action="store_false", default=True, help="(optimize jpg) Disable progressive encoding")

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        toolchain = detect_toolchain()
    except Exception as exc:
        eprint(f"image-processing: error: {exc}")
        return 1

    repo_root = find_repo_root()
    run_dir: Path | None = None

    # Expand inputs early.
    try:
        inputs = expand_inputs(args.inputs, recursive=args.recursive, globs=args.glob)
    except Exception as exc:
        parser.error(str(exc))
        return 2

    # Validate output mode.
    try:
        output_mode = validate_output_mode(
            subcommand=args.subcommand,
            out=args.out,
            out_dir=args.out_dir,
            in_place=args.in_place,
            yes=args.yes,
        )
    except Exception as exc:
        parser.error(str(exc))
        return 2

    # Validate subcommand-specific requirements.
    # Also reject irrelevant flags to avoid silently ignoring user intent.
    def forbid(flag: str) -> None:
        parser.error(f"{args.subcommand} does not support {flag}")

    if args.subcommand != "convert" and args.to:
        forbid("--to")
        return 2
    if args.subcommand not in {"convert", "optimize"} and args.quality is not None:
        forbid("--quality")
        return 2

    if args.subcommand != "resize":
        if args.scale is not None:
            forbid("--scale")
            return 2
        if args.fit is not None:
            forbid("--fit")
            return 2
        if args.no_pre_upscale:
            forbid("--no-pre-upscale")
            return 2

    if args.subcommand not in {"resize", "pad"}:
        if args.width is not None:
            forbid("--width")
            return 2
        if args.height is not None:
            forbid("--height")
            return 2

    if args.subcommand not in {"resize", "crop"} and args.aspect:
        forbid("--aspect")
        return 2

    if args.subcommand != "rotate" and args.degrees is not None:
        forbid("--degrees")
        return 2

    if args.subcommand not in {"crop", "pad"}:
        if args.rect is not None:
            forbid("--rect")
            return 2
        if args.size is not None:
            forbid("--size")
            return 2
        if args.gravity != "center":
            forbid("--gravity")
            return 2

    if args.subcommand != "optimize":
        if args.lossless:
            forbid("--lossless")
            return 2
        if not args.progressive:
            forbid("--no-progressive")
            return 2

    resize_aspect: tuple[int, int] | None = None
    crop_aspect: tuple[int, int] | None = None

    if args.subcommand == "convert":
        if not args.to:
            parser.error("convert requires --to png|jpg|webp")
            return 2
        if args.to not in SUPPORTED_CONVERT_TARGETS:
            parser.error("convert --to must be one of: png|jpg|webp")
            return 2

    if args.subcommand == "resize":
        if args.aspect:
            try:
                resize_aspect = parse_aspect(args.aspect)
            except Exception as exc:
                parser.error(str(exc))
                return 2

    if args.subcommand == "crop":
        if args.aspect:
            try:
                crop_aspect = parse_aspect(args.aspect)
            except Exception as exc:
                parser.error(str(exc))
                return 2

    crop_rect: tuple[int, int, int, int] | None = None
    crop_size: tuple[int, int] | None = None
    if args.subcommand == "crop":
        if args.rect:
            try:
                crop_rect = parse_geometry(args.rect)
            except Exception as exc:
                parser.error(str(exc))
                return 2
        if args.size:
            try:
                crop_size = parse_size(args.size)
            except Exception as exc:
                parser.error(str(exc))
                return 2
        if sum(1 for x in [bool(args.rect), bool(args.size), bool(args.aspect)] if x) != 1:
            parser.error("crop requires exactly one of: --rect, --size, or --aspect")
            return 2

    if args.subcommand == "rotate":
        if args.degrees is None:
            parser.error("rotate requires --degrees")
            return 2

    if args.subcommand == "pad":
        if args.width is None or args.height is None:
            parser.error("pad requires --width and --height")
            return 2

    if args.subcommand == "optimize":
        # optimize does not change format; ensure output extension matches input.
        pass

    # Preflight: user-error validations that depend on inputs should still exit 2.
    if args.subcommand == "convert" and args.to == "jpg" and not args.background:
        # Only required when the input actually has alpha.
        for p in inputs:
            info = probe_image(toolchain, p)
            if info.alpha:
                parser.error("alpha input cannot be converted to JPEG without a background (provide --background <color>)")
                return 2

    if args.subcommand == "resize":
        if args.fit is not None and args.fit not in {"contain", "cover", "stretch"}:
            parser.error("resize --fit must be one of: contain, cover, stretch")
            return 2
        if args.aspect and not args.fit:
            parser.error("resize with --aspect requires --fit contain|cover|stretch")
            return 2
        if args.width is not None and args.height is not None and not args.fit:
            parser.error("resize with --width + --height requires --fit contain|cover|stretch")
            return 2

    if args.json or args.report:
        run_id = now_run_id()
        run_dir = repo_root / "out" / "image-processing" / "runs" / run_id
        run_dir.mkdir(parents=True, exist_ok=True)

    try:
        summary = process_items(
            toolchain=toolchain,
            repo_root=repo_root,
            run_dir=run_dir,
            subcommand=args.subcommand,
            inputs=inputs,
            output_mode=output_mode,
            overwrite=args.overwrite,
            dry_run=args.dry_run,
            auto_orient_enabled=bool(args.auto_orient),
            strip_metadata=bool(args.strip_metadata),
            background=args.background,
            report_enabled=bool(args.report),
            json_enabled=bool(args.json),
            convert_to=args.to,
            quality=args.quality,
            resize_scale=args.scale,
            resize_width=args.width if args.subcommand == "resize" else None,
            resize_height=args.height if args.subcommand == "resize" else None,
            resize_aspect=resize_aspect,
            resize_fit=args.fit,
            no_pre_upscale=bool(args.no_pre_upscale),
            rotate_degrees=args.degrees,
            crop_rect=crop_rect,
            crop_size=crop_size,
            crop_aspect=crop_aspect,
            crop_gravity=args.gravity,
            pad_width=args.width if args.subcommand == "pad" else None,
            pad_height=args.height if args.subcommand == "pad" else None,
            pad_gravity=args.gravity,
            optimize_lossless=bool(args.lossless),
            optimize_progressive=bool(args.progressive),
        )
    except SystemExit as exc:
        return int(exc.code or 1)
    except ValueError as exc:
        parser.error(str(exc))
        return 2
    except Exception as exc:
        eprint(f"image-processing: error: {exc}")
        return 1

    # Emit summary.
    if args.json:
        sys.stdout.write(json.dumps(summary, ensure_ascii=False))
        sys.stdout.write("\n")
    else:
        # Human summary to stdout.
        sys.stdout.write(f"operation: {summary.get('operation')}\n")
        if run_dir is not None:
            sys.stdout.write(f"run_dir: {maybe_relpath(run_dir, repo_root) or str(run_dir)}\n")
        for item in summary.get("items") or []:
            status = item.get("status")
            inp = item.get("input_path")
            outp = item.get("output_path")
            sys.stdout.write(f"- {status}: {inp} -> {outp}\n")

    # Exit status: non-zero if any item errored.
    any_error = any((item.get("status") == "error") for item in (summary.get("items") or []))
    return 1 if any_error else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
