from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_automation_release_workflow_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_release_workflow_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/release-publish-from-changelog.sh",
            "scripts/release-resolve.sh",
        ],
    )


def test_automation_release_workflow_declares_retained_entrypoints() -> None:
    text = (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")
    assert "## Entrypoints (fallback helper scripts)" in text
    assert "$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh" in text
    assert "$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh" in text
    assert "--push-current-branch" in text
    assert "legacy wrapper paths are not supported" in text.lower()
