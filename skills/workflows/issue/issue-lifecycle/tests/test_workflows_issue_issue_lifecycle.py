from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_issue_issue_lifecycle_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_issue_issue_lifecycle_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/manage_issue_lifecycle.sh",
        ],
    )


def test_issue_lifecycle_skill_mentions_main_agent_ownership() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "Main agent" in text
    assert "decompose" in text


def test_issue_lifecycle_skill_mentions_subagent_owner_policy() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "Owner policy enforcement for implementation tasks" in text
    assert "`Owner` is for subagents only" in text


def test_issue_lifecycle_skill_uses_shared_task_lane_policy() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "_shared/references/TASK_LANE_CONTINUITY.md" in text


def test_issue_lifecycle_execution_modes_are_explicit_and_non_legacy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    script_text = (skill_root / "scripts" / "manage_issue_lifecycle.sh").read_text(encoding="utf-8")
    template_text = (skill_root / "references" / "ISSUE_TEMPLATE.md").read_text(encoding="utf-8")
    skill_text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "pr-isolated" in script_text
    assert "pr-shared" in script_text
    assert "single-pr" not in script_text
    assert "single-pr" not in template_text
    assert "single-pr" not in skill_text
