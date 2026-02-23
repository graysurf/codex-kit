from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_pr_bug_deliver_bug_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_bug_deliver_bug_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/deliver-bug-pr.sh"])


def _skill_md_text() -> str:
    return (Path(__file__).resolve().parents[1] / "SKILL.md").read_text(encoding="utf-8")


def test_deliver_bug_pr_skill_requires_end_to_end_completion() -> None:
    text = _skill_md_text()
    assert "If there is no blocking error, this workflow must run end-to-end through `close`." in text
    assert "create-only is not a successful delivery outcome." in text


def test_deliver_bug_pr_skill_disallows_partial_handoff_success_language() -> None:
    text = _skill_md_text()
    assert "Do not stop after create/open PR and report \"next step is wait-ci/close\"." in text
    assert "When stopping before `close`, report status as `BLOCKED` or `FAILED`" in text


def test_deliver_bug_pr_skill_routes_draft_handling_to_auto_ready_close_flow() -> None:
    text = _skill_md_text()
    assert "if draft, auto-mark ready first, then merge PR and clean branches." in text
    assert "handling draft-state PRs (draft is resolved by auto-ready in close flow, not by bypass)" in text
