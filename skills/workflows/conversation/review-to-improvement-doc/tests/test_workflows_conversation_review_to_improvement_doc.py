from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_workflows_conversation_review_to_improvement_doc_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_review_to_improvement_doc_defines_artifact_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "repo-local improvement source document" in text
    assert "Do not turn it into a phased implementation plan" in text
    assert "Do not turn it into a handoff prompt" in text
    assert "docs/plans/<slug>/<slug>-review-source.md" in text


def test_review_to_improvement_doc_requires_findings_and_discoverability() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "findings table with priority, issue, evidence, fix location, and acceptance" in text
    assert "runtime vs test/harness vs docs" in text
    assert "Update the nearest docs index or README only when this document is promoted" in text
    assert "`Read First`" in text


def test_review_to_improvement_doc_routes_discussion_handoffs_elsewhere() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "`discussion-to-implementation-doc`" in text
    assert "discussion handoff for later implementation" in text
    assert "primary reader is the next" in text


def test_review_to_improvement_doc_can_prepare_execution_ready_records() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "`execute-from-implementation-doc`" in text
    assert "executable backlog" in text
    assert "execution-state path" in text
    assert "later implementation" in text


def test_review_to_improvement_doc_can_be_plan_source() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")

    assert "primary source artifact for later plan" in text
    assert "review findings, risks, lessons" in text
    assert "docs/runbooks/heuristic-system/error-inbox/<slug>.md" in text
    assert "Promote or rewrite into domain docs/runbooks" in text
    assert "cleanup after execution or promotion candidate" in text
    assert "plan's `Read First` section as the primary source" in text
    assert "`create-plan-rigorous`" in text
