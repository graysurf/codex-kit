from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract
from skills.workflows.plan._shared.python import shared_plan_baseline_text, shared_plan_template_text, skill_md_text


def test_workflows_plan_create_plan_rigorous_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_create_plan_rigorous_forbids_cross_sprint_parallel_execution() -> None:
    text = skill_md_text(__file__)
    shared = shared_plan_baseline_text(__file__)

    assert "PLAN_AUTHORING_BASELINE.md" in text
    assert "Treat sprints as sequential integration gates" in shared
    assert "do not imply cross-sprint" in shared.lower()
    assert "Do not schedule cross-sprint execution parallelism." in text
    assert "Build on the `create-plan` baseline" in text


def test_create_plan_rigorous_requires_metadata_for_every_sprint() -> None:
    text = skill_md_text(__file__)

    assert "Record sprint metadata for every sprint" in text
    assert "`**PR grouping intent**: per-sprint|group`" in text
    assert "`**Execution Profile**: serial|parallel-xN`" in text


def test_create_plan_rigorous_defines_pr_and_sprint_complexity_guardrails() -> None:
    text = skill_md_text(__file__)
    assert "PR complexity target is `2-5`; preferred max is `6`." in text
    assert "PR complexity `7-8` is an exception and requires explicit justification" in text
    assert "PR complexity `>8` should be split before execution planning." in text
    assert "CriticalPathComplexity" in text
    assert "Do not use `TotalComplexity` alone as the sizing signal" in text
    assert "`serial`: target `2-4` tasks, `TotalComplexity 8-16`" in text
    assert "`parallel-x2`: target `3-5` tasks, `TotalComplexity 12-22`" in text
    assert "`parallel-x3`: target `4-6` tasks, `TotalComplexity 16-24`" in text


def test_shared_plan_template_includes_rigorous_scorecard_placeholders() -> None:
    shared = shared_plan_template_text(__file__)

    assert "**TotalComplexity**: `<rigorous or sizing-heavy plans>`" in shared
    assert "**CriticalPathComplexity**: `<rigorous or sizing-heavy plans>`" in shared
    assert "**MaxBatchWidth**: `<rigorous or sizing-heavy plans>`" in shared
    assert "**OverlapHotspots**: `<rigorous or sizing-heavy plans>`" in shared


def test_create_plan_rigorous_high_complexity_task_policy_requires_split_or_dedicated_lane() -> None:
    text = skill_md_text(__file__)
    assert "For a task with complexity `>=7`, try to split first" in text
    assert "keep it as a dedicated lane and dedicated PR" in text
    assert "at most one task with complexity `>=7` per sprint" in text
