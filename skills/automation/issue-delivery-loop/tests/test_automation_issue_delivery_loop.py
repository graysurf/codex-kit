from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_automation_issue_delivery_loop_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_automation_issue_delivery_loop_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(
        skill_root,
        [
            "scripts/manage_issue_delivery_loop.sh",
        ],
    )


def test_issue_delivery_loop_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is limited to issue orchestration" in text
    assert "Main-agent must not implement issue tasks directly." in text
    assert "implementation must be produced by a subagent PR" in text


def test_issue_delivery_loop_skill_requires_close_for_done() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Definition of done: execution is complete only when `close-after-review` succeeds and the target issue is actually closed." in text
    assert "A successful run must terminate at `close-after-review` with issue state `CLOSED`." in text
    assert "If close gates fail, treat the run as unfinished" in text


def test_issue_delivery_loop_script_enforces_subagent_owner_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "manage_issue_delivery_loop.sh").read_text(encoding="utf-8")
    assert "enforce_subagent_owner_policy" in text
    assert "Owner must not be main-agent" in text
    assert "Owner must include 'subagent'" in text
    assert "canonical_pr_display" in text
    assert "pr_refs=()" in text
    assert "Tasks [" in text
    assert "(tasks: " in text


def test_issue_delivery_loop_close_emits_done_markers() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "manage_issue_delivery_loop.sh").read_text(encoding="utf-8")
    assert "ISSUE_CLOSE_STATUS=SUCCESS" in text
    assert "DONE_CRITERIA=ISSUE_CLOSED" in text
    assert "close-after-review did not close issue" in text


def test_issue_delivery_loop_review_request_omits_issue_line() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "manage_issue_delivery_loop.sh").read_text(encoding="utf-8")
    assert "## Main-Agent Review Request" in text
    assert 'output+="- Issue: ${issue_ref}${nl}"' not in text


def test_issue_delivery_loop_status_snapshot_omits_source_line() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "scripts" / "manage_issue_delivery_loop.sh").read_text(encoding="utf-8")
    assert "## Main-Agent Status Snapshot" in text
    assert 'output+="- Source: ${source_label} ${issue_ref}${nl}"' not in text
    assert "| Task | Summary | Planned Status | PR | PR State | Review | Suggested |" in text
    assert "Merge State" not in text
