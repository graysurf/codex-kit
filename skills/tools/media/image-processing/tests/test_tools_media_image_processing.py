from __future__ import annotations

import json
import os
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
    if code_home := os.environ.get("AGENT_HOME"):
        return Path(code_home).resolve()
    root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    return Path(root).resolve()


def _skill_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _fixtures_dir() -> Path:
    return _skill_root() / "assets" / "fixtures"


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


def _write_svg(path: Path, width: int = 80, height: int = 60) -> Path:
    path.write_text(
        (
            f"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {width} {height}\" "
            f"width=\"{width}\" height=\"{height}\">"
            "<rect x=\"2\" y=\"2\" width=\"76\" height=\"56\" fill=\"#0f62fe\"/>"
            "</svg>"
        ),
        encoding="utf-8",
    )
    return path


def _as_path_in_repo(path_like: str) -> Path:
    candidate = Path(path_like)
    if candidate.is_absolute():
        return candidate
    return _repo_root() / candidate


def test_image_processing_help() -> None:
    proc = _run(["--help"])
    assert proc.returncode == 0
    assert "usage:" in proc.stdout.lower()
    assert "convert" in proc.stdout
    assert "svg-validate" in proc.stdout


@pytest.mark.parametrize(
    "removed",
    ["info", "auto-orient", "resize", "rotate", "crop", "pad", "flip", "flop", "optimize"],
)
def test_removed_subcommands_are_usage_errors(removed: str) -> None:
    proc = _run([removed])
    assert proc.returncode == 2
    stderr = proc.stderr.lower()
    assert "invalid value" in stderr or "unrecognized subcommand" in stderr or "unknown subcommand" in stderr


def test_convert_from_svg_to_supported_outputs() -> None:
    out_dir = _unique_out_dir("convert-supported-outputs")
    input_svg = _write_svg(out_dir / "icon.svg")

    for to, expected_format in [("png", "PNG"), ("webp", "WEBP"), ("svg", "SVG")]:
        output = out_dir / f"icon-converted.{to}"
        j = _run_json(
            [
                "convert",
                "--from-svg",
                str(input_svg),
                "--to",
                to,
                "--out",
                str(output),
            ]
        )
        assert j["operation"] == "convert"
        assert j["source"]["mode"] == "from_svg"
        item = j["items"][0]
        assert item["status"] == "ok"
        assert output.is_file()
        assert item["output_info"]["format"] == expected_format


def test_convert_supports_raster_dimension_override() -> None:
    out_dir = _unique_out_dir("convert-raster-dimensions")
    input_svg = _write_svg(out_dir / "icon.svg")

    width_only = _run_json(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(out_dir / "icon-width.png"),
            "--width",
            "512",
        ]
    )
    assert width_only["items"][0]["output_info"]["width"] == 512
    assert width_only["items"][0]["output_info"]["height"] == 384

    exact_box = _run_json(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(out_dir / "icon-box.png"),
            "--width",
            "512",
            "--height",
            "512",
        ]
    )
    assert exact_box["items"][0]["output_info"]["width"] == 512
    assert exact_box["items"][0]["output_info"]["height"] == 512


def test_convert_requires_from_svg() -> None:
    fixture = _fixtures_dir() / "fixture_80x60.png"
    proc = _run(["convert", "--in", str(fixture), "--to", "png", "--out", str(fixture), "--json"])
    assert proc.returncode == 2
    assert "convert requires --from-svg" in proc.stderr


def test_convert_rejects_in_flag_and_invalid_target() -> None:
    out_dir = _unique_out_dir("convert-invalid-flags")
    input_svg = _write_svg(out_dir / "icon.svg")

    with_in = _run(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--in",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(out_dir / "icon.png"),
            "--json",
        ]
    )
    assert with_in.returncode == 2
    assert "does not support --in" in with_in.stderr

    invalid_target = _run(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "jpg",
            "--out",
            str(out_dir / "icon.jpg"),
            "--json",
        ]
    )
    assert invalid_target.returncode == 2
    assert "png|webp|svg" in invalid_target.stderr


def test_convert_rejects_missing_out_and_extension_mismatch() -> None:
    out_dir = _unique_out_dir("convert-out-contract")
    input_svg = _write_svg(out_dir / "icon.svg")

    missing_out = _run(["convert", "--from-svg", str(input_svg), "--to", "png", "--json"])
    assert missing_out.returncode == 2
    assert "requires --out" in missing_out.stderr

    mismatch = _run(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(out_dir / "icon.webp"),
            "--json",
        ]
    )
    assert mismatch.returncode == 2
    assert "--out extension must match --to png" in mismatch.stderr


