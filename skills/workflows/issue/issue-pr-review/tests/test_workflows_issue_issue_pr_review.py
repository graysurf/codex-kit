from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_issue_issue_pr_review_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_issue_issue_pr_review_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/manage_issue_pr_review.sh",
        ],
    )


def test_issue_pr_review_skill_requires_comment_link_traceability() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "comment URL" in text
    assert "issue" in text.lower()


def test_issue_pr_review_script_has_internal_pr_body_validator() -> None:
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "manage_issue_pr_review.sh"
    text = script_path.read_text(encoding="utf-8")
    assert "validate_pr_body_hygiene_text" in text
    assert "validate_pr_body_hygiene_input" in text
    assert "ensure_pr_body_hygiene_for_close" in text


def test_issue_pr_review_script_has_no_subagent_wrapper_dependency() -> None:
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "manage_issue_pr_review.sh"
    text = script_path.read_text(encoding="utf-8")
    assert ("manage_issue_subagent_pr" + ".sh") not in text
