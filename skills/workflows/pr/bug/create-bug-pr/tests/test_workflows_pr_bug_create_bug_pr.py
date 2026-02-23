from __future__ import annotations

import os
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_pr_bug_create_bug_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_bug_create_bug_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/render_bug_pr.sh",
        ],
    )


def _run_render(
    *args: str,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    script = Path(__file__).resolve().parents[1] / "scripts" / "render_bug_pr.sh"
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(
        [str(script), *args],
        text=True,
        capture_output=True,
        check=False,
        cwd=None if cwd is None else str(cwd),
        env=run_env,
    )


def _skill_md_text() -> str:
    return (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")


def test_render_bug_pr_outputs_bug_template_sections() -> None:
    result = _run_render("--pr")
    assert result.returncode == 0, result.stderr
    assert "## Summary" in result.stdout
    assert "## Problem" in result.stdout
    assert "## Reproduction" in result.stdout
    assert "## Issues Found" in result.stdout
    assert "## Fix Approach" in result.stdout
    assert "## Changes" not in result.stdout


def test_render_bug_pr_output_template_has_issues_response_structure() -> None:
    result = _run_render("--output")
    assert result.returncode == 0, result.stderr
    assert "Issues List" in result.stdout
    assert "Git Scope" in result.stdout
    assert "Tests Run" in result.stdout
    assert "PR Link" in result.stdout


def test_render_bug_pr_rejects_unknown_flags() -> None:
    result = _run_render("--pr", "--unexpected-flag")
    assert result.returncode == 1
    assert "Unknown option: --unexpected-flag" in result.stderr


def test_create_bug_pr_skill_avoids_commit_subject_narrative() -> None:
    text = _skill_md_text()
    assert "do not derive PR title/body from `git log -1 --pretty=%B`." in text
    assert "commits like `Add plan file` are not valid PR title/body sources." in text


def test_create_bug_pr_skill_opens_draft_pr_by_default() -> None:
    text = _skill_md_text()
    assert "`gh pr create --draft ...`" in text
    assert "Open draft PRs by default; only open non-draft when the user explicitly requests it." in text


def test_create_bug_pr_skill_uses_shared_bug_references() -> None:
    text = _skill_md_text()
    assert "$AGENT_HOME/skills/automation/find-and-fix-bugs/references/PR_TEMPLATE.md" in text
    assert "$AGENT_HOME/skills/automation/find-and-fix-bugs/references/ASSISTANT_RESPONSE_TEMPLATE.md" in text
    assert "Use `$AGENT_HOME/skills/workflows/pr/bug/create-bug-pr/scripts/render_bug_pr.sh --pr`" in text
