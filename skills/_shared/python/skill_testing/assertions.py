from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Iterable


def repo_root() -> Path:
    if code_home := os.environ.get("CODEX_HOME"):
        path = Path(code_home)
        if path.is_dir():
            return path.resolve()
    root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    return Path(root).resolve()


def assert_skill_contract(skill_root: Path) -> None:
    skill_md = skill_root / "SKILL.md"
    if not skill_md.is_file():
        raise AssertionError(f"missing SKILL.md: {skill_md}")

    script = (
        repo_root()
        / "skills"
        / "tools"
        / "skill-management"
        / "skill-governance"
        / "scripts"
        / "validate_skill_contracts.sh"
    )
    if not script.is_file():
        raise AssertionError(f"missing validator script: {script}")

    proc = subprocess.run(
        [str(script), "--file", str(skill_md)],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise AssertionError(
            "skill contract validation failed:\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )


def assert_entrypoints_exist(skill_root: Path, rel_paths: Iterable[str]) -> None:
    missing: list[str] = []
    for rel in rel_paths:
        path = skill_root / rel
        if not path.is_file():
            missing.append(rel)
    if missing:
        raise AssertionError(f"missing entrypoints: {', '.join(missing)}")


def resolve_codex_command(name: str) -> Path:
    if found := shutil.which(name):
        return Path(found).resolve()

    if name == "project-resolve":
        candidate = repo_root() / "scripts" / "project-resolve"
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
        raise AssertionError(f"{name} not found (install on PATH or use scripts/project-resolve)")

    raise AssertionError(f"{name} not found (install on PATH)")
