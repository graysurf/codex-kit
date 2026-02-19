from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_plan_docs_plan_cleanup_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_plan_docs_plan_cleanup_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/docs-plan-cleanup.sh"])


def _skill_md_text() -> str:
    return (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")


def _response_template_text() -> str:
    return (Path(__file__).resolve().parents[1] / "references" / "ASSISTANT_RESPONSE_TEMPLATE.md").read_text(
        encoding="utf-8"
    )


def test_docs_plan_cleanup_skill_declares_response_template_usage() -> None:
    text = _skill_md_text()
    assert "## Output and clarification rules" in text
    assert "references/ASSISTANT_RESPONSE_TEMPLATE.md" in text
    assert "status: applied" in text


def test_docs_plan_cleanup_response_template_includes_required_summary_fields() -> None:
    text = _response_template_text()
    required_fields = (
        "| metric | value |",
        "| total_plan_md |",
        "| plan_md_to_keep |",
        "| plan_md_to_clean |",
        "| plan_related_md_to_clean |",
        "| plan_related_md_kept_referenced_elsewhere |",
        "| plan_related_md_to_rehome |",
        "| plan_related_md_manual_review |",
        "| non_docs_md_referencing_removed_plan |",
    )
    for field in required_fields:
        assert field in text


def test_docs_plan_cleanup_response_template_includes_all_item_sections() -> None:
    text = _response_template_text()
    required_sections = (
        "## plan_md_to_keep",
        "## plan_md_to_clean",
        "## plan_related_md_to_clean",
        "## plan_related_md_kept_referenced_elsewhere",
        "## plan_related_md_to_rehome",
        "## plan_related_md_manual_review",
        "## non_docs_md_referencing_removed_plan",
    )
    for section in required_sections:
        assert section in text

    # Itemized sections must be represented as markdown tables.
    assert "| path |" in text
    assert "| path | referenced_by |" in text
    assert "| none | - |" in text


def test_docs_plan_cleanup_skill_requires_markdown_table_output() -> None:
    text = _skill_md_text()
    assert "rendered as a Markdown table" in text
    assert "rendered as Markdown tables" in text
    assert "render a `none` row in that table" in text
