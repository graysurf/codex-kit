from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import default_env, repo_root


def run(cmd: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        env=default_env(cwd),
        text=True,
        capture_output=True,
        timeout=10,
    )


def test_validate_skill_contracts_passes_for_repo():
    repo = repo_root()
    result = run(["bash", str(repo / "scripts" / "validate_skill_contracts.sh")], cwd=repo)
    assert result.returncode == 0, result.stderr
    assert result.stdout == ""
    assert result.stderr == ""


def test_validate_skill_contracts_fails_for_invalid_contract(tmp_path: Path):
    fixture = tmp_path / "bad-skill.md"
    fixture.write_text(
        "\n".join(
            [
                "# Fixture Skill",
                "",
                "## Contract",
                "",
                "Prereqs:",
                "- N/A",
                "",
                "Inputs:",
                "- N/A",
                "",
                "Outputs:",
                "- N/A",
                "",
                "Exit codes:",
                "- N/A",
                "",
                "# Missing Failure modes:",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    repo = repo_root()
    result = run(
        ["bash", str(repo / "scripts" / "validate_skill_contracts.sh"), "--file", str(fixture)],
        cwd=repo,
    )
    assert result.returncode != 0
    assert "Failure modes" in result.stderr


def test_validate_progress_index_passes_for_repo():
    repo = repo_root()
    script = repo / "skills" / "workflows" / "pr" / "progress" / "create-progress-pr" / "scripts" / "validate_progress_index.sh"
    result = run(["bash", str(script)], cwd=repo)
    assert result.returncode == 0, result.stderr
    assert result.stdout == ""
    assert result.stderr == ""


def test_validate_progress_index_fails_for_invalid_pr_cell(tmp_path: Path):
    repo = repo_root()
    original = repo / "docs" / "progress" / "README.md"
    mutated = tmp_path / "progress-readme.md"
    mutated.write_text(original.read_text("utf-8"), "utf-8")

    lines = mutated.read_text("utf-8").splitlines()
    out: list[str] = []
    in_progress_table = False
    seen_sep = False
    mutated_row = False

    for line in lines:
        if line.strip() == "## In progress":
            in_progress_table = True
            out.append(line)
            continue
        if in_progress_table and line.startswith("| ---"):
            seen_sep = True
            out.append(line)
            continue
        if in_progress_table and seen_sep and not mutated_row and line.startswith("|"):
            parts = [p.strip() for p in line.strip().strip("|").split("|")]
            if len(parts) == 3:
                parts[2] = "NOT_A_LINK"
                out.append(f"| {parts[0]} | {parts[1]} | {parts[2]} |")
                mutated_row = True
                continue
        if line.strip() == "## Archived":
            in_progress_table = False
        out.append(line)

    mutated.write_text("\n".join(out).rstrip() + "\n", "utf-8")

    script = repo / "skills" / "workflows" / "pr" / "progress" / "create-progress-pr" / "scripts" / "validate_progress_index.sh"
    result = run(["bash", str(script), "--file", str(mutated)], cwd=repo)
    assert result.returncode != 0
    assert "invalid PR cell" in result.stderr
