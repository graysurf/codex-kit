from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_plan_execute_from_plan_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_execute_from_plan_accepts_expected_sources() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "discussion-to-implementation-doc" in text
    assert "review-to-improvement-doc" in text
    assert "create-plan" in text
    assert "create-dispatch-plan" in text
    assert "durable-artifact-cleanup" in text
    assert "review-evidence.json" in text
    assert "prefer a plan as the" in text
    assert "execution-control source" in text
    assert "Direct source-doc execution is allowed only" in text
    assert "direct-execution waiver" in text


def test_execute_from_plan_defines_state_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Execution State Template" in text
    assert "Current State" in text
    assert "Task Ledger" in text
    assert "Session Log" in text
    assert "append-only" in text
    assert "source document and execution state" in text


def test_execute_from_plan_requires_safe_resume_gates() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    normalized = " ".join(text.split())

    assert "Verify execution readiness" in text
    assert "failing-test evidence or record an explicit waiver" in text
    assert "Do not spawn subagents unless the user explicitly requested" in text
    assert "Work tree contains unrelated dirty changes" in text
    assert "bounded single-step change" in normalized


def test_execute_from_plan_routes_plan_created_sources_to_sibling_plan() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Plan-created source docs under `docs/plans/<slug>/`" in text
    assert "If a sibling `<slug>-plan.md` exists" in text
    assert "execute from that plan" in text
    assert "look for a sibling `<slug>-plan.md`" in text
    assert "use `create-plan` or" in text
    assert "`create-dispatch-plan` instead of starting edits" in text
