from __future__ import annotations

import re
from pathlib import Path

from .conftest import repo_root


def iter_progress_script_files(root: Path) -> list[Path]:
    progress_root = root / "skills" / "workflows" / "pr" / "progress"
    if not progress_root.is_dir():
        return []

    out: list[Path] = []
    for path in progress_root.rglob("*"):
        if not path.is_file():
            continue
        if "/scripts/" not in path.as_posix():
            continue
        out.append(path)
    return sorted(out)


def test_no_direct_git_commit_in_progress_scripts() -> None:
    root = repo_root()
    offenders: list[str] = []

    commit_re = re.compile(r"(?m)^[ \t]*(?:command[ \t]+)?git[ \t]+commit\b")
    assert commit_re.search("git commit -m test")
    assert commit_re.search("  command git\tcommit -m test")

    for path in iter_progress_script_files(root):
        text = path.read_text("utf-8", errors="ignore")
        if commit_re.search(text):
            offenders.append(path.relative_to(root).as_posix())

    assert not offenders, "direct git commit is forbidden in progress scripts: " + ", ".join(offenders)
