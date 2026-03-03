from __future__ import annotations

import shutil
import subprocess
import uuid
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract
from skills._shared.python.skill_testing.assertions import repo_root


def test_tools_skill_management_create_skill_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_skill_management_create_skill_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/create_skill.sh"])


def test_create_skill_contract_references_current_entrypoints() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")

    assert "$AGENT_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh" in text
    assert "$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh" in text
    assert "$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh" in text
    assert "legacy wrapper paths are not supported" in text.lower()


def test_create_skill_generates_contract_first_skill_md() -> None:
    root = repo_root()
    create_script = (
        root / "skills" / "tools" / "skill-management" / "create-skill" / "scripts" / "create_skill.sh"
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

    skill_dir = root / "skills" / "tools" / "_tmp" / f"create-skill-contract-first-{uuid.uuid4().hex}"
    rel_skill_dir = skill_dir.relative_to(root).as_posix()
    readme = root / "README.md"
    original_readme = readme.read_text(encoding="utf-8")
    skill_desc = "Smoke skill catalog update from create-skill"
    expected_link = f"(./{rel_skill_dir}/)"

    try:
        proc = subprocess.run(
            [
                "bash",
                str(create_script),
                "--skill-dir",
                rel_skill_dir,
                "--title",
                "Create Skill Contract First Smoke",
                "--description",
                skill_desc,
            ],
            cwd=root,
            text=True,
            capture_output=True,
        )
        assert proc.returncode == 0, f"create_skill.sh failed:\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"

        skill_md = skill_dir / "SKILL.md"
        assert skill_md.is_file()

        proc2 = subprocess.run(
            [str(validate_script), "--file", str(skill_md)],
            cwd=root,
            text=True,
            capture_output=True,
        )
        assert proc2.returncode == 0, f"validate_skill_contracts.sh failed:\n{proc2.stderr}"

        readme_after = readme.read_text(encoding="utf-8")
        assert expected_link in readme_after, "README is missing the new skill link entry"
        assert skill_desc in readme_after, "README is missing the new skill description entry"
    finally:
        readme.write_text(original_readme, encoding="utf-8")
        if skill_dir.exists():
            shutil.rmtree(skill_dir)
