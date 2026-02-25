from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_automation_issue_delivery_loop_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_issue_delivery_loop_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is limited to issue orchestration" in text
    assert "Main-agent must not implement issue tasks directly." in text
    assert "implementation must be produced by a subagent PR" in text


def test_issue_delivery_loop_skill_requires_close_for_done() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Definition of done: execution is complete only when `close-plan` succeeds and the target issue is actually closed." in text
    assert "A successful run must terminate at `close-plan` with issue state `CLOSED`." in text
    assert "If close gates fail, treat the run as unfinished" in text


def test_issue_delivery_loop_skill_uses_binary_first_command_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "plan-issue" in text
    assert "plan-issue-local" in text
    assert "status-plan" in text
    assert "ready-plan" in text
    assert "close-plan" in text


def test_issue_delivery_loop_skill_excludes_deleted_wrapper_script() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert ("manage_issue_delivery_loop" + ".sh") not in text
