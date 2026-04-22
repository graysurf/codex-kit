from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract
from skills._shared.python.skill_testing.assertions import repo_root


def test_tools_google_workspace_google_sheets_cell_edit_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_google_workspace_google_sheets_cell_edit_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/google-sheets-cell-edit.sh"])


def test_tools_google_workspace_google_sheets_cell_edit_readme_catalog_entry_present() -> None:
    readme = repo_root() / "README.md"
    text = readme.read_text(encoding="utf-8")

    assert "[google-sheets-cell-edit](./skills/tools/google-workspace/google-sheets-cell-edit/)" in text
    assert "| Google Workspace |" in text


def test_tools_google_workspace_google_sheets_cell_edit_skill_covers_self_improvement() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")

    assert "Skill Improvement Suggestions" in text
    assert "Do not use `HYPERLINK()` when one cell needs multiple clickable links." in text
