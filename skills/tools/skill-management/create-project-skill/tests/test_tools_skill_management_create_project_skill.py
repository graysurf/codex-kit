from __future__ import annotations

import subprocess
from tempfile import TemporaryDirectory
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract
from skills._shared.python.skill_testing.assertions import repo_root


def test_tools_skill_management_create_project_skill_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_skill_management_create_project_skill_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/create_project_skill.sh"])


def test_create_project_skill_generates_contract_first_skill_md() -> None:
    root = repo_root()
    create_script = (
        root
        / "skills"
        / "tools"
        / "skill-management"
        / "create-project-skill"
        / "scripts"
        / "create_project_skill.sh"
    )
    validate_script = (
        root
        / "skills"
        / "tools"
        / "skill-management"
        / "skill-governance"
        / "scripts"
        / "validate_skill_contracts.sh"
    )

    with TemporaryDirectory(prefix="create-project-skill-") as tmp:
        project_root = Path(tmp) / "demo-project"
        project_root.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", str(project_root)], check=True)

        proc = subprocess.run(
            [
                "bash",
                str(create_script),
                "--project-path",
                str(project_root),
                "--skill-dir",
                "example-project-skill",
                "--title",
                "Example Project Skill",
                "--description",
                "smoke",
            ],
            cwd=root,
            text=True,
            capture_output=True,
        )
        assert proc.returncode == 0, f"create_project_skill.sh failed:\n{proc.stdout}\n{proc.stderr}"

        skill_root = project_root / ".codex" / "skills" / "example-project-skill"
        skill_md = skill_root / "SKILL.md"
        generated_script = skill_root / "scripts" / "example-project-skill.sh"
        assert skill_md.is_file(), f"missing generated SKILL.md: {skill_md}"
        assert generated_script.is_file(), f"missing generated script: {generated_script}"

        proc2 = subprocess.run(
            [str(validate_script), "--file", str(skill_md)],
            cwd=root,
            text=True,
            capture_output=True,
        )
        assert proc2.returncode == 0, f"validate_skill_contracts.sh failed:\n{proc2.stdout}\n{proc2.stderr}"

        proc3 = subprocess.run(
            ["bash", str(generated_script), "--help"],
            cwd=root,
            text=True,
            capture_output=True,
        )
        assert proc3.returncode == 0, f"generated script --help failed:\n{proc3.stdout}\n{proc3.stderr}"


def test_create_project_skill_rejects_non_codex_skills_prefix() -> None:
    root = repo_root()
    create_script = (
        root
        / "skills"
        / "tools"
        / "skill-management"
        / "create-project-skill"
        / "scripts"
        / "create_project_skill.sh"
    )

    with TemporaryDirectory(prefix="create-project-skill-invalid-") as tmp:
        project_root = Path(tmp) / "demo-project"
        project_root.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", str(project_root)], check=True)

        proc = subprocess.run(
            [
                "bash",
                str(create_script),
                "--project-path",
                str(project_root),
                "--skill-dir",
                ".codex/not-skills/example-project-skill",
            ],
            cwd=root,
            text=True,
            capture_output=True,
        )
        assert proc.returncode == 2, f"expected usage error, got {proc.returncode}:\n{proc.stdout}\n{proc.stderr}"
        assert "must be under .codex/skills/" in proc.stderr
