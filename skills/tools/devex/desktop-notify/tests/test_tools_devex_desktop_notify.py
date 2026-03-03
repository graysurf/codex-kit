from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_tools_devex_desktop_notify_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_devex_desktop_notify_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/desktop-notify.sh",
            "scripts/project-notify.sh",
        ],
    )


def test_tools_devex_desktop_notify_legacy_codex_wrapper_removed() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    legacy_wrapper = "codex-notify" + ".sh"
    assert not (skill_root / "scripts" / legacy_wrapper).exists()
