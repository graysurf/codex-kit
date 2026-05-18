from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_plan_durable_artifact_cleanup_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_durable_artifact_cleanup_is_audit_first_and_delete_scoped() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Run an audit/dry-run classification before deletion" in text
    assert "delete`, `keep`, `archive-or-rehome`, and `manual-review`" in text
    assert "Delete only artifacts classified as `delete`" in text
    assert "Treat deletion as the preferred end state" in text


def test_durable_artifact_cleanup_preserves_evidence_and_references() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Scan references" in text
    assert "retained evidence" in text
    assert "diagnostic logs" in text
    assert "docs/runbooks/heuristic-system/error-inbox/" in text
    assert "docs/runbooks/heuristic-system/operation-records/" in text
    assert "dangling links" in text
    assert "Status: complete" in text


def test_durable_artifact_cleanup_links_nearby_lifecycle_skills() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "`discussion-to-implementation-doc`" in text
    assert "`review-to-improvement-doc`" in text
    assert "`execute-from-implementation-doc`" in text
    assert "`docs-plan-cleanup`" in text
