from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_tools_skill_management_skill_governance_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_skill_management_skill_governance_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/audit-skill-layout.sh",
            "scripts/validate_skill_contracts.sh",
            "scripts/validate_skill_paths.sh",
        ],
    )
