from __future__ import annotations

from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def test_plan_workflow_readme_defines_source_plan_state_roles() -> None:
    text = (_repo_root() / "skills" / "workflows" / "plan" / "README.md").read_text(encoding="utf-8")
    normalized = " ".join(text.split())

    assert "## Artifact Roles" in text
    assert "Source doc: durable facts" in text
    assert "Plan: execution-control artifact" in text
    assert "Execution state: resume ledger" in text
    assert "A source doc should explain why and what" in normalized
    assert "a plan should sequence how" in normalized


def test_plan_workflow_readme_defines_cleanup_selection_boundary() -> None:
    text = (_repo_root() / "skills" / "workflows" / "plan" / "README.md").read_text(encoding="utf-8")

    assert "## Cleanup Selection" in text
    assert "Use `durable-artifact-cleanup` for named source docs" in text
    assert "Use `docs-plan-cleanup` for broad `docs/plans/` hygiene" in text
    assert "It is the batch executor, not the policy audit" in text
    assert "run `durable-artifact-cleanup` first to classify the scope" in text


def test_plan_workflow_readme_prefers_plan_for_multistep_execution() -> None:
    text = (_repo_root() / "skills" / "workflows" / "plan" / "README.md").read_text(encoding="utf-8")

    assert "default bridge from source docs to implementation" in text
    assert "execute-from-plan" in text
    assert "resume implementation from a plan by default" in text
    assert "direct source-doc execution is only for bounded" in text
