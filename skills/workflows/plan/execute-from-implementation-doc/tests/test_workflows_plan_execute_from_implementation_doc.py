from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_plan_execute_from_implementation_doc_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_execute_from_implementation_doc_accepts_expected_sources() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "discussion-to-implementation-doc" in text
    assert "review-to-improvement-doc" in text
    assert "create-plan" in text
    assert "create-dispatch-plan" in text
    assert "durable-artifact-cleanup" in text
    assert "review-evidence.json" in text


def test_execute_from_implementation_doc_defines_state_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Execution State Template" in text
    assert "Current State" in text
    assert "Task Ledger" in text
    assert "Session Log" in text
    assert "append-only" in text
    assert "source document and execution state" in text


def test_execute_from_implementation_doc_requires_safe_resume_gates() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Verify execution readiness" in text
    assert "failing-test evidence or record an explicit waiver" in text
    assert "Do not spawn subagents unless the user explicitly requested" in text
    assert "Work tree contains unrelated dirty changes" in text
