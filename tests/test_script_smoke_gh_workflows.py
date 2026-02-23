from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


def git(cmd: list[str], *, cwd: Path) -> None:
    subprocess.run(["git", *cmd], cwd=str(cwd), check=True, text=True, capture_output=True)


def gh_stub_log_dir(tmp_path: Path, name: str) -> Path:
    return tmp_path / "stub-logs" / "gh" / name


def init_fixture_repo(tmp_path: Path, *, default_branch: str = "main") -> tuple[Path, Path]:
    work_tree = tmp_path / "repo"
    origin = tmp_path / "origin.git"
    work_tree.mkdir(parents=True, exist_ok=True)
    origin.mkdir(parents=True, exist_ok=True)

    git(["init"], cwd=work_tree)
    git(["config", "user.email", "fixture@example.com"], cwd=work_tree)
    git(["config", "user.name", "Fixture User"], cwd=work_tree)

    git(["checkout", "-b", default_branch], cwd=work_tree)

    (work_tree / "README.md").write_text("fixture\n", "utf-8")
    git(["add", "README.md"], cwd=work_tree)
    git(["commit", "-m", "init"], cwd=work_tree)

    git(["init", "--bare"], cwd=origin)
    git(["remote", "add", "origin", str(origin)], cwd=work_tree)
    git(["push", "-u", "origin", default_branch], cwd=work_tree)

    return (work_tree, origin)


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_feature_pr(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-feature-pr")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Summary",
            "Fixture.",
            "",
            "## Changes",
            "- Fixture",
            "",
            "## Testing",
            "- not run (fixture)",
            "",
            "## Risk / Notes",
            "- None",
            "",
        ]
    )
    spec = {
        "args": ["--pr", "123", "--skip-checks", "--no-cleanup"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "123",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/123",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-merge-no-cleanup", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls_path = log_dir / "gh.calls.txt"
    calls = calls_path.read_text("utf-8")
    assert "gh pr merge 123" in calls
    assert "gh pr edit 123 --body-file" not in calls


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_feature_pr_auto_ready_draft_before_merge(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-feature-pr-auto-ready-draft")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Summary",
            "Fixture.",
            "",
            "## Changes",
            "- Fixture",
            "",
            "## Testing",
            "- not run (fixture)",
            "",
            "## Risk / Notes",
            "- None",
            "",
        ]
    )
    spec = {
        "args": ["--pr", "127", "--skip-checks", "--no-cleanup"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "127",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/127",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_IS_DRAFT": "true",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-auto-ready-draft", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls = (log_dir / "gh.calls.txt").read_text("utf-8").splitlines()
    ready_idx = next(i for i, line in enumerate(calls) if line.startswith("gh pr ready 127"))
    merge_idx = next(i for i, line in enumerate(calls) if line.startswith("gh pr merge 127"))
    assert ready_idx < merge_idx
    assert any("gh pr view 127 --json url,baseRefName,headRefName,state,isDraft" in line for line in calls)


def _prepare_locked_main_worktree_fixture(tmp_path: Path) -> tuple[Path, Path]:
    work_tree, origin = init_fixture_repo(tmp_path)

    git(["checkout", "-b", "feat/fixture"], cwd=work_tree)
    (work_tree / "feature.txt").write_text("fixture feature branch\n", "utf-8")
    git(["add", "feature.txt"], cwd=work_tree)
    git(["commit", "-m", "feat fixture"], cwd=work_tree)
    git(["push", "-u", "origin", "feat/fixture"], cwd=work_tree)

    main_worktree = tmp_path / "main-worktree"
    git(["worktree", "add", str(main_worktree), "main"], cwd=work_tree)

    git(["merge", "--no-ff", "feat/fixture", "-m", "merge fixture"], cwd=main_worktree)
    git(["push", "origin", "main"], cwd=main_worktree)

    # Return the primary worktree still on feat/fixture; main is now locked in another worktree.
    git(["checkout", "feat/fixture"], cwd=work_tree)
    return (work_tree, origin)


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_feature_pr_worktree_safe_cleanup_when_base_branch_locked(tmp_path: Path):
    work_tree, _ = _prepare_locked_main_worktree_fixture(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-feature-pr-worktree-safe-cleanup")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Summary",
            "Fixture.",
            "",
            "## Changes",
            "- Fixture",
            "",
            "## Testing",
            "- not run (fixture)",
            "",
            "## Risk / Notes",
            "- None",
            "",
        ]
    )
    spec = {
        "args": ["--pr", "128", "--skip-checks"],
        "timeout_sec": 20,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "128",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/128",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-worktree-safe-cleanup", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls = (log_dir / "gh.calls.txt").read_text("utf-8").splitlines()
    merge_call = next(line for line in calls if line.startswith("gh pr merge 128"))
    assert "--delete-branch" not in merge_call

    stderr_text = Path(result.stderr_path).read_text("utf-8")
    assert "detached origin/main" in stderr_text

    head_ref_exists = subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", "refs/heads/feat/fixture"],
        cwd=str(work_tree),
        text=True,
        capture_output=True,
    )
    assert head_ref_exists.returncode != 0

    remote_head = subprocess.run(
        ["git", "ls-remote", "--heads", "origin", "feat/fixture"],
        cwd=str(work_tree),
        text=True,
        capture_output=True,
        check=True,
    )
    assert remote_head.stdout.strip() == ""


@pytest.mark.script_smoke
def test_script_smoke_fixture_deliver_feature_pr_close_worktree_safe_cleanup_when_base_branch_locked(tmp_path: Path):
    work_tree, _ = _prepare_locked_main_worktree_fixture(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "deliver-feature-pr-close-worktree-safe-cleanup")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Summary",
            "Fixture.",
            "",
            "## Changes",
            "- Fixture",
            "",
            "## Testing",
            "- not run (fixture)",
            "",
            "## Risk / Notes",
            "- None",
            "",
        ]
    )
    spec = {
        "args": ["close", "--pr", "129", "--skip-checks"],
        "timeout_sec": 20,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "129",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/129",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-close-worktree-safe-cleanup", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    stderr_text = Path(result.stderr_path).read_text("utf-8")
    assert "detached origin/main" in stderr_text


@pytest.mark.script_smoke
def test_script_smoke_fixture_deliver_feature_pr_close_treats_merged_helper_failure_as_success(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/deliver-feature-pr/scripts/deliver-feature-pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "deliver-feature-pr-close-merged-helper-failure")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Summary",
            "Fixture.",
            "",
            "## Changes",
            "- Fixture",
            "",
            "## Testing",
            "- not run (fixture)",
            "",
            "## Risk / Notes",
            "- None",
            "",
        ]
    )
    spec = {
        "args": ["close", "--pr", "130", "--skip-checks"],
        "timeout_sec": 20,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "130",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/130",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
            "CODEX_GH_STUB_PR_MERGE_EXIT_CODE": "1",
            "CODEX_GH_STUB_PR_MERGE_SET_STATE": "MERGED",
            "CODEX_GH_STUB_FAIL_FIRST_POST_MERGE_PR_VIEW": "true",
            "CODEX_GH_STUB_FAIL_POST_MERGE_PR_VIEW_EXIT_CODE": "1",
        },
    }

    result = run_smoke_script(script, "fixture-close-merged-helper-failure", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls = (log_dir / "gh.calls.txt").read_text("utf-8").splitlines()
    assert any(line.startswith("gh pr merge 130") for line in calls)
    post_merge_state_queries = [
        line for line in calls if "gh pr view 130 --json url,baseRefName,headRefName,state,isDraft" in line
    ]
    assert len(post_merge_state_queries) >= 2

    stderr_text = Path(result.stderr_path).read_text("utf-8")
    assert "simulated 'pr merge' non-zero exit 1 for PR 130" in stderr_text
    assert "PR #130 is already MERGED; treating close as success" in stderr_text
