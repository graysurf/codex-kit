from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_heuristic_system_documents_error_inbox_and_operation_records() -> None:
    text = (ROOT / "HEURISTIC_SYSTEM.md").read_text(encoding="utf-8")

    assert "Important unresolved workflow gap" in text
    assert "docs/runbooks/heuristic-system/error-inbox/" in text
    assert "docs/runbooks/heuristic-system/operation-records/" in text
    assert "raw runtime records in their evidence location" in text


def test_heuristic_system_error_inbox_readme_defines_curated_queue_contract() -> None:
    text = (ROOT / "docs/runbooks/heuristic-system/error-inbox/README.md").read_text(encoding="utf-8")

    assert "versioned summaries of important workflow gaps" in text
    assert "This is not a raw log archive" in text
    assert "- `open`: gap is known and not yet triaged." in text
    assert "## Entry Template" in text
    assert "## Cleanup Rules" in text


def test_skill_usage_runbook_routes_unresolved_gaps_to_error_inbox() -> None:
    text = (ROOT / "docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md").read_text(encoding="utf-8")

    assert "If a failure remains unresolved" in text
    assert "docs/runbooks/heuristic-system/error-inbox/" in text
    assert "Do not commit the raw `skill-usage.record.json` as the tracker." in text
