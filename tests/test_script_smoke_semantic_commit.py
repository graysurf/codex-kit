from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


def init_fixture_repo(work_tree: Path) -> None:
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


@pytest.mark.script_smoke
def test_script_smoke_fixture_semantic_commit_commit_with_message(tmp_path: Path):
    work_tree = tmp_path / "repo"
    init_fixture_repo(work_tree)

    repo = repo_root()
    script = "semantic-commit"
    spec = {
        "command": [
            "semantic-commit",
            "commit",
            "--message",
            "test(fixture): commit staged change",
        ],
        "timeout_sec": 20,
        "env": {"CODEX_HOME": None},
        "expect": {
            "exit_codes": [0],
            "stdout_regex": r"(?s)test\(fixture\): commit staged change.*Directory tree",
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


@pytest.mark.script_smoke
@pytest.mark.parametrize(
    ("case", "message", "stderr_substring"),
    [
        ("bad-header", "Fix: Add thing", "invalid header format"),
        ("missing-blank-line", "feat(core): add thing\n- Add thing", "separated from header by a blank line"),
        ("non-bullet-body", "feat(core): add thing\n\nAdd thing", "must start with '- ' followed by uppercase letter"),
        ("lowercase-body", "feat(core): add thing\n\n- add thing", "must start with '- ' followed by uppercase letter"),
        (
            "overlong-body-line",
            "feat(core): add thing\n\n- " + ("A" * 101),
            "exceeds 100 characters",
        ),
    ],
)
def test_script_smoke_semantic_commit_invalid_messages(
    tmp_path: Path, case: str, message: str, stderr_substring: str
) -> None:
    work_tree = tmp_path / case
    init_fixture_repo(work_tree)

    message_path = work_tree / "message.txt"
    message_path.write_text(message, "utf-8")

    repo = repo_root()
    script = "semantic-commit"
    spec = {
        "command": ["semantic-commit", "commit", "--message-file", str(message_path)],
        "timeout_sec": 20,
        "env": {"CODEX_HOME": None},
        "expect": {"exit_codes": [1]},
    }

    result = run_smoke_script(script, f"commit-with-message-{case}", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    stderr = Path(result.stderr_path).read_text("utf-8")
    assert result.exit_code != 0, f"expected non-zero exit for {case}, got {result.exit_code}"
    assert stderr_substring in stderr, (
        f"expected stderr to contain {stderr_substring!r} for {case}\n"
        f"stderr: {result.stderr_path}"
    )
