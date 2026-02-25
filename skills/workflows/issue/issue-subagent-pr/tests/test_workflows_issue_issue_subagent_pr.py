from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_issue_issue_subagent_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_issue_subagent_pr_skill_mentions_worktree_isolation() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "worktree" in text.lower()
    assert "Subagent" in text
    assert "Task Decomposition" in text


def test_issue_subagent_pr_skill_requires_native_git_gh_commands() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "git worktree" in text
    assert "gh pr create" in text
    assert "gh pr comment" in text


def test_issue_subagent_pr_skill_excludes_deleted_wrapper_script() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert ("manage_issue_subagent_pr" + ".sh") not in text


def test_issue_subagent_prompt_template_excludes_legacy_single_pr_mode() -> None:
    prompt_template = (
        Path(__file__).resolve().parents[1] / "references" / "SUBAGENT_TASK_PROMPT_TEMPLATE.md"
    ).read_text(encoding="utf-8")

    assert "pr-shared" in prompt_template
    assert "pr-isolated" in prompt_template
    assert "single-pr" not in prompt_template
