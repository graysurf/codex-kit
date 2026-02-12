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
            "## Progress",
            "- None",
            "",
            "## Planning PR",
            "- None",
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

    patched_body = (log_dir / "gh.pr.123.body.md").read_text("utf-8")
    assert "## Progress" not in patched_body
    assert "## Planning PR" not in patched_body


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_feature_pr_strips_progress_only(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-feature-pr-strip-progress-only")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Progress",
            "- None",
            "",
            "## Planning PR",
            "- #42",
            "",
            "## Summary",
            "Fixture.",
            "",
        ]
    )
    spec = {
        "args": ["--pr", "124", "--skip-checks", "--no-cleanup"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "124",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/124",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-strip-progress-only", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    patched_body = (log_dir / "gh.pr.124.body.md").read_text("utf-8")
    assert "## Progress" not in patched_body
    assert "## Planning PR" not in patched_body


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_feature_pr_strips_planning_only(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-feature-pr-strip-planning-only")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Progress",
            "- https://example.com/progress",
            "",
            "## Planning PR",
            "- None",
            "",
            "## Summary",
            "Fixture.",
            "",
        ]
    )
    spec = {
        "args": ["--pr", "125", "--skip-checks", "--no-cleanup"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "125",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/125",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-strip-planning-only", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    patched_body = (log_dir / "gh.pr.125.body.md").read_text("utf-8")
    assert "## Planning PR" not in patched_body
    assert "## Progress" not in patched_body


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_feature_pr_keeps_valid_progress_pair(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/feature/close-feature-pr/scripts/close_feature_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-feature-pr-keep-valid-pair")
    pr_body = "\n".join(
        [
            "# Fixture PR",
            "",
            "## Progress",
            "- [docs/progress/20260213_fixture.md](https://github.com/example/repo/blob/feat/fixture/docs/progress/20260213_fixture.md)",
            "",
            "## Planning PR",
            "- #42",
            "",
            "## Summary",
            "Fixture.",
            "",
            "## Changes",
            "- Fixture",
            "",
        ]
    )
    spec = {
        "args": ["--pr", "126", "--skip-checks", "--no-cleanup"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "126",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/126",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "feat/fixture",
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-keep-valid-progress-pair", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls_path = log_dir / "gh.calls.txt"
    calls = calls_path.read_text("utf-8")
    assert "gh pr merge 126" in calls
    assert "gh pr edit 126 --body-file" not in calls


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
            "CODEX_GH_STUB_MODE_ENABLED": "true",
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
    stderr_text = Path(result.stderr_path).read_text("utf-8")
    assert "feature-pr-render-args: --from-progress-pr --planning-pr 21 --progress-url" in stderr_text


@pytest.mark.script_smoke
def test_script_smoke_fixture_handoff_progress_pr_patch_only_reuses_pr_body(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "handoff-progress-pr-body-cache")
    progress_file = "docs/progress/20260113_fixture.md"
    pr_body = f"# Fixture PR\n\n## Progress\n- [{progress_file}]({progress_file})\n"

    spec = {
        "args": ["--pr", "22", "--patch-only"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "22",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/22",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "docs/progress/fixture",
            "CODEX_GH_STUB_STATE": "MERGED",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-patch-only-body-cache", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls_path = log_dir / "gh.calls.txt"
    calls = calls_path.read_text("utf-8")
    assert calls.count("gh pr view 22 --json body") == 1

    patched_body = (log_dir / "gh.pr.22.body.md").read_text("utf-8")
    assert f"- [{progress_file}](https://github.com/example/repo/blob/main/{progress_file})" in patched_body


@pytest.mark.script_smoke
def test_script_smoke_fixture_handoff_progress_pr_rejects_non_progress_file(tmp_path: Path):
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    script = "skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "handoff-progress-pr-invalid-progress-file")

    spec = {
        "args": ["--pr", "23", "--progress-file", "docs/notes.md", "--patch-only"],
        "timeout_sec": 15,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "23",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/23",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": "docs/progress/fixture",
            "CODEX_GH_STUB_STATE": "MERGED",
            "CODEX_GH_STUB_BODY": "# Fixture PR\n\n## Summary\nFixture.\n",
        },
    }

    result = run_smoke_script(script, "fixture-invalid-progress-file", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "fail", result
    assert result.exit_code == 1
    stderr_text = Path(result.stderr_path).read_text("utf-8")
    assert "docs/progress/*.md path" in stderr_text


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
            "CODEX_GH_STUB_MODE_ENABLED": "true",
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


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_progress_pr_merge_reuses_pr_body(tmp_path: Path):
    work_tree, origin = init_fixture_repo(tmp_path)

    head_branch = "feat/progress-126"
    git(["checkout", "-b", head_branch], cwd=work_tree)

    progress_rel = "docs/progress/20260113_fixture_progress.md"
    progress_file = work_tree / progress_rel
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

    git(["add", progress_rel], cwd=work_tree)
    git(["commit", "-m", "docs(progress): add fixture progress"], cwd=work_tree)
    git(["push", "-u", "origin", head_branch], cwd=work_tree)

    repo = repo_root()
    script = "skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh"
    log_dir = gh_stub_log_dir(tmp_path, "close-progress-pr-body-cache")
    pr_body = f"# Fixture PR\n\n## Progress\n- [{progress_rel}]({progress_rel})\n"

    spec = {
        "args": [
            "--pr",
            "126",
        ],
        "timeout_sec": 30,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "126",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/126",
            "CODEX_GH_STUB_TITLE": "Fixture progress close",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": head_branch,
            "CODEX_GH_STUB_STATE": "OPEN",
            "CODEX_GH_STUB_BODY": pr_body,
        },
    }

    result = run_smoke_script(script, "fixture-merge-body-cache", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    calls_path = log_dir / "gh.calls.txt"
    calls = calls_path.read_text("utf-8")
    assert calls.count("gh pr view 126 --json body") == 1

    patched_body = (log_dir / "gh.pr.126.body.md").read_text("utf-8")
    assert (
        "- [docs/progress/archived/20260113_fixture_progress.md](https://github.com/example/repo/blob/main/docs/progress/archived/20260113_fixture_progress.md)"
        in patched_body
    )

    subprocess.run(["git", "remote", "get-url", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)
    subprocess.run(["git", "ls-remote", "--heads", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_progress_pr_auto_strikethrough(tmp_path: Path):
    work_tree, origin = init_fixture_repo(tmp_path)

    head_branch = "feat/progress-124"
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
                "    - [ ] (Optional) Add a one-time backfill script to import `apps/client/src/components/news/brand-news.json` into `articles`.",
                "      - Reason: Optional follow-up; not required for backend module availability.",
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
    log_dir = gh_stub_log_dir(tmp_path, "close-progress-pr-auto-strikethrough")
    spec = {
        "args": [
            "--pr",
            "124",
            "--progress-file",
            "docs/progress/20260113_fixture_progress.md",
            "--no-merge",
        ],
        "timeout_sec": 30,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "124",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/124",
            "CODEX_GH_STUB_TITLE": "Fixture progress close",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": head_branch,
            "CODEX_GH_STUB_STATE": "OPEN",
        },
    }

    result = run_smoke_script(script, "fixture-auto-strikethrough", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    archived = work_tree / "docs" / "progress" / "archived" / "20260113_fixture_progress.md"
    assert archived.exists()
    archived_text = archived.read_text("utf-8")
    assert (
        "- [ ] ~~(Optional) Add a one-time backfill script to import `apps/client/src/components/news/brand-news.json` into `articles`.~~"
        in archived_text
    )
    assert "Reason: Optional follow-up; not required for backend module availability." in archived_text

    subprocess.run(["git", "remote", "get-url", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)
    subprocess.run(["git", "ls-remote", "--heads", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)


@pytest.mark.script_smoke
def test_script_smoke_fixture_close_progress_pr_invalid_strikethrough_fails(tmp_path: Path):
    work_tree, origin = init_fixture_repo(tmp_path)

    head_branch = "feat/progress-125"
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
                "    - [ ] (Optional) Add a ~~backfill~~ script (bad format).",
                "      - Reason: Optional follow-up.",
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
    log_dir = gh_stub_log_dir(tmp_path, "close-progress-pr-invalid-strikethrough")
    spec = {
        "args": [
            "--pr",
            "125",
            "--progress-file",
            "docs/progress/20260113_fixture_progress.md",
            "--no-merge",
        ],
        "timeout_sec": 30,
        "env": {
            "CODEX_GH_STUB_MODE_ENABLED": "true",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "CODEX_GH_STUB_PR_NUMBER": "125",
            "CODEX_GH_STUB_PR_URL": "https://github.com/example/repo/pull/125",
            "CODEX_GH_STUB_TITLE": "Fixture progress close",
            "CODEX_GH_STUB_BASE_REF": "main",
            "CODEX_GH_STUB_HEAD_REF": head_branch,
            "CODEX_GH_STUB_STATE": "OPEN",
        },
        "expect": {
            "exit_codes": [1],
            "stderr_regex": r"unchecked checklist item contains '~~' but is not in the form",
        },
    }

    result = run_smoke_script(script, "fixture-invalid-strikethrough", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    archived = work_tree / "docs" / "progress" / "archived" / "20260113_fixture_progress.md"
    assert not archived.exists()

    subprocess.run(["git", "remote", "get-url", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)
    subprocess.run(["git", "ls-remote", "--heads", "origin"], cwd=str(work_tree), check=True, text=True, capture_output=True)
