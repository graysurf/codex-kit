from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "deliver-github-pr.sh"
REPO_ROOT = Path(__file__).resolve().parents[6]
STUB_BIN = REPO_ROOT / "tests" / "stubs" / "bin"


def test_workflows_pr_github_deliver_github_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_github_deliver_github_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/deliver-github-pr.sh"])


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
    checks_mode: str = "pass",
    extra_env: dict[str, str] | None = None,
) -> tuple[Path, dict[str, str]]:
    repo = tmp_path / "repo"
    repo.mkdir()
    _init_repo(repo)
    env = {
        "PATH": os.pathsep.join([str(STUB_BIN), os.environ.get("PATH", "")]),
        "CODEX_GH_STUB_MODE_ENABLED": "true",
        "CODEX_GH_STUB_PR_NUMBER": "123",
        "CODEX_GH_STUB_PR_CHECKS_MODE": checks_mode,
    }
    if extra_env:
        env.update(extra_env)
    return repo, env


def _run_skill(repo: Path, env: dict[str, str], *args: str) -> subprocess.CompletedProcess[str]:
    return _run([str(SCRIPT), *args], cwd=repo, env=env)


def _custom_checks(required: list[dict[str, str]], all_checks: list[dict[str, str]]) -> dict[str, str]:
    return {
        "CODEX_GH_STUB_PR_REQUIRED_CHECKS_JSON": json.dumps(required),
        "CODEX_GH_STUB_PR_CHECKS_JSON": json.dumps(all_checks),
    }


def test_help_surface() -> None:
    proc = subprocess.run([str(SCRIPT), "--help"], text=True, capture_output=True, check=False)

    assert proc.returncode == 0
    assert "deliver-github-pr.sh --kind <feature|bug> <command>" in proc.stdout


def test_preflight_outputs_github_kind_mapping(tmp_path: Path) -> None:
    repo, env = _setup_repo(tmp_path)

    proc = _run_skill(repo, env, "--kind", "feature", "preflight", "--base", "main")

    assert proc.returncode == 0, proc.stderr
    assert "KIND=feature" in proc.stdout
    assert "BRANCH_PREFIX=feat" in proc.stdout
    assert "CREATE_SKILL=create-github-pr" in proc.stdout
    assert "CLOSE_SKILL=close-github-pr" in proc.stdout


def test_wait_checks_blocks_missing_checks_by_default(tmp_path: Path) -> None:
    repo, env = _setup_repo(tmp_path, checks_mode="none")

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-checks",
        "--pr",
        "123",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 1
    assert "CHECK_STATUS=missing" in proc.stdout
    assert "use --allow-no-checks" in proc.stderr


def test_wait_checks_accepts_missing_checks_when_explicitly_allowed(tmp_path: Path) -> None:
    repo, env = _setup_repo(tmp_path, checks_mode="none")

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-checks",
        "--pr",
        "123",
        "--allow-no-checks",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 0, proc.stderr
    assert "CHECK_STATUS=missing" in proc.stdout
    assert "accepted by --allow-no-checks" in proc.stdout


def test_wait_checks_blocks_failed_checks_even_when_no_checks_are_allowed(tmp_path: Path) -> None:
    repo, env = _setup_repo(tmp_path, checks_mode="failed")

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "bug",
        "wait-checks",
        "--pr",
        "123",
        "--allow-no-checks",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 1
    assert "CHECK_STATUS=failed" in proc.stdout


def test_wait_checks_allows_optional_skipped_when_required_checks_pass(tmp_path: Path) -> None:
    repo, env = _setup_repo(
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

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-checks",
        "--pr",
        "123",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 0, proc.stderr
    assert "CHECK_STATUS=passed" in proc.stdout


def test_wait_checks_keeps_waiting_when_required_checks_are_pending(tmp_path: Path) -> None:
    repo, env = _setup_repo(
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

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-checks",
        "--pr",
        "123",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 124
    assert "CHECK_STATUS=pending" in proc.stdout
