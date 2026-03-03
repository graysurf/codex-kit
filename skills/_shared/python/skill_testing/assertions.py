from __future__ import annotations

import ast
import os
import shutil
import subprocess
from pathlib import Path
from typing import Iterable


def repo_root() -> Path:
    if code_home := os.environ.get("AGENT_HOME"):
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


def discover_skill_scripts(repo: Path | None = None) -> list[str]:
    root = (repo or repo_root()).resolve()
    scripts: list[str] = []
    for path in root.glob("skills/**/scripts/*"):
        if path.is_file():
            scripts.append(path.relative_to(root).as_posix())
    return sorted(set(scripts))


def _extract_entrypoint_literals(test_file: Path) -> list[str]:
    try:
        tree = ast.parse(test_file.read_text("utf-8"))
    except (OSError, SyntaxError):
        return []

    rel_paths: list[str] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if not isinstance(node.func, ast.Name) or node.func.id != "assert_entrypoints_exist":
            continue

        candidate: ast.AST | None = None
        if len(node.args) >= 2:
            candidate = node.args[1]
        else:
            for keyword in node.keywords:
                if keyword.arg == "rel_paths":
                    candidate = keyword.value
                    break
        if candidate is None:
            continue

        try:
            literal = ast.literal_eval(candidate)
        except (TypeError, ValueError):
            continue
        if not isinstance(literal, (list, tuple)):
            continue
        for rel in literal:
            if isinstance(rel, str):
                rel_paths.append(rel)
    return rel_paths


def discover_owned_skill_entrypoints(repo: Path | None = None) -> set[str]:
    root = (repo or repo_root()).resolve()
    owned: set[str] = set()

    for test_file in root.glob("skills/**/tests/test_*.py"):
        skill_root = test_file.parent.parent
        for rel in _extract_entrypoint_literals(test_file):
            owned.add((skill_root / rel).relative_to(root).as_posix())

    return owned


def assert_skill_script_entrypoint_ownership(
    repo: Path | None = None,
    *,
    approved_exclusions: Iterable[str] = (),
) -> None:
    root = (repo or repo_root()).resolve()
    skill_scripts = set(discover_skill_scripts(root))
    owned_scripts = discover_owned_skill_entrypoints(root)

    exclusions: set[str] = set()
    for path in approved_exclusions:
        normalized = Path(path).as_posix().lstrip("./")
        exclusions.add(normalized)

    invalid_exclusions = sorted(
        exclusion
        for exclusion in exclusions
        if not exclusion.startswith("skills/") or "/scripts/" not in exclusion
    )
    if invalid_exclusions:
        raise AssertionError(
            "approved exclusions must be explicit skill script paths under skills/**/scripts/: "
            f"{', '.join(invalid_exclusions)}"
        )

    missing_exclusions = sorted(exclusions - skill_scripts)
    if missing_exclusions:
        raise AssertionError(
            "approved exclusions must reference existing scripts: "
            f"{', '.join(missing_exclusions)}"
        )

    unowned = sorted(skill_scripts - owned_scripts - exclusions)
    if unowned:
        raise AssertionError(
            "unowned skill scripts detected (add assert_entrypoints_exist in the matching skill tests or add a reviewed exclusion): "
            f"{', '.join(unowned)}"
        )


def resolve_codex_command(name: str) -> Path:
    if found := shutil.which(name):
        return Path(found).resolve()

    if name == "project-resolve":
        candidate = repo_root() / "scripts" / "project-resolve"
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
        raise AssertionError(f"{name} not found (install on PATH or use scripts/project-resolve)")

    raise AssertionError(f"{name} not found (install on PATH)")
