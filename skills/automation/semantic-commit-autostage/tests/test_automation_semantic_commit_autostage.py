from __future__ import annotations

import os
import stat
import subprocess
import tempfile
from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract, resolve_codex_command


def test_automation_semantic_commit_autostage_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_semantic_commit_autostage_binary_available() -> None:
    resolve_codex_command("semantic-commit")


def _run(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    proc_env = os.environ.copy()
    if env:
        proc_env.update(env)
    return subprocess.run(
        args,
        cwd=str(cwd),
        env=proc_env,
        text=True,
        input=input_text,
        capture_output=True,
    )


def _init_repo(dir_path: Path) -> None:
    for cmd in [
        ["git", "init", "-q"],
        ["git", "checkout", "-q", "-B", "main"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test User"],
        ["git", "config", "commit.gpgsign", "false"],
        ["git", "config", "tag.gpgSign", "false"],
    ]:
        proc = _run(cmd, cwd=dir_path, env=None)
        assert proc.returncode == 0, proc.stderr


def _write_executable(dir_path: Path, name: str, contents: str) -> None:
    path = dir_path / name
    path.write_text(contents, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _has_head(repo: Path) -> bool:
    head = _run(["git", "rev-parse", "--verify", "HEAD"], cwd=repo, env=None)
    return head.returncode == 0


def test_automation_semantic_commit_autostage_flow_works_with_semantic_commit_binary() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")

        proc = _run(["git", "add", "-A"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr

        with tempfile.TemporaryDirectory() as tools_dir:
            tools = Path(tools_dir)
            _write_executable(
                tools,
                "git-scope",
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "if [[ \"${1-}\" == \"help\" ]]; then\n"
                "  exit 0\n"
                "fi\n"
                "if [[ \"${1-}\" != \"commit\" || \"${2-}\" != \"HEAD\" || \"${3-}\" != \"--no-color\" ]]; then\n"
                "  echo \"unexpected args: $*\" >&2\n"
                "  exit 2\n"
                "fi\n"
                "echo \"GIT_SCOPE_OK\"\n",
            )
            path_env = f"{tools}:/usr/bin:/bin:/usr/sbin:/sbin"

            proc = _run(
                [str(semantic_commit), "commit"],
                cwd=repo,
                env={"PATH": path_env},
                input_text="chore: test\n",
            )

        assert proc.returncode == 0, proc.stderr
        assert "warning:" not in proc.stderr
        assert "error:" not in proc.stderr
        assert "GIT_SCOPE_OK" in proc.stdout
        assert _has_head(repo)


def test_automation_semantic_commit_autostage_falls_back_when_git_scope_missing() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")

        proc = _run(["git", "add", "-A"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr

        proc = _run(
            [str(semantic_commit), "commit", "--message", "chore: test fallback"],
            cwd=repo,
            env={"PATH": "/usr/bin:/bin:/usr/sbin:/sbin"},
        )

        assert proc.returncode == 0, proc.stderr
        assert "git-scope not found" in proc.stderr
        assert "falling back to git show" in proc.stderr
        assert "chore: test fallback" in proc.stdout
        assert _has_head(repo)


def test_automation_semantic_commit_autostage_tracked_only_keeps_untracked_files_out_of_commit() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        tracked = repo / "tracked.txt"
        tracked.write_text("v1\n", encoding="utf-8")

        proc = _run(["git", "add", "tracked.txt"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr
        proc = _run(["git", "commit", "-m", "seed"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr

        tracked.write_text("v2\n", encoding="utf-8")
        (repo / "untracked.txt").write_text("new\n", encoding="utf-8")

        proc = _run(["git", "add", "-u"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr

        proc = _run(
            [str(semantic_commit), "commit", "--summary", "none", "--message", "chore: tracked only"],
            cwd=repo,
            env=None,
        )

        assert proc.returncode == 0, proc.stderr
        show_names = _run(["git", "show", "--name-only", "--pretty=format:"], cwd=repo, env=None)
        assert show_names.returncode == 0, show_names.stderr
        assert "tracked.txt" in show_names.stdout
        assert "untracked.txt" not in show_names.stdout


def test_automation_semantic_commit_autostage_validate_and_dry_run_do_not_create_commit() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")

        proc = _run(["git", "add", "-A"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr

        validate_proc = _run(
            [str(semantic_commit), "commit", "--validate-only", "--message", "chore: validate"],
            cwd=repo,
            env=None,
        )
        assert validate_proc.returncode == 0, validate_proc.stderr
        assert not _has_head(repo)

        dry_run_proc = _run(
            [str(semantic_commit), "commit", "--dry-run", "--message", "chore: validate"],
            cwd=repo,
            env=None,
        )
        assert dry_run_proc.returncode == 0, dry_run_proc.stderr
        assert not _has_head(repo)


def test_automation_semantic_commit_autostage_automation_mode_requires_explicit_message() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")

        proc = _run(["git", "add", "-A"], cwd=repo, env=None)
        assert proc.returncode == 0, proc.stderr

        proc = _run(
            [str(semantic_commit), "commit", "--automation"],
            cwd=repo,
            env=None,
            input_text="chore: ignored\n",
        )

        assert proc.returncode == 3
        assert "automation mode" in proc.stderr
        assert not _has_head(repo)
