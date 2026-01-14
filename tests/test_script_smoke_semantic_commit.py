from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


@pytest.mark.script_smoke
def test_script_smoke_fixture_semantic_commit_commit_with_message(tmp_path: Path):
    work_tree = tmp_path / "repo"
    work_tree.mkdir(parents=True, exist_ok=True)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(work_tree), check=True, text=True, capture_output=True)

    run(["git", "init"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])

    tracked = work_tree / "hello.txt"
    tracked.write_text("one\n", "utf-8")
    run(["git", "add", "hello.txt"])
    run(["git", "commit", "-m", "init"])

    tracked.write_text("two\n", "utf-8")
    run(["git", "add", "hello.txt"])

    repo = repo_root()
    script = "skills/tools/devex/semantic-commit/scripts/commit_with_message.sh"
    spec = {
        "args": ["--message", "test(fixture): commit staged change"],
        "timeout_sec": 20,
        "expect": {
            "exit_codes": [0],
            "stdout_regex": r"test\(fixture\): commit staged change",
        },
    }

    result = run_smoke_script(script, "commit-with-message", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )
