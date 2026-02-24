from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_issue_issue_subagent_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_issue_issue_subagent_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/manage_issue_subagent_pr.sh",
        ],
    )


def test_issue_subagent_pr_skill_mentions_worktree_isolation() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "worktree" in text.lower()
    assert "Subagents" in text
    assert "Task Decomposition.PR" in text


def test_issue_subagent_pr_script_syncs_issue_pr_fields_on_open() -> None:
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "manage_issue_subagent_pr.sh"
    text = script_path.read_text(encoding="utf-8")
    assert "sync_issue_task_pr_by_branch" in text
    assert "refresh_sprint_start_comments_pr_values" in text
    assert "UPDATED_TASK_IDS=" in text
