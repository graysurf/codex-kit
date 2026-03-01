from __future__ import annotations

import re
from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_automation_plan_issue_delivery_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_plan_issue_delivery_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is orchestration/review-only." in text
    assert "Main-agent does not implement sprint tasks directly." in text
    assert "subagent-owned PRs" in text
    assert "1 plan = 1 issue" in text
    assert "PR grouping controls" in text
    assert "PR Grouping Steps (Mandatory)" in text
    assert "--strategy auto --default-pr-grouping group" in text
    assert "group + deterministic" in text
    assert "## Full Skill Flow" in text
    assert "--pr-grouping group --strategy auto" not in text


def test_plan_issue_delivery_skill_requires_close_for_done() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed" in text
    assert "worktree cleanup passes." in text
    assert "A successful run must terminate at `close-plan` with:" in text
    assert "If any close gate fails, treat the run as unfinished" in text


def test_plan_issue_delivery_skill_uses_binary_first_command_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "plan-issue" in text
    assert "plan-issue-local" in text
    assert "start-plan" in text
    assert "start-sprint" in text
    assert "link-pr" in text
    assert "status-plan" in text
    assert "ready-sprint" in text
    assert "accept-sprint" in text
    assert "ready-plan" in text
    assert "close-plan" in text
    assert "plan-issue ready-plan --issue <number> [--repo <owner/repo>]" in text
    assert (
        "plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]"
        in text
    )


def test_plan_issue_delivery_local_rehearsal_uses_metadata_first_auto_default() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "references" / "LOCAL_REHEARSAL.md").read_text(encoding="utf-8")
    assert "--strategy auto --default-pr-grouping group" in text
    assert "--pr-grouping group --strategy auto" not in text


def test_plan_issue_delivery_skill_mentions_split_prs_v2_runtime_ownership() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "split-prs" in text
    assert "grouping primitives only" in text
    assert "materializes runtime metadata" in text


def test_plan_issue_delivery_skill_defines_runtime_workspace_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "$AGENT_HOME/out/plan-issue-delivery" in text
    assert "Runtime Workspace Policy (Mandatory)" in text
    assert "PLAN_SNAPSHOT_PATH" in text
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" in text
    assert "DISPATCH_RECORD_PATH" in text
    assert "references/RUNTIME_LAYOUT.md" in text


def test_plan_issue_delivery_skill_uses_shared_task_lane_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in text


def test_plan_issue_delivery_skill_uses_shared_review_rubric() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md" in text
    assert "reviews each sprint PR against the shared review rubric" in text


def test_plan_issue_delivery_skill_uses_shared_post_review_outcomes() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md" in text
    assert "After each review decision" in text
    assert "--row-status" in text
    assert "--next-owner" in text
    assert "--close-reason" in text


def test_plan_issue_delivery_prompts_align_runtime_and_dispatch_bundle() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    repo_root = skill_root.parents[2]

    subagent_prompt = (repo_root / "prompts" / "plan-issue-delivery-subagent-init.md").read_text(encoding="utf-8")
    main_agent_prompt = (repo_root / "prompts" / "plan-issue-delivery-main-agent-init.md").read_text(encoding="utf-8")

    assert "PLAN_SNAPSHOT_PATH" in subagent_prompt
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" in subagent_prompt
    assert "DISPATCH_RECORD_PATH" in subagent_prompt
    assert "$AGENT_HOME/out/plan-issue-delivery" in subagent_prompt

    assert "PLAN_SNAPSHOT_PATH" in main_agent_prompt
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" in main_agent_prompt
    assert "DISPATCH_RECORD_PATH" in main_agent_prompt
    assert "$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md" in main_agent_prompt
    assert "$AGENT_HOME/out/plan-issue-delivery" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in subagent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md" in main_agent_prompt
    assert "--next-owner" in main_agent_prompt
    assert "--close-reason" in main_agent_prompt


def test_plan_issue_delivery_skill_excludes_deleted_wrapper_scripts() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert ("plan-issue-delivery" + ".sh") not in text
    assert ("manage_issue_delivery_loop" + ".sh") not in text
    assert ("manage_issue_subagent_pr" + ".sh") not in text


def test_plan_issue_delivery_e2e_sprint1_fixture_artifact_labels_and_pr_markers() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    fixture_path = repo_root / "tests" / "fixtures" / "issue" / "plan_issue_delivery_e2e_sprint1.md"
    text = fixture_path.read_text(encoding="utf-8")

    expected_task_decomposition_header = "| Task ID | Summary | Owner | Branch | Worktree | PR | Status |"
    assert "## Task Decomposition" in text, (
        f"Sprint 1 fixture must include '## Task Decomposition': {fixture_path}"
    )
    assert expected_task_decomposition_header in text, (
        "Sprint 1 fixture is missing required artifact labels in the Task Decomposition table header; "
        f"expected exact header: {expected_task_decomposition_header}"
    )

    row_pattern = re.compile(
        r"^\| (?P<task_id>S1T\d+) \| (?P<summary>[^|]+) \| (?P<owner>[^|]+) \| "
        r"(?P<branch>[^|]+) \| (?P<worktree>[^|]+) \| (?P<pr>[^|]+) \| (?P<status>[^|]+) \|$"
    )
    rows = [match.groupdict() for line in text.splitlines() if (match := row_pattern.match(line.strip()))]
    assert rows, (
        "Sprint 1 fixture has no S1T* Task Decomposition rows; expected rows with canonical PR markers like '#101'."
    )

    for row in rows:
        pr_token = row["pr"].strip()
        assert re.fullmatch(r"#\d+", pr_token), (
            f"Sprint 1 fixture PR marker for {row['task_id']} must use canonical '#<number>' format, "
            f"found '{pr_token}'."
        )


def test_plan_issue_delivery_e2e_sprint2_invariants() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    fixture_path = repo_root / "tests" / "fixtures" / "issue" / "plan_issue_delivery_e2e_sprint2.md"
    assert fixture_path.exists(), "Sprint 2 fixture is required for normalized PR/done-state regression checks."

    text = fixture_path.read_text(encoding="utf-8")
    assert "## Task Decomposition" in text, "Sprint 2 fixture must define a Task Decomposition section."
    assert "#201" in text, "Sprint 2 fixture must keep canonical PR marker #201."
    assert "#202" in text, "Sprint 2 fixture must keep canonical PR marker #202."
    assert "pr-shared" in text, "Sprint 2 fixture must explicitly encode pr-shared lane behavior."

    rows = [line for line in text.splitlines() if line.startswith("| S2T")]
    assert rows, "Sprint 2 fixture must include task rows for Sprint 2 decomposition."
    for row in rows:
        assert "| done |" in row, f"Sprint 2 row must retain done-state marker: {row}"

    grouped_rows = [row for row in rows if row.startswith("| S2T2 ") or row.startswith("| S2T3 ")]
    assert grouped_rows, "Sprint 2 fixture must include grouped lane rows for S2T2/S2T3."
    for row in grouped_rows:
        assert "| #201 |" in row, f"Grouped Sprint 2 lane rows must keep canonical shared PR #201: {row}"

    assert "https://github.com/" not in text, "Sprint 2 fixture should not drift to URL-only PR references."
