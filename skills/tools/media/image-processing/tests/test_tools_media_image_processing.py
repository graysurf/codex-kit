from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest

from skills._shared.python.skill_testing import assert_skill_contract, resolve_codex_command


def test_tools_media_image_processing_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_media_image_processing_command_exists() -> None:
    resolve_codex_command("image-processing")


def _repo_root() -> Path:
    if code_home := os.environ.get("AGENTS_HOME"):
        return Path(code_home).resolve()
    root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    return Path(root).resolve()


def _skill_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _fixtures_dir() -> Path:
    return _skill_root() / "assets" / "fixtures"


def _ensure_imagemagick() -> None:
    has_magick = shutil.which("magick") is not None
    has_convert = shutil.which("convert") is not None
    has_identify = shutil.which("identify") is not None
    if not (has_magick or (has_convert and has_identify)):
        pytest.skip("ImageMagick not installed (need magick or convert+identify)")


def _unique_out_dir(case: str) -> Path:
    base = _repo_root() / "out" / "tests" / "image-processing"
    path = base / f"{case}-{time.time_ns()}"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
    image_processing = resolve_codex_command("image-processing")
    return subprocess.run(
        [str(image_processing), *args],
        text=True,
        capture_output=True,
    )


def _run_json(args: list[str]) -> dict:
    proc = _run([*args, "--json"])
    if proc.returncode != 0:
        raise AssertionError(f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")
    return json.loads(proc.stdout)


def test_image_processing_help() -> None:
    proc = _run(["--help"])
    assert proc.returncode == 0
    assert "usage:" in proc.stdout.lower()


def test_info_json() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    j = _run_json(["info", "--in", str(fixture)])
    assert j["operation"] == "info"
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_path"] is None
    assert j["items"][0]["input_info"]["width"] == 80
    assert j["items"][0]["input_info"]["height"] == 60


def test_auto_orient() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60_exif_orientation_6.jpg"
    out_dir = _unique_out_dir("auto-orient")
    out_file = out_dir / "auto.jpg"
    j = _run_json(["auto-orient", "--in", str(fixture), "--out", str(out_file)])
    item = j["items"][0]
    assert item["status"] == "ok"
    assert out_file.is_file()
    assert item["output_info"]["width"] == 60
    assert item["output_info"]["height"] == 80
    assert item["output_info"]["exif_orientation"] in (None, "1")


def test_convert_png_to_webp() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("convert-webp")
    out_file = out_dir / "fixture.webp"
    j = _run_json(["convert", "--in", str(fixture), "--to", "webp", "--out", str(out_file)])
    item = j["items"][0]
    assert item["status"] == "ok"
    assert out_file.is_file()
    assert item["output_info"]["format"] == "WEBP"
    assert item["output_info"]["width"] == 80
    assert item["output_info"]["height"] == 60


def test_convert_alpha_to_jpg_requires_background() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60_alpha.png"
    out_dir = _unique_out_dir("alpha-to-jpg")
    out_file = out_dir / "alpha.jpg"

    proc = _run(
        [
            "convert",
            "--in",
            str(fixture),
            "--to",
            "jpg",
            "--out",
            str(out_file),
            "--json",
        ]
    )
    assert proc.returncode == 2
    assert "background" in proc.stderr.lower()

    j = _run_json(
        [
            "convert",
            "--in",
            str(fixture),
            "--to",
            "jpg",
            "--background",
            "white",
            "--out",
            str(out_file),
        ]
    )
    assert j["items"][0]["status"] == "ok"
    assert out_file.is_file()
    assert j["items"][0]["output_info"]["format"] == "JPEG"


def test_resize_scale_2() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("resize-scale")
    out_file = out_dir / "scaled.png"
    j = _run_json(["resize", "--in", str(fixture), "--scale", "2", "--out", str(out_file)])
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["width"] == 160
    assert j["items"][0]["output_info"]["height"] == 120


def test_resize_aspect_requires_fit() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("resize-aspect-missing-fit")
    out_file = out_dir / "out.png"
    proc = _run(
        [
            "resize",
            "--in",
            str(fixture),
            "--aspect",
            "16:9",
            "--width",
            "160",
            "--out",
            str(out_file),
            "--json",
        ]
    )
    assert proc.returncode == 2
    assert "--fit" in proc.stderr


def test_rotate_90() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("rotate")
    out_file = out_dir / "rot.png"
    j = _run_json(["rotate", "--in", str(fixture), "--degrees", "90", "--out", str(out_file)])
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["width"] == 60
    assert j["items"][0]["output_info"]["height"] == 80


def test_crop_aspect_1_1() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("crop")
    out_file = out_dir / "square.png"
    j = _run_json(["crop", "--in", str(fixture), "--aspect", "1:1", "--out", str(out_file)])
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["width"] == 60
    assert j["items"][0]["output_info"]["height"] == 60


def test_pad_to_100x100() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("pad")
    out_file = out_dir / "pad.png"
    j = _run_json(["pad", "--in", str(fixture), "--width", "100", "--height", "100", "--out", str(out_file)])
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["width"] == 100
    assert j["items"][0]["output_info"]["height"] == 100


def test_flip_flop() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("flip-flop")
    out_flip = out_dir / "flip.png"
    out_flop = out_dir / "flop.png"
    j1 = _run_json(["flip", "--in", str(fixture), "--out", str(out_flip)])
    j2 = _run_json(["flop", "--in", str(fixture), "--out", str(out_flop)])
    assert j1["items"][0]["status"] == "ok"
    assert j2["items"][0]["status"] == "ok"
    assert j1["items"][0]["output_info"]["width"] == 80
    assert j1["items"][0]["output_info"]["height"] == 60
    assert j2["items"][0]["output_info"]["width"] == 80
    assert j2["items"][0]["output_info"]["height"] == 60


def test_optimize_jpg_and_webp() -> None:
    _ensure_imagemagick()
    out_dir = _unique_out_dir("optimize")

    jpg_in = _fixtures_dir() / "fixture_80x60.jpg"
    jpg_out = out_dir / "opt.jpg"
    j = _run_json(["optimize", "--in", str(jpg_in), "--quality", "85", "--out", str(jpg_out)])
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["format"] == "JPEG"
    assert jpg_out.is_file()

    webp_in = _fixtures_dir() / "fixture_80x60.webp"
    webp_out = out_dir / "opt.webp"
    j = _run_json(["optimize", "--in", str(webp_in), "--quality", "80", "--out", str(webp_out)])
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["format"] == "WEBP"
    assert webp_out.is_file()


def test_negative_missing_output_mode() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    proc = _run(["convert", "--in", str(fixture), "--to", "webp", "--json"])
    assert proc.returncode == 2
    assert "output mode" in proc.stderr.lower()


def test_negative_in_place_requires_yes() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    proc = _run(["flip", "--in", str(fixture), "--in-place", "--json"])
    assert proc.returncode == 2
    assert "--yes" in proc.stderr


def test_strip_metadata_removes_exif_orientation() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60_exif_orientation_6.jpg"
    out_dir = _unique_out_dir("strip-metadata")
    out_keep = out_dir / "keep.jpg"
    out_strip = out_dir / "strip.jpg"

    keep = _run_json(
        [
            "convert",
            "--in",
            str(fixture),
            "--to",
            "jpg",
            "--no-auto-orient",
            "--out",
            str(out_keep),
        ]
    )
    assert keep["items"][0]["output_info"]["exif_orientation"] == "6"

    stripped = _run_json(
        [
            "convert",
            "--in",
            str(fixture),
            "--to",
            "jpg",
            "--no-auto-orient",
            "--strip-metadata",
            "--out",
            str(out_strip),
        ]
    )
    assert stripped["items"][0]["output_info"]["exif_orientation"] in (None, "1")


def test_report_written() -> None:
    _ensure_imagemagick()
    fixture = _fixtures_dir() / "fixture_80x60.png"
    out_dir = _unique_out_dir("report")
    out_file = out_dir / "fixture.webp"
    j = _run_json(["convert", "--in", str(fixture), "--to", "webp", "--out", str(out_file), "--report"])
    report_path = j.get("report_path")
    assert isinstance(report_path, str) and report_path
    assert (_repo_root() / report_path).is_file()
