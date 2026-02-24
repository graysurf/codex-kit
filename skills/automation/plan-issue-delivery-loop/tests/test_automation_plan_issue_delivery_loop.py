from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_automation_plan_issue_delivery_loop_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_plan_issue_delivery_loop_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/plan-issue-delivery-loop.sh"])


def test_plan_issue_delivery_loop_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is orchestration/review-only." in text
    assert "Main-agent does not implement sprint tasks directly." in text
    assert "subagent-owned PRs" in text
    assert "1 plan = 1 issue" in text
    assert "PR grouping controls" in text
    assert "## Full Skill Flow" in text


def test_plan_issue_delivery_loop_script_supports_sprint_progression_flow() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")
    assert "start-plan" in text
    assert "close-plan" in text
    assert "build-plan-task-spec" in text
    assert "start-sprint" in text
    assert "accept-sprint" in text
    assert "next-sprint" in text
    assert "multi-sprint-guide" in text
    assert "close-after-review" in text
    assert "issue_lifecycle_script" in text
    assert "render_plan_issue_body_from_task_spec" in text
    assert '"to-json"' in text
    assert "validate_pr_grouping_args" in text
    assert "--pr-grouping <mode>" in text
    assert "--pr-group <task=group>" in text
    assert "PR_GROUP=" in text
    assert "OPEN_PR_CMD=SHARED_WITH_GROUP" in text
