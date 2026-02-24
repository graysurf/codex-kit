from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_automation_plan_issue_delivery_loop_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_plan_issue_delivery_loop_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/plan-issue-delivery-loop.sh"])


def test_plan_issue_delivery_loop_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is orchestration/review-only." in text
    assert "Main-agent does not implement sprint tasks directly." in text
    assert "subagent-owned PRs" in text
    assert "1 plan = 1 issue" in text
    assert "PR grouping controls" in text
    assert "## Full Skill Flow" in text


def test_plan_issue_delivery_loop_skill_requires_close_for_done() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed, and worktree cleanup passes." in text
    assert "A successful run must terminate at `close-plan` with:" in text
    assert "If any close gate fails, treat the run as unfinished" in text


def test_plan_issue_delivery_loop_script_supports_sprint_progression_flow() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")
    assert "start-plan" in text
    assert "close-plan" in text
    assert "build-plan-task-spec" in text
    assert "start-sprint" in text
    assert "accept-sprint" in text
    assert "next-sprint" not in text
    assert "multi-sprint-guide" in text
    assert "cleanup-worktrees" in text
    assert "close-after-review" in text
    assert "issue_lifecycle_script" in text
    assert "render_plan_issue_body_from_task_spec" in text
    assert '"to-json"' in text
    assert "validate_pr_grouping_args" in text
    assert "--pr-grouping <mode>" in text
    assert "--pr-group <task=group>" in text
    assert "--subagent-prompts-out <dir>" in text
    assert "per-sprint | group (required; `per-spring` alias accepted)" in text
    assert "--pr-grouping is required (per-sprint|group)" in text
    assert "per-task (default)" not in text
    assert "--pr-grouping manual" not in text
    assert "--pr-grouping auto" not in text
    assert "render_subagent_task_prompts" in text
    assert "SUBAGENT_PROMPT_POLICY=MANDATORY_RENDERED_PROMPT" in text
    assert "START_SUBAGENT_INPUT=TASK_PROMPT_PATH" in text
    assert "SUBAGENT_DISPATCH_POLICY=RENDERED_TASK_PROMPT_REQUIRED" in text
    assert "PR_GROUP=" in text
    assert "OPEN_PR_CMD=SHARED_WITH_GROUP" in text
    assert "sync_issue_sprint_task_rows" in text
    assert "enforce_sprint_merge_gate" in text
    assert "PREVIOUS_SPRINT_GATE=PASS" in text
    assert "SPRINT_STATUS_SYNC=UPDATED_TO_DONE" in text
    assert "PR values come from current Task Decomposition" in text
    assert "group_anchor" in text
    assert "MODE=DRY_RUN_LOCAL" in text
    assert "NOTE_DRY_RUN=" in text
    assert "default_dry_run_issue_number" in text


def test_plan_issue_delivery_loop_close_plan_enforces_worktree_cleanup() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")
    assert "cleanup_plan_issue_worktrees" in text
    assert "--issue is required for close-plan" in text
    assert "--body-file is required for close-plan --dry-run" in text
    assert "PLAN_CLOSE_SCOPE=LOCAL_BODY_FILE" in text
    assert "close-plan always runs strict worktree cleanup" in text
    assert "WORKTREE_CLEANUP_STATUS=PASS" in text
    assert "PLAN_CLOSE_STATUS=SUCCESS" in text
    assert "DONE_CRITERIA=ISSUE_CLOSED_AND_WORKTREES_CLEANED" in text


def test_plan_issue_delivery_loop_sprint_comment_omits_redundant_plan_metadata() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")
    assert 'print(f"- Plan issue: #{issue_number}")' not in text
    assert 'print(f"- Plan file: `{plan_file}`")' not in text


def test_plan_issue_delivery_loop_sprint_comment_prefers_issue_pr_values() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")
    assert "load_issue_pr_values" in text
    assert "normalize_pr_display" in text
    assert "Execution Mode comes from current Task Decomposition for each sprint task." in text
    assert "| Task | Summary | Execution Mode |" in text
    assert "PR values come from current Task Decomposition; unresolved tasks remain `TBD` until PRs are linked." in text
    assert "extract_sprint_section" in text
    assert 'if mode == "start":' in text
    assert "pr-shared" in text
    assert "pr-isolated" in text
    assert "single-pr" not in text


def test_plan_issue_delivery_loop_sprint_comments_are_posted_after_sync() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")

    start_block = text.split("start_sprint_cmd() {", maxsplit=1)[1].split("ready_sprint_cmd() {", maxsplit=1)[0]
    ready_block = text.split("ready_sprint_cmd() {", maxsplit=1)[1].split("accept_sprint_cmd() {", maxsplit=1)[0]
    accept_block = text.split("accept_sprint_cmd() {", maxsplit=1)[1].split("multi_sprint_guide_cmd() {", maxsplit=1)[0]

    sync_call = 'sync_issue_sprint_task_rows "$issue_number" "$task_spec_out" "$repo_arg" "$dry_run"'
    comment_call = 'run_issue_lifecycle "$dry_run" "$repo_arg" comment --issue "$issue_number" --body "$comment_body" >/dev/null'

    assert start_block.index(sync_call) < start_block.index(comment_call)
    assert ready_block.index(sync_call) < ready_block.index(comment_call)
    assert accept_block.index(sync_call) < accept_block.index(comment_call)


def test_plan_issue_delivery_loop_sprint_comment_markers_do_not_fail_after_post() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "plan-issue-delivery-loop.sh").read_text(encoding="utf-8")
    assert "printf 'SPRINT_COMMENT_POSTED=1\\n' || true" in text
    assert "printf 'SPRINT_READY_COMMENT_POSTED=1\\n' || true" in text
    assert "printf 'SPRINT_ACCEPT_COMMENT_POSTED=1\\n' || true" in text
    assert "printf 'PLAN_ISSUE_REMAINS_OPEN=1\\n' || true" in text
