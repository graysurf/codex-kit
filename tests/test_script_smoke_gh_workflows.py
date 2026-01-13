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
    spec = {
        "args": ["--pr", "123", "--skip-checks", "--no-cleanup"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE": "1",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "123",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/123",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
        },
    }

    result = run_smoke_script(script, "fixture-merge-no-cleanup", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls_path = log_dir / "gh.calls.txt"
    calls = calls_path.read_text("utf-8")
    assert "gh pr merge 123" in calls


@pytest.mark.script_smoke
def test_script_smoke_fixture_handoff_progress_pr_patch_only(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "handoff-progress-pr")
    progress_file = "docs/progress/20260113_fixture.md"

    spec = {
        "args": ["--pr", "21", "--progress-file", progress_file, "--patch-only"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE": "1",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "21",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/21",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "docs/progress/fixture",
            "CODEX_GH_STUB_STATE": "MERGED",
            "CODEX_GH_STUB_BODY": "# Fixture PR\n\n## Summary\nFixture.\n",
        },
    }

    result = run_smoke_script(script, "fixture-patch-only", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    patched_body = (log_dir / "gh.pr.21.body.md").read_text("utf-8")
    assert f"- [{progress_file}](https://github.com/example/repo/blob/main/{progress_file})" in patched_body


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_progress_pr_no_merge(tmp_path: Path):
    work_tree, origin = init_fixture_repo(tmp_path)

    head_branch = "feat/progress-123"
    git(["checkout", "-b", head_branch], cwd=work_tree)

    progress_file = work_tree / "docs" / "progress" / "20260113_fixture_progress.md"
    progress_file.parent.mkdir(parents=True, exist_ok=True)
    progress_file.write_text(
        "\n".join(
            [
                "# codex-kit: Fixture progress",
                "",
                "| Status | Created | Updated |",
                "| --- | --- | --- |",
                "| IN PROGRESS | 2026-01-13 | 2026-01-13 |",
                "",
                "Links:",
                "",
                "- PR: TBD",
                "- Docs: None",
                "- Glossary: TBD",
                "",
                "## Goal",
                "",
                "- Fixture",
                "",
                "## Acceptance Criteria",
                "",
                "- Fixture",
                "",
                "## Steps (Checklist)",
                "",
                "- [x] Step 0: Alignment",
                "  - Work Items:",
                "    - [x] Fixture",
                "  - Exit Criteria:",
                "    - [x] Fixture",
                "- [x] Step 1: MVP",
                "  - Work Items:",
                "    - [x] Fixture",
                "  - Exit Criteria:",
                "    - [x] Fixture",
                "- [x] Step 2: Expansion",
                "  - Work Items:",
                "    - [x] Fixture",
                "  - Exit Criteria:",
                "    - [x] Fixture",
                "- [x] Step 3: Validation",
                "  - Work Items:",
                "    - [x] Fixture",
                "  - Exit Criteria:",
                "    - [x] Fixture",
                "- [ ] Step 4: Release / wrap-up",
                "  - Work Items:",
                "    - [ ] Fixture",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    git(["add", "docs/progress/20260113_fixture_progress.md"], cwd=work_tree)
    git(["commit", "-m", "docs(progress): add fixture progress"], cwd=work_tree)
    git(["push", "-u", "origin", head_branch], cwd=work_tree)

    repo = repo_root()
    script = "skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-progress-pr")
    spec = {
        "args": [
            "--pr",
            "123",
            "--progress-file",
            "docs/progress/20260113_fixture_progress.md",
            "--no-merge",
        ],
        "timeout_sec": 30,
        "env": {
            "CODEX_GH_STUB_MODE": "1",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "123",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/123",
            "CODEX_GH_STUB_TITLE": "Fixture progress close",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": head_branch,
            "CODEX_GH_STUB_STATE": "OPEN",
        },
    }

    result = run_smoke_script(script, "fixture-no-merge", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    archived = work_tree / "docs" / "progress" / "archived" / "20260113_fixture_progress.md"
    assert archived.exists()
    archived_text = archived.read_text("utf-8")
    assert "| DONE | 2026-01-13 |" in archived_text
    assert "- PR: https://github.com/example/repo/pull/123" in archived_text

    subprocess.run(["git", "remote", "get-url", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)
    subprocess.run(["git", "ls-remote", "--heads", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)
