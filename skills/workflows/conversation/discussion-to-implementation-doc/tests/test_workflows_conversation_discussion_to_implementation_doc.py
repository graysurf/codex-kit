from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_conversation_discussion_to_implementation_doc_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_discussion_to_implementation_doc_defines_artifact_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "implementation-readiness source document" in text
    assert "not execute the implementation now" in text
    assert "Do not turn the document into a task-by-task implementation plan" in text
    assert "Do not use the document as a session prompt" in text


def test_discussion_to_implementation_doc_routes_to_nearby_skills() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "Relationship To Nearby Skills" in text
    assert "`review-evidence`" in text
    assert "`review-to-improvement-doc`" in text
    assert "`create-plan`" in text
    assert "`execute-from-plan`" in text
    assert "`handoff-session-prompt`" in text
    assert "review findings and validation records" in text


def test_discussion_to_implementation_doc_can_prepare_execution_state() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "An `Execution` section" in text
    assert "execution-state path" in text
    assert "next-task source" in text


def test_discussion_to_implementation_doc_can_be_plan_source() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "primary source artifact for later plan" in text
    assert "requirements, design, feasibility" in text
    assert "docs/plans/<slug>/<slug>-discussion-source.md" in text
    assert "Promote or rewrite into domain docs/runbooks" in text
    assert "cleanup after execution or promotion candidate" in text
    assert "plan's `Read First` section as the primary source" in text
    assert "`create-dispatch-plan`" in text


def test_discussion_to_implementation_doc_documents_skill_usage_recording_pilot() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "first docs-only pilot for `skill-usage.record.v1`" in text
    assert "agent-out project --topic skill-usage --mkdir" in text
    assert "skill-usage verify --out <record-dir> --format json" in text
