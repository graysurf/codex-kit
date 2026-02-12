from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path
from urllib.parse import urlparse

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_pr_feature_create_feature_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_feature_create_feature_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/render_feature_pr.sh",
        ],
    )


def _run_render(
    *args: str,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    script = Path(__file__).resolve().parents[1] / "scripts" / "render_feature_pr.sh"
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(
        [str(script), *args],
        text=True,
        capture_output=True,
        check=False,
        cwd=None if cwd is None else str(cwd),
        env=run_env,
    )


def _skill_md_text() -> str:
    return (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")


def test_render_feature_pr_omits_optional_sections_when_missing() -> None:
    result = _run_render("--pr")
    assert result.returncode == 0, result.stderr
    assert "## Progress" not in result.stdout
    assert "## Planning PR" not in result.stdout
    assert "## Status" in result.stdout
    assert "- kickoff: implementation in progress (draft PR)" in result.stdout
    assert "## Summary" in result.stdout
    assert "## Changes" in result.stdout


def test_render_feature_pr_includes_optional_sections_when_provided() -> None:
    result = _run_render(
        "--pr",
        "--from-progress-pr",
        "--progress-url",
        "https://github.com/org/repo/blob/feat-branch/docs/progress/20260206_slug.md",
        "--planning-pr",
        "#123",
    )
    assert result.returncode == 0, result.stderr
    assert "## Progress" in result.stdout
    assert "## Planning PR" in result.stdout
    assert "- #123" in result.stdout
    assert "https://github.com/org/repo/blob/feat-branch/docs/progress/20260206_slug.md" in result.stdout


def test_render_feature_pr_rejects_optional_flags_without_from_progress_pr() -> None:
    result = _run_render(
        "--pr",
        "--progress-url",
        "https://github.com/org/repo/blob/feat-branch/docs/progress/20260206_slug.md",
        "--planning-pr",
        "#123",
    )
    assert result.returncode == 1
    assert "--from-progress-pr" in result.stderr


def test_render_feature_pr_builds_progress_url_from_progress_file() -> None:
    result = _run_render(
        "--pr",
        "--from-progress-pr",
        "--progress-file",
        "docs/progress/20260206_slug.md",
        "--planning-pr",
        "123",
    )
    assert result.returncode == 0, result.stderr
    assert "## Progress" in result.stdout
    assert "## Planning PR" in result.stdout
    assert "- #123" in result.stdout
    match = re.search(r"\((https://[^\s)]+)\)", result.stdout)
    assert match is not None, result.stdout
    parsed = urlparse(match.group(1))
    assert parsed.scheme == "https"
    assert parsed.netloc == "github.com"
    assert parsed.path.endswith("/docs/progress/20260206_slug.md")


def test_render_feature_pr_builds_progress_url_with_detached_head_fallback(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()

    subprocess.run(["git", "init", "-q"], cwd=str(repo), check=True)
    subprocess.run(["git", "config", "user.email", "fixture@example.com"], cwd=str(repo), check=True)
    subprocess.run(["git", "config", "user.name", "Fixture User"], cwd=str(repo), check=True)
    (repo / "README.md").write_text("fixture\n", encoding="utf-8")
    subprocess.run(["git", "add", "README.md"], cwd=str(repo), check=True)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=str(repo), check=True)
    subprocess.run(["git", "remote", "add", "origin", "https://github.com/org/repo.git"], cwd=str(repo), check=True)

    head_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=str(repo), text=True).strip()
    subprocess.run(["git", "checkout", "--detach", head_sha], cwd=str(repo), check=True)

    result = _run_render(
        "--pr",
        "--from-progress-pr",
        "--progress-file",
        "docs/progress/20260206_slug.md",
        "--planning-pr",
        "123",
        cwd=repo,
        env={"GITHUB_HEAD_REF": "feat/fallback-branch"},
    )
    assert result.returncode == 0, result.stderr
    assert "https://github.com/org/repo/blob/feat/fallback-branch/docs/progress/20260206_slug.md" in result.stdout


def test_create_feature_pr_skill_avoids_commit_subject_narrative() -> None:
    text = _skill_md_text()
    assert "do not derive PR title/body from `git log -1 --pretty=%B`." in text
    assert "commits like `Add plan file` are not valid PR title/body sources." in text


def test_create_feature_pr_skill_opens_draft_pr_by_default() -> None:
    text = _skill_md_text()
    assert "`gh pr create --draft ...`" in text
    assert "Open draft PRs by default; only open non-draft when the user explicitly requests it." in text


def test_create_feature_pr_skill_scopes_progress_sections_to_progress_flow() -> None:
    text = _skill_md_text()
    assert "Use this section only when the feature PR is derived from a progress PR." in text
    assert "--from-progress-pr --planning-pr <number>" in text
