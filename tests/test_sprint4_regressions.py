from __future__ import annotations

import configparser

from .conftest import repo_root


def test_pytest_ini_keeps_worktree_out_tmp_in_norecursedirs() -> None:
    path = repo_root() / "pytest.ini"
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(path)
    if not parser.has_section("pytest"):
        raise AssertionError("pytest.ini missing [pytest] section")
    norecursedirs = parser.get("pytest", "norecursedirs", fallback="")
    values = {line.strip() for line in norecursedirs.splitlines() if line.strip()}

    missing = sorted({"worktrees", ".worktrees", "out", "tmp"} - values)
    assert not missing, f"pytest.ini norecursedirs missing: {', '.join(missing)}"


def test_scripts_test_sh_ignores_worktrees_by_default() -> None:
    path = repo_root() / "scripts" / "test.sh"
    text = path.read_text("utf-8", errors="ignore")
    assert "CODEX_PYTEST_INCLUDE_WORKTREES" in text
    assert "--ignore=worktrees" in text
    assert "--ignore=.worktrees" in text
