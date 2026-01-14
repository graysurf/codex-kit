from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


@pytest.mark.script_smoke
def test_script_smoke_create_progress_file_updates_index(tmp_path: Path):
    work_tree = tmp_path / "repo"
    work_tree.mkdir(parents=True, exist_ok=True)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(work_tree), check=True, text=True, capture_output=True)

    run(["git", "init"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])

    (work_tree / "README.md").write_text("fixture\n", "utf-8")
    run(["git", "add", "README.md"])
    run(["git", "commit", "-m", "init"])

    progress_index = work_tree / "docs" / "progress" / "README.md"
    progress_index.parent.mkdir(parents=True, exist_ok=True)
    progress_index.write_text(
        "# Progress\n\n## In progress\n\n| Date | Feature | PR |\n| --- | --- | --- |\n",
        "utf-8",
    )

    repo = repo_root()
    script = "skills/workflows/pr/progress/create-progress-pr/scripts/create_progress_file.sh"
    spec = {
        "args": [
            "--title",
            "Smoke test progress",
            "--feature",
            "Fixture",
            "--slug",
            "smoke-progress",
            "--date",
            "20260101",
            "--status",
            "IN PROGRESS",
        ],
        "timeout_sec": 20,
        "expect": {"exit_codes": [0], "stdout_regex": r"^docs/progress/20260101_smoke-progress\.md$"},
    }

    result = run_smoke_script(script, "create-progress-file", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )

    output_path = work_tree / "docs" / "progress" / "20260101_smoke-progress.md"
    assert output_path.exists(), f"missing progress file: {output_path}"

    output_text = output_path.read_text("utf-8")
    assert "# Fixture: Smoke test progress\n" in output_text
    assert "| IN PROGRESS |" in output_text

    assert (work_tree / "docs" / "templates" / "PROGRESS_TEMPLATE.md").exists()
    assert (work_tree / "docs" / "templates" / "PROGRESS_GLOSSARY.md").exists()

    index_text = progress_index.read_text("utf-8")
    assert "| 2026-01-01 | [Smoke test progress](20260101_smoke-progress.md) | TBD |" in index_text
