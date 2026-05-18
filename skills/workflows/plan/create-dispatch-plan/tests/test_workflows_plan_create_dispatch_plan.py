from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract
from skills.workflows.plan._shared.python import shared_plan_baseline_text, shared_plan_template_text, skill_md_text


def test_workflows_plan_create_dispatch_plan_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_create_dispatch_plan_forbids_cross_sprint_parallel_execution() -> None:
    text = skill_md_text(__file__)
    shared = shared_plan_baseline_text(__file__)

    assert "PLAN_AUTHORING_BASELINE.md" in text
    assert "Treat sprints as sequential integration gates" in shared
    assert "do not imply cross-sprint" in shared.lower()
    assert "Do not schedule cross-sprint execution parallelism." in text
    assert "Build on the `create-plan` baseline" in text


def test_create_dispatch_plan_requires_metadata_for_every_sprint() -> None:
    text = skill_md_text(__file__)

    assert "Record sprint metadata for every sprint" in text
    assert "`**PR grouping intent**: per-sprint|group`" in text
    assert "`**Execution Profile**: serial|parallel-xN`" in text


def test_create_dispatch_plan_defines_pr_and_sprint_complexity_guardrails() -> None:
    text = skill_md_text(__file__)
    assert "PR complexity target is `2-5`; preferred max is `6`." in text
    assert "PR complexity `7-8` is an exception and requires explicit justification" in text
    assert "PR complexity `>8` should be split before execution planning." in text
    assert "CriticalPathComplexity" in text
    assert "Do not use `TotalComplexity` alone as the sizing signal" in text
    assert "`serial`: target `2-4` tasks, `TotalComplexity 8-16`" in text
    assert "`parallel-x2`: target `3-5` tasks, `TotalComplexity 12-22`" in text
    assert "`parallel-x3`: target `4-6` tasks, `TotalComplexity 16-24`" in text


def test_shared_plan_template_includes_dispatch_scorecard_placeholders() -> None:
    shared = shared_plan_template_text(__file__)

    assert "**TotalComplexity**: `<dispatch or sizing-heavy plans>`" in shared
    assert "**CriticalPathComplexity**: `<dispatch or sizing-heavy plans>`" in shared
    assert "**MaxBatchWidth**: `<dispatch or sizing-heavy plans>`" in shared
    assert "**OverlapHotspots**: `<dispatch or sizing-heavy plans>`" in shared


def test_create_dispatch_plan_high_complexity_task_policy_requires_split_or_dedicated_lane() -> None:
    text = skill_md_text(__file__)
    assert "For a task with complexity `>=7`, try to split first" in text
    assert "keep it as a dedicated lane and dedicated PR" in text
    assert "at most one task with complexity `>=7` per sprint" in text


def test_create_dispatch_plan_routes_durable_findings_to_improvement_doc() -> None:
    text = skill_md_text(__file__)

    assert "Confirm that dispatch planning is the right artifact" in text
    assert "Use `review-to-improvement-doc` first" in text
    assert "Use `discussion-to-implementation-doc` first" in text
    assert "durable review/improvement record" in text
    assert "link that document as read-first context" in text


def test_create_dispatch_plan_requires_source_artifact_and_review_check() -> None:
    text = skill_md_text(__file__)
    shared = shared_plan_baseline_text(__file__)
    template = shared_plan_template_text(__file__)

    assert "Establish the plan source artifact" in text
    assert "Dispatch plans must have exactly one primary source artifact" in text
    assert "docs/plans/<slug>/<slug>-discussion-source.md" in text
    assert "docs/plans/<slug>/<slug>-review-source.md" in text
    assert "coordination artifacts" in text
    assert "cleanup after execution" in text
    assert "Link the primary source under `Read First`" in text
    assert "one primary source artifact or an explicit" in text
    assert "plan-only waiver" in text
    assert "Every plan needs a primary source artifact" in shared
    assert "<slug>-review-source.md" in shared
    assert "docs/plans/<slug>/<slug>-plan.md" in shared
    assert "nils-cli >= 0.8.7" in text
    assert "## Read First" in template
    assert "Open questions carried into execution" in template
