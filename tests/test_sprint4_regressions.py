from __future__ import annotations

import configparser
import re
from pathlib import Path

from .conftest import repo_root


def iter_non_comment_lines(path: Path) -> list[tuple[int, str]]:
    lines = path.read_text("utf-8", errors="ignore").splitlines()
    out: list[tuple[int, str]] = []
    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        out.append((idx, line))
    return out


def test_close_progress_pr_no_delete_branch_flag() -> None:
    path = repo_root() / "skills" / "workflows" / "pr" / "progress" / "close-progress-pr" / "scripts" / "close_progress_pr.sh"
    offenders = find_non_comment_token_offenders(path, "--delete-branch")

    assert not offenders, "found --delete-branch in non-comment lines:\n" + "\n".join(offenders)


def find_non_comment_token_offenders(path: Path, token: str) -> list[str]:
    offenders: list[str] = []
    for lineno, line in iter_non_comment_lines(path):
        if token in line:
            offenders.append(f"{path.as_posix()}:{lineno}: {line.strip()}")
    return offenders


def test_handoff_progress_pr_no_delete_branch_flag() -> None:
    path = (
        repo_root()
        / "skills"
        / "workflows"
        / "pr"
        / "progress"
        / "handoff-progress-pr"
        / "scripts"
        / "handoff_progress_pr.sh"
    )
    offenders = find_non_comment_token_offenders(path, "--delete-branch")

    assert not offenders, "found --delete-branch in non-comment lines:\n" + "\n".join(offenders)


def test_pytest_ini_keeps_out_tmp_in_norecursedirs() -> None:
    path = repo_root() / "pytest.ini"
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(path)
    if not parser.has_section("pytest"):
        raise AssertionError("pytest.ini missing [pytest] section")
    norecursedirs = parser.get("pytest", "norecursedirs", fallback="")
    values = {line.strip() for line in norecursedirs.splitlines() if line.strip()}

    missing = sorted({"out", "tmp"} - values)
    assert not missing, f"pytest.ini norecursedirs missing: {', '.join(missing)}"


def test_e2e_progress_pr_workflow_gh_pr_create_uses_head() -> None:
    path = repo_root() / "scripts" / "e2e" / "progress_pr_workflow.sh"
    text = "\n".join(line for _, line in iter_non_comment_lines(path))

    for match in re.finditer(r"\\bgh\\s+pr\\s+create\\b", text):
        window = text[match.start() : match.start() + 800]
        if "--head" not in window:
            snippet = window[:200].strip().replace("\n", " ")
            raise AssertionError(f"gh pr create missing --head near: {snippet}")