def test_convert_rejects_invalid_dimension_contracts() -> None:
    out_dir = _unique_out_dir("convert-dimension-contracts")
    input_svg = _write_svg(out_dir / "icon.svg")

    svg_with_width = _run(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "svg",
            "--out",
            str(out_dir / "icon.svg"),
            "--width",
            "256",
            "--json",
        ]
    )
    assert svg_with_width.returncode == 2
    assert "does not support --width/--height" in svg_with_width.stderr

    width_zero = _run(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(out_dir / "icon.png"),
            "--width",
            "0",
            "--json",
        ]
    )
    assert width_zero.returncode == 2
    assert "--width must be > 0" in width_zero.stderr


def test_convert_overwrite_flag_controls_output_replacement() -> None:
    out_dir = _unique_out_dir("convert-overwrite")
    input_svg = _write_svg(out_dir / "icon.svg")
    output = out_dir / "icon.png"
    output.write_text("existing", encoding="utf-8")

    blocked = _run(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(output),
            "--json",
        ]
    )
    assert blocked.returncode == 2
    assert "output exists (pass --overwrite to replace)" in blocked.stderr

    replaced = _run_json(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "png",
            "--out",
            str(output),
            "--overwrite",
        ]
    )
    assert replaced["items"][0]["status"] == "ok"
    assert output.is_file()
    assert output.read_bytes() != b"existing"


def test_svg_validate_success() -> None:
    out_dir = _unique_out_dir("svg-validate-success")
    input_svg = _write_svg(out_dir / "valid.svg")
    output_svg = out_dir / "valid.cleaned.svg"

    j = _run_json(["svg-validate", "--in", str(input_svg), "--out", str(output_svg)])
    assert j["operation"] == "svg-validate"
    assert j["source"]["mode"] == "svg_validate"
    assert output_svg.is_file()
    assert j["items"][0]["status"] == "ok"
    assert j["items"][0]["output_info"]["format"] == "SVG"


def test_svg_validate_requires_single_input_and_out() -> None:
    out_dir = _unique_out_dir("svg-validate-contract")
    one = _write_svg(out_dir / "one.svg")
    two = _write_svg(out_dir / "two.svg")

    missing_out = _run(["svg-validate", "--in", str(one)])
    assert missing_out.returncode == 2
    assert "svg-validate requires --out" in missing_out.stderr

    many_inputs = _run(
        [
            "svg-validate",
            "--in",
            str(one),
            "--in",
            str(two),
            "--out",
            str(out_dir / "out.svg"),
        ]
    )
    assert many_inputs.returncode == 2
    assert "requires exactly one --in" in many_inputs.stderr


def test_svg_validate_rejects_convert_only_flags() -> None:
    out_dir = _unique_out_dir("svg-validate-flags")
    one = _write_svg(out_dir / "one.svg")

    proc = _run(
        [
            "svg-validate",
            "--in",
            str(one),
            "--out",
            str(out_dir / "one.cleaned.svg"),
            "--to",
            "png",
            "--json",
        ]
    )
    assert proc.returncode == 2
    assert "does not support --to" in proc.stderr


def test_svg_validate_invalid_svg_returns_error_summary() -> None:
    out_dir = _unique_out_dir("svg-validate-invalid")
    invalid_svg = out_dir / "invalid.svg"
    invalid_svg.write_text(
        "<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>",
        encoding="utf-8",
    )
    output = out_dir / "invalid.cleaned.svg"

    proc = _run(["svg-validate", "--in", str(invalid_svg), "--out", str(output), "--json"])
    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    item = payload["items"][0]
    assert item["status"] == "error"
    error = item.get("error") or ""
    assert any(token in error for token in ["missing_viewbox", "disallowed_tag", "unsafe_tag"])


def test_report_written() -> None:
    out_dir = _unique_out_dir("report")
    input_svg = _write_svg(out_dir / "icon.svg")
    output = out_dir / "icon.webp"

    j = _run_json(
        [
            "convert",
            "--from-svg",
            str(input_svg),
            "--to",
            "webp",
            "--out",
            str(output),
            "--report",
        ]
    )
    report_path = j.get("report_path")
    assert isinstance(report_path, str) and report_path
    assert _as_path_in_repo(report_path).is_file()
