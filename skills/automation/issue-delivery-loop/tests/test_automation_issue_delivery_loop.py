from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_automation_issue_delivery_loop_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_issue_delivery_loop_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/manage_issue_delivery_loop.sh",
        ],
    )


def test_issue_delivery_loop_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is limited to issue orchestration" in text
    assert "Main-agent must not implement issue tasks directly." in text
    assert "implementation must be produced by a subagent PR" in text


def test_issue_delivery_loop_script_enforces_subagent_owner_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "manage_issue_delivery_loop.sh").read_text(encoding="utf-8")
    assert "enforce_subagent_owner_policy" in text
    assert "Owner must not be main-agent" in text
    assert "Owner must include 'subagent'" in text
    assert "pr_refs=()" in text
    assert "Tasks [" in text
    assert "(tasks: " in text
