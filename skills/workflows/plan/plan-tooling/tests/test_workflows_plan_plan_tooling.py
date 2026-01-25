from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_plan_plan_tooling_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_plan_plan_tooling_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/validate_plans.sh",
            "scripts/plan_to_json.sh",
            "scripts/plan_batches.sh",
            "scripts/scaffold_plan.sh",
        ],
    )
