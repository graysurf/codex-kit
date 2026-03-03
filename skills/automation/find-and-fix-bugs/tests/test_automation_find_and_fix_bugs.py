from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_automation_find_and_fix_bugs_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_find_and_fix_bugs_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/render_issues_pr.sh",
        ],
    )


def test_automation_find_and_fix_bugs_declares_canonical_entrypoint() -> None:
    text = (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")
    assert "## Entrypoint" in text
    assert "$AGENT_HOME/skills/automation/find-and-fix-bugs/scripts/render_issues_pr.sh" in text
    assert "legacy wrapper paths are not supported" in text.lower()
