from __future__ import annotations

import os
import stat
import subprocess
import tempfile
from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract, resolve_codex_command


def test_tools_devex_semantic_commit_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_devex_semantic_commit_binary_available() -> None:
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


def test_tools_devex_semantic_commit_staged_context_outputs_bundle_and_ignores_git_commit_context_json() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        with tempfile.TemporaryDirectory() as tools_dir:
            tools = Path(tools_dir)
            _write_executable(
                tools,
                "git-commit-context-json",
                "#!/usr/bin/env bash\nset -euo pipefail\necho 'SHOULD_NOT_RUN' >&2\nexit 1\n",
            )
            path_env = os.pathsep.join([str(tools), os.environ.get("PATH", "")])

            proc = _run(
                [str(semantic_commit), "staged-context"],
                cwd=repo,
                env={"PATH": path_env},
            )

        assert proc.returncode == 0, proc.stderr
        assert "SHOULD_NOT_RUN" not in proc.stderr
        assert "git-commit-context-json" not in proc.stderr
        assert "warning:" not in proc.stderr
        assert "===== commit-context.json =====" in proc.stdout
        assert '"schemaVersion":1' in proc.stdout
        assert "===== staged.patch =====" in proc.stdout
        assert "diff --git a/a.txt b/a.txt" in proc.stdout


def test_tools_devex_semantic_commit_staged_context_supports_repo_and_json_output() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        repo = root / "repo"
        repo.mkdir()
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        proc = _run(
            [str(semantic_commit), "staged-context", "--repo", str(repo), "--format", "json"],
            cwd=root,
            env=None,
        )

        assert proc.returncode == 0, proc.stderr
        assert '"schemaVersion":1' in proc.stdout
        assert '"path":"a.txt"' in proc.stdout
        assert proc.stderr == ""


def test_tools_devex_semantic_commit_commit_creates_commit_with_git_scope_summary() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

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
                input_text="feat(core): add thing\n\n- Add thing\n",
            )

        assert proc.returncode == 0, proc.stderr
        assert "warning:" not in proc.stderr
        assert "error:" not in proc.stderr
        assert "GIT_SCOPE_OK" in proc.stdout
        assert _has_head(repo)


def test_tools_devex_semantic_commit_commit_falls_back_to_git_show_when_git_scope_missing() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        proc = _run(
            [str(semantic_commit), "commit", "--message", "feat(core): add thing\n\n- Add thing"],
            cwd=repo,
            env={"PATH": "/usr/bin:/bin:/usr/sbin:/sbin"},
        )

        assert proc.returncode == 0, proc.stderr
        assert "git-scope not found" in proc.stderr
        assert "falling back to git show" in proc.stderr
        assert "feat(core): add thing" in proc.stdout
        assert _has_head(repo)


def test_tools_devex_semantic_commit_validate_only_checks_message_without_creating_commit() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        proc = _run(
            [
                str(semantic_commit),
                "commit",
                "--validate-only",
                "--message",
                "feat(core): add thing\n\n- Add thing",
            ],
            cwd=repo,
            env=None,
        )

        assert proc.returncode == 0, proc.stderr
        assert not _has_head(repo)


def test_tools_devex_semantic_commit_dry_run_checks_staged_changes_without_creating_commit() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        proc = _run(
            [
                str(semantic_commit),
                "commit",
                "--dry-run",
                "--message",
                "feat(core): add thing\n\n- Add thing",
            ],
            cwd=repo,
            env=None,
        )

        assert proc.returncode == 0, proc.stderr
        assert not _has_head(repo)


def test_tools_devex_semantic_commit_automation_mode_requires_explicit_message() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        proc = _run(
            [str(semantic_commit), "commit", "--automation"],
            cwd=repo,
            env=None,
            input_text="chore: ignored over stdin\n",
        )

        assert proc.returncode == 3
        assert "automation mode" in proc.stderr
        assert not _has_head(repo)


def test_tools_devex_semantic_commit_validation_error_returns_exit_4() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        (repo / "a.txt").write_text("hello\n", encoding="utf-8")
        _run(["git", "add", "a.txt"], cwd=repo, env=None)

        proc = _run(
            [str(semantic_commit), "commit", "--message", "Feat(core): invalid uppercase type"],
            cwd=repo,
            env=None,
        )

        assert proc.returncode == 4
        assert "invalid header format" in proc.stderr
        assert not _has_head(repo)


def test_tools_devex_semantic_commit_message_out_writes_recovery_file() -> None:
    semantic_commit = resolve_codex_command("semantic-commit")

    with tempfile.TemporaryDirectory() as temp_dir:
        repo = Path(temp_dir)
        _init_repo(repo)
        recovery = repo / "message.txt"

        proc = _run(
            [
                str(semantic_commit),
                "commit",
                "--validate-only",
                "--message",
                "chore: test recovery",
                "--message-out",
                str(recovery),
            ],
            cwd=repo,
            env=None,
        )

        assert proc.returncode == 0, proc.stderr
        assert recovery.is_file()
        assert recovery.read_text(encoding="utf-8").rstrip("\n") == "chore: test recovery"
