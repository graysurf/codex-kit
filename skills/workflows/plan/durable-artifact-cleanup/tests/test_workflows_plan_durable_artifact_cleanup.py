from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_plan_durable_artifact_cleanup_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_durable_artifact_cleanup_is_audit_first_and_delete_scoped() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "audit and policy workflow for cleanup" in text
    assert "Run an audit/dry-run classification before deletion" in text
    assert "delete`, `keep`, `archive-or-rehome`, and `manual-review`" in text
    assert "Delete only artifacts classified as `delete`" in text
    assert "Treat deletion as the preferred end state" in text
    assert "Classify source docs, plans, and execution-state docs as one execution" in text
    assert "Use this workflow for named artifacts or unclear cleanup status" in text


def test_durable_artifact_cleanup_preserves_evidence_and_references() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Scan references" in text
    assert "retained evidence" in text
    assert "diagnostic logs" in text
    assert "heuristic-system/error-inbox/" in text
    assert "heuristic-system/operation-records/" in text
    assert "dangling links" in text
    assert "Status: complete" in text


def test_durable_artifact_cleanup_links_nearby_lifecycle_skills() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "`discussion-to-implementation-doc`" in text
    assert "`review-to-improvement-doc`" in text
    assert "`execute-from-plan`" in text
    assert "`docs-plan-cleanup`" in text
    assert "deterministic batch executor for broad `docs/plans/`" in text
    assert "after this workflow when cleanup scope needs policy classification first" in text
