from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_automation_issue_delivery_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_issue_delivery_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is limited to issue orchestration" in text
    assert "Main-agent must not implement issue tasks directly." in text
    assert "implementation must be produced by a subagent PR" in text


def test_issue_delivery_skill_requires_close_for_done() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Definition of done: execution is complete only when `close-plan` succeeds and the target issue is actually closed." in text
    assert "A successful run must terminate at `close-plan` with issue state `CLOSED`." in text
    assert "If close gates fail, treat the run as unfinished" in text


def test_issue_delivery_skill_uses_binary_first_command_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "plan-issue" in text
    assert "plan-issue-local" in text
    assert "link-pr" in text
    assert "status-plan" in text
    assert "ready-plan" in text
    assert "close-plan" in text


def test_issue_delivery_skill_uses_shared_task_lane_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in text


def test_issue_delivery_skill_uses_shared_review_rubric() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md" in text
    assert "apply the shared main-agent review rubric" in text


def test_issue_delivery_skill_uses_shared_post_review_outcomes() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md" in text
    assert "After each review decision" in text
    assert "--row-status" in text
    assert "--next-owner" in text
    assert "--close-reason" in text


def test_issue_delivery_skill_excludes_deleted_wrapper_script() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert ("manage_issue_delivery_loop" + ".sh") not in text
