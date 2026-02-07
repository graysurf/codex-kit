from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_tools_browser_chrome_devtools_debug_companion_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)
