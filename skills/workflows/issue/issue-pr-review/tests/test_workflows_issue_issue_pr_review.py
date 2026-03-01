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


def test_issue_pr_review_skill_uses_shared_task_lane_policy() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "_shared/references/TASK_LANE_CONTINUITY.md" in text


def test_issue_pr_review_skill_uses_shared_review_rubric() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md" in text
    assert "task-fidelity" in text
    assert "correctness" in text
    assert "integration" in text


def test_issue_pr_review_skill_uses_shared_post_review_outcomes() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    assert "_shared/references/POST_REVIEW_OUTCOMES.md" in text
    assert "row sync to" in text
    assert "retires the lane" in text
    assert "CLOSE_PR_ISSUE_SYNC_TEMPLATE.md" in text
    assert "--row-status" in text
    assert "--next-owner" in text
    assert "--close-reason" in text


def test_issue_pr_review_script_has_internal_pr_body_validator() -> None:
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "manage_issue_pr_review.sh"
    text = script_path.read_text(encoding="utf-8")
    assert "validate_pr_body_hygiene_text" in text
    assert "validate_pr_body_hygiene_input" in text
    assert "ensure_pr_body_hygiene_for_close" in text


def test_issue_pr_review_script_supports_structured_issue_sync_fields() -> None:
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "manage_issue_pr_review.sh"
    text = script_path.read_text(encoding="utf-8")
    assert "--issue-note-file" in text
    assert "--issue-comment-file" in text
    assert "--close-reason" in text
    assert "--next-action" in text
    assert "build_followup_issue_note" in text
    assert "build_close_issue_comment" in text


def test_issue_pr_review_script_has_no_subagent_wrapper_dependency() -> None:
    script_path = Path(__file__).resolve().parents[1] / "scripts" / "manage_issue_pr_review.sh"
    text = script_path.read_text(encoding="utf-8")
    assert ("manage_issue_subagent_pr" + ".sh") not in text


def test_issue_pr_review_templates_include_row_state_guidance() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    issue_sync = (skill_root / "references" / "ISSUE_SYNC_TEMPLATE.md").read_text(encoding="utf-8")
    close_sync = (skill_root / "references" / "CLOSE_PR_ISSUE_SYNC_TEMPLATE.md").read_text(encoding="utf-8")
    assert "Main-agent requested updates in PR" not in issue_sync
    assert "Row status" in issue_sync
    assert "Lane action" in issue_sync
    assert "Lane state: retired" in close_sync
    assert "do not resume the closed lane" in close_sync
