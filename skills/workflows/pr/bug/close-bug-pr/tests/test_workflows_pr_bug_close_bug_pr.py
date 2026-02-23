from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_pr_bug_close_bug_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_bug_close_bug_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/close_bug_pr.sh",
        ],
    )


def _skill_md_text() -> str:
    return (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")


def test_close_bug_pr_skill_documents_auto_ready_for_draft_prs() -> None:
    text = _skill_md_text()
    assert "if `true`, run `gh pr ready <pr>` automatically, then continue to merge." in text
    assert "PR is draft and automatic `gh pr ready` fails." in text
