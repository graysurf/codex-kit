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
    assert "plan-tooling to-json --file docs/plans/<slug>/<slug>-plan.md --sprint <n>" in shared
    assert "plan-tooling batches --file docs/plans/<slug>/<slug>-plan.md --sprint <n>" in shared
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


def test_create_plan_distinguishes_plans_from_durable_improvement_records() -> None:
    text = skill_md_text(__file__)

    assert "Confirm that a plan is the right artifact" in text
    assert "Do not force `docs/plans/`" in text
    assert "preserve review findings" in text
    assert "Use `review-to-improvement-doc`" in text
    assert "Use `discussion-to-implementation-doc`" in text
    assert "durable review/improvement record" in text
    assert "link that doc under the plan's" in text
    assert "context/read-first section" in text
    assert "use `execute-from-implementation-doc` instead" in text


def test_create_plan_requires_primary_source_artifact_before_plan() -> None:
    text = skill_md_text(__file__)
    shared = shared_plan_baseline_text(__file__)
    template = shared_plan_template_text(__file__)

    assert "Establish the plan source artifact" in text
    assert "Every plan must have exactly one primary source artifact" in text
    assert "`discussion-to-implementation-doc`" in text
    assert "`review-to-improvement-doc`" in text
    assert "docs/plans/<slug>/<slug>-discussion-source.md" in text
    assert "docs/plans/<slug>/<slug>-review-source.md" in text
    assert "heuristic-system/error-inbox/<slug>.md" in text
    assert "coordination artifacts" in text
    assert "cleanup after execution" in text
    assert "<slug>-discussion-source.md" in shared
    assert "<slug>-review-source.md" in shared
    assert "docs/plans/<slug>/<slug>-plan.md" in shared
    assert "plan-tooling scaffold --slug <slug>" in shared
    assert "nils-cli >= 0.8.7" in text
    assert "Link the primary source under `Read First`" in text
    assert "Every plan needs a primary source artifact" in shared
    assert "Source type" in shared
    assert "## Read First" in template
    assert "Primary source:" in template


def test_shared_plan_template_includes_optional_base_execution_metadata() -> None:
    shared = shared_plan_template_text(__file__)

    assert "**PR grouping intent**: `<optional: per-sprint|group>`" in shared
    assert "**Execution Profile**: `<optional: serial|parallel-xN>`" in shared
    assert "<optional for create-plan; required for create-dispatch-plan>" in shared
