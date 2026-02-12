from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_pr_progress_handoff_progress_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_progress_handoff_progress_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/handoff_progress_pr.sh",
        ],
    )


def _skill_md_text() -> str:
    return (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")


def test_handoff_progress_pr_skill_documents_progress_derived_create_feature_pr_flags() -> None:
    text = _skill_md_text()
    assert "--from-progress-pr --planning-pr <number> --progress-url <full-github-url>" in text
    assert "valid pair" in text
