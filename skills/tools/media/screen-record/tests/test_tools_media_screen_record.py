from __future__ import annotations

import os
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract, resolve_codex_command


def test_tools_media_screen_record_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)

def _run(args: list[str], *, extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    screen_record = resolve_codex_command("screen-record")
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        [str(screen_record), *args],
        text=True,
        capture_output=True,
        env=env,
    )


def test_tools_media_screen_record_command_exists() -> None:
    resolve_codex_command("screen-record")


def test_tools_media_screen_record_docs_include_latest_capture_modes() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    skill_doc = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    guide_doc = (skill_root / "references" / "SCREEN_RECORD_GUIDE.md").read_text(encoding="utf-8")

    assert "--screenshot" in skill_doc
    assert "--image-format" in skill_doc
    assert "--if-changed" in skill_doc
    assert "--metadata-out" in skill_doc
    assert "--diagnostics-out" in skill_doc
    assert "--portal" in skill_doc

    assert "--screenshot --active-window" in guide_doc
    assert "--if-changed-threshold" in guide_doc
    assert "--metadata-out" in guide_doc
    assert "--diagnostics-out" in guide_doc


def test_screen_record_help() -> None:
    proc = _run(["--help"])
    assert proc.returncode == 0
    assert "usage" in proc.stdout.lower()


def test_list_windows_test_mode() -> None:
    proc = _run(["--list-windows"], extra_env={"CODEX_SCREEN_RECORD_TEST_MODE": "1"})
    assert proc.returncode == 0
    assert proc.stderr == ""
    assert proc.stdout.splitlines() == [
        "200\tFinder\tFinder\t80\t80\t900\t600\ttrue",
        "101\tTerminal\tDocs\t40\t40\t1100\t760\ttrue",
        "100\tTerminal\tInbox\t0\t0\t1200\t800\ttrue",
    ]


def test_list_apps_test_mode() -> None:
    proc = _run(["--list-apps"], extra_env={"CODEX_SCREEN_RECORD_TEST_MODE": "1"})
    assert proc.returncode == 0
    assert proc.stderr == ""
    assert proc.stdout.splitlines() == [
        "Finder\t222\tcom.apple.Finder",
        "Terminal\t111\tcom.apple.Terminal",
    ]
