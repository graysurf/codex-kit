from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "close-github-pr.sh"
REPO_ROOT = Path(__file__).resolve().parents[6]
STUB_BIN = REPO_ROOT / "tests" / "stubs" / "bin"


def test_workflows_pr_github_close_github_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_github_close_github_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/close-github-pr.sh"])


def _run(args: list[str], *, cwd: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    proc_env = os.environ.copy()
    proc_env.update(env)
    return subprocess.run(
        args,
        cwd=str(cwd),
        env=proc_env,
        text=True,
        capture_output=True,
        check=False,
    )


def _git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=str(repo), text=True, capture_output=True, check=False)


def _assert_ok(proc: subprocess.CompletedProcess[str]) -> None:
    assert proc.returncode == 0, proc.stderr


def _init_repo(repo: Path) -> None:
    _assert_ok(_git(repo, "init", "-q"))
    _assert_ok(_git(repo, "checkout", "-q", "-B", "main"))
    _assert_ok(_git(repo, "config", "user.email", "test@example.com"))
    _assert_ok(_git(repo, "config", "user.name", "Test User"))
    (repo / "README.md").write_text("seed\n", encoding="utf-8")
    _assert_ok(_git(repo, "add", "README.md"))
    _assert_ok(_git(repo, "commit", "-q", "-m", "chore: seed repository"))


def _setup_repo(
    tmp_path: Path,
    *,
    checks_mode: str,
    extra_env: dict[str, str] | None = None,
) -> tuple[Path, dict[str, str], Path]:
    repo = tmp_path / "repo"
    repo.mkdir()
    _init_repo(repo)
    log_dir = tmp_path / "gh-log"
    env = {
        "PATH": os.pathsep.join([str(STUB_BIN), os.environ.get("PATH", "")]),
        "CODEX_GH_STUB_MODE_ENABLED": "true",
        "CODEX_STUB_LOG_DIR": str(log_dir),
        "CODEX_GH_STUB_PR_NUMBER": "123",
        "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/123",
        "CODEX_GH_STUB_BASE_REF": "main",
        "CODEX_GH_STUB_HEAD_REF": "feat/no-checks",
        "CODEX_GH_STUB_STATE": "OPEN",
        "CODEX_GH_STUB_PR_CHECKS_MODE": checks_mode,
    }
    if extra_env:
        env.update(extra_env)
    return repo, env, log_dir


def _run_close(repo: Path, env: dict[str, str], *extra_args: str) -> subprocess.CompletedProcess[str]:
    return _run(
        [
            str(SCRIPT),
            "--kind",
            "feature",
            "--pr",
            "123",
            "--keep-branch",
            "--no-cleanup",
            *extra_args,
        ],
        cwd=repo,
        env=env,
    )


def _custom_checks(required: list[dict[str, str]], all_checks: list[dict[str, str]]) -> dict[str, str]:
    return {
        "CODEX_GH_STUB_PR_REQUIRED_CHECKS_JSON": json.dumps(required),
        "CODEX_GH_STUB_PR_CHECKS_JSON": json.dumps(all_checks),
    }


def test_close_blocks_missing_checks_by_default(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(tmp_path, checks_mode="none")

    proc = _run_close(repo, env)

    assert proc.returncode == 1
    assert "CHECK_STATUS=missing" in proc.stdout
    assert "use --allow-no-checks" in proc.stderr
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr merge 123" not in calls


def test_close_accepts_missing_checks_when_explicitly_allowed(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(tmp_path, checks_mode="none")

    proc = _run_close(repo, env, "--allow-no-checks")

    assert proc.returncode == 0, proc.stderr
    assert "CHECK_STATUS=missing" in proc.stdout
    assert "accepted by --allow-no-checks" in proc.stdout
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr checks 123 --json name,state,bucket" in calls
    assert "gh pr merge 123" in calls


def test_close_blocks_failed_checks_even_when_no_checks_are_allowed(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(tmp_path, checks_mode="failed")

    proc = _run_close(repo, env, "--allow-no-checks")

    assert proc.returncode == 1
    assert "CHECK_STATUS=failed" in proc.stdout
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr merge 123" not in calls


def test_close_allows_optional_skipped_when_required_checks_pass(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(
        tmp_path,
        checks_mode="custom",
        extra_env=_custom_checks(
            required=[{"name": "test", "state": "SUCCESS", "bucket": "pass"}],
            all_checks=[
                {"name": "test", "state": "SUCCESS", "bucket": "pass"},
                {"name": "coverage_badge", "state": "SKIPPED", "bucket": "skipping"},
            ],
        ),
    )

    proc = _run_close(repo, env)

    assert proc.returncode == 0, proc.stderr
    assert "CHECK_STATUS=passed" in proc.stdout
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr checks 123 --required --json name,state,bucket" in calls
    assert "gh pr merge 123" in calls


def test_close_falls_back_to_all_checks_when_no_required_checks_reported(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(
        tmp_path,
        checks_mode="custom",
        extra_env={
            "CODEX_GH_STUB_PR_REQUIRED_CHECKS_MISSING": "1",
            "CODEX_GH_STUB_PR_CHECKS_JSON": json.dumps(
                [{"name": "ci", "state": "SUCCESS", "bucket": "pass"}]
            ),
        },
    )

    proc = _run_close(repo, env)

    assert proc.returncode == 0, proc.stderr
    assert "CHECK_STATUS=passed" in proc.stdout
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr checks 123 --required --json name,state,bucket" in calls
    assert "gh pr checks 123 --json name,state,bucket" in calls
    assert "gh pr merge 123" in calls


def test_close_blocks_pending_required_checks_even_with_optional_skipped(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(
        tmp_path,
        checks_mode="custom",
        extra_env=_custom_checks(
            required=[{"name": "test", "state": "PENDING", "bucket": "pending"}],
            all_checks=[
                {"name": "test", "state": "PENDING", "bucket": "pending"},
                {"name": "coverage_badge", "state": "SKIPPED", "bucket": "skipping"},
            ],
        ),
    )

    proc = _run_close(repo, env)

    assert proc.returncode == 1
    assert "CHECK_STATUS=pending" in proc.stdout
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr merge 123" not in calls


def test_close_blocks_skipped_required_checks(tmp_path: Path) -> None:
    repo, env, log_dir = _setup_repo(
        tmp_path,
        checks_mode="custom",
        extra_env=_custom_checks(
            required=[{"name": "test", "state": "SKIPPED", "bucket": "skipping"}],
            all_checks=[{"name": "test", "state": "SKIPPED", "bucket": "skipping"}],
        ),
    )

    proc = _run_close(repo, env)

    assert proc.returncode == 1
    assert "CHECK_STATUS=failed" in proc.stdout
    calls = (log_dir / "gh.calls.txt").read_text(encoding="utf-8")
    assert "gh pr merge 123" not in calls
