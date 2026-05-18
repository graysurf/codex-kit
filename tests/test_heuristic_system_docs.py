from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_heuristic_system_documents_error_inbox_and_operation_records() -> None:
    text = (ROOT / "HEURISTIC_SYSTEM.md").read_text(encoding="utf-8")

    assert "Important unresolved workflow gap" in text
    assert "heuristic-system/error-inbox/" in text
    assert "heuristic-system/error-inbox/archive/YYYY/" in text
    assert "heuristic-system/operation-records/" in text
    assert "heuristic-error-inbox" in text
    assert "raw runtime records in their evidence location" in text
    assert "Operation records are not required for every promoted inbox entry." in text


def test_heuristic_system_error_inbox_readme_defines_curated_queue_contract() -> None:
    text = (ROOT / "heuristic-system/error-inbox/README.md").read_text(encoding="utf-8")

    assert "versioned summaries of important workflow gaps" in text
    assert "This is not a raw log archive" in text
    assert "- `open`: gap is known and not yet triaged." in text
    assert "Do not add `archived` as a lifecycle status." in text
    assert "status is `promoted` or `wontfix`" in text
    assert "`Next Action` starts with `None.`" in text
    assert "Top-level `*.md` files are the active inbox." in text
    assert "## Entry Template" in text
    assert "## Archive" in text
    assert "## Cleanup Rules" in text
    assert "heuristic-error-inbox" in text


def test_skill_usage_runbook_routes_unresolved_gaps_to_error_inbox() -> None:
    text = (ROOT / "docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md").read_text(encoding="utf-8")

    assert "If a failure remains unresolved" in text
    assert "heuristic-system/error-inbox/" in text
    assert "heuristic-error-inbox" in text
    assert "Do not commit the raw `skill-usage.record.json` as the tracker." in text
    assert "Do not run multiple `skill-usage` write commands against the same `--out`" in text


def test_heuristic_system_workflow_docs_keep_archive_and_compression_narrow() -> None:
    text = (ROOT / "skills/workflows/heuristic-system/heuristic-error-inbox/SKILL.md").read_text(encoding="utf-8")
    index_text = (ROOT / "skills/workflows/heuristic-system/README.md").read_text(encoding="utf-8")

    assert "heuristic-error-inbox.sh archive <entry.md>" in text
    assert "Closed entries keep status `promoted` or `wontfix`" in text
    assert "`archived` lifecycle status" in text
    assert "several related" in text
    assert "archived inbox or operation records" in text
    assert "Archive completed inbox entries so the active backlog stays small." in index_text
    assert "Create an operation record only for repeated, cross-skill, audit-worthy" in index_text
