from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract
from skills.workflows.plan._shared.python import shared_plan_baseline_text, shared_plan_template_text, skill_md_text


def test_workflows_plan_create_plan_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_create_plan_references_shared_plan_baseline_for_executability_rules() -> None:
    text = skill_md_text(__file__)
    shared = shared_plan_baseline_text(__file__)

    assert "PLAN_AUTHORING_BASELINE.md" in text
    assert "plan-tooling to-json --file docs/plans/<slug>-plan.md --sprint <n>" in shared
    assert "plan-tooling batches --file docs/plans/<slug>-plan.md --sprint <n>" in shared
    assert "--strategy auto --default-pr-grouping group --format json" in shared
    assert "--pr-grouping group --strategy deterministic --pr-group ... --format json" in shared
    assert "--pr-grouping per-sprint --strategy deterministic --format json" in shared


def test_create_plan_keeps_base_skill_policies_local_while_using_shared_cross_sprint_rules() -> None:
    text = skill_md_text(__file__)
    shared = shared_plan_baseline_text(__file__)

    assert "Treat sprints as sequential integration gates" in shared
    assert "do not imply cross-sprint" in shared.lower()
    assert "execution parallelism" in shared.lower()
    assert "`**PR grouping intent**: per-sprint|group`" in shared
    assert "`**Execution Profile**: serial|parallel-xN`" in shared
    assert "If `PR grouping intent` is `per-sprint`, do not declare parallel width" in shared
    assert "`>1`." in shared
    assert "Add sprint metadata only when the plan needs explicit grouping/parallelism metadata" in text
    assert "You may omit sprint scorecards unless the user explicitly wants deeper sizing analysis" in text


def test_shared_plan_template_includes_optional_base_execution_metadata() -> None:
    shared = shared_plan_template_text(__file__)

    assert "**PR grouping intent**: `<optional: per-sprint|group>`" in shared
    assert "**Execution Profile**: `<optional: serial|parallel-xN>`" in shared
    assert "<optional for create-plan; required for create-plan-rigorous>" in shared
