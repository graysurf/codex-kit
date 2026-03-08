from __future__ import annotations

from pathlib import Path


def _test_file_path(test_file: str | Path) -> Path:
    return Path(test_file).resolve()


def skill_root(test_file: str | Path) -> Path:
    return _test_file_path(test_file).parents[1]


def skill_md_text(test_file: str | Path) -> str:
    return (skill_root(test_file) / "SKILL.md").read_text(encoding="utf-8")


def _plan_shared_root(test_file: str | Path) -> Path:
    return _test_file_path(test_file).parents[2] / "_shared"


def shared_plan_baseline_text(test_file: str | Path) -> str:
    return (_plan_shared_root(test_file) / "references" / "PLAN_AUTHORING_BASELINE.md").read_text(encoding="utf-8")


def shared_plan_template_text(test_file: str | Path) -> str:
    return (_plan_shared_root(test_file) / "assets" / "plan-template.md").read_text(encoding="utf-8")
