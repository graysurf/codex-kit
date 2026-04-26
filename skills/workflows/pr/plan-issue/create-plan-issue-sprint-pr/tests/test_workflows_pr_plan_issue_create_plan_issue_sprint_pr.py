from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_workflows_pr_plan_issue_create_plan_issue_sprint_pr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_pr_plan_issue_create_plan_issue_sprint_pr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/create-plan-issue-sprint-pr.sh"])


def test_create_mode_runs_gh_followups_in_dispatch_worktree_without_repo_slug() -> None:
    script = Path(__file__).resolve().parents[1] / "scripts" / "create-plan-issue-sprint-pr.sh"
    text = script.read_text(encoding="utf-8")
    assert '(cd "$worktree" && gh pr view "$branch" --json number --jq .number)' in text
    assert '(cd "$worktree" && gh pr ready "$pr_number" >/dev/null)' in text
    assert '(cd "$worktree" && gh pr view "$pr_number" --json url --jq .url)' in text


def _run_entrypoint(*args: str) -> subprocess.CompletedProcess[str]:
    script = Path(__file__).resolve().parents[1] / "scripts" / "create-plan-issue-sprint-pr.sh"
    return subprocess.run(
        [str(script), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def test_render_body_only_uses_dispatch_record(tmp_path: Path) -> None:
    dispatch = tmp_path / "dispatch-S2T3.json"
    dispatch.write_text(
        json.dumps(
            {
                "task_id": "S2T3",
                "task_ids": ["S2T3", "S2T4"],
                "branch": "issue-12-s2-storage",
                "base_branch": "plan/issue-12",
                "worktree_abs_path": str(tmp_path / "worktree"),
            }
        ),
        encoding="utf-8",
    )

    result = _run_entrypoint(
        "--dispatch-record",
        str(dispatch),
        "--issue",
        "12",
        "--summary",
        "Sprint 2 completes the storage lane.",
        "--scope",
        "src/storage/: implements S2T3 and S2T4.",
        "--testing",
        "scripts/check.sh --tests -- -k storage (pass)",
        "--body-only",
    )

    assert result.returncode == 0, result.stderr
    assert "## Summary" in result.stdout
    assert "## Scope" in result.stdout
    assert "Sprint 2 task IDs: S2T3, S2T4." in result.stdout
    assert "- #12" in result.stdout


def test_renderer_rejects_placeholders(tmp_path: Path) -> None:
    dispatch = tmp_path / "dispatch-S1T1.json"
    dispatch.write_text(
        json.dumps(
            {
                "task_id": "S1T1",
                "branch": "issue-9-s1",
                "base_branch": "plan/issue-9",
                "worktree_abs_path": str(tmp_path / "worktree"),
            }
        ),
        encoding="utf-8",
    )

    result = _run_entrypoint(
        "--dispatch-record",
        str(dispatch),
        "--issue",
        "9",
        "--summary",
        "TODO: fill this later.",
        "--scope",
        "src/app.py: implements S1T1.",
        "--testing",
        "scripts/check.sh --tests (pass)",
        "--body-only",
    )

    assert result.returncode == 2
    assert "TODO" in result.stderr


def test_render_module_prints_dispatch_facts(tmp_path: Path) -> None:
    skill_root = Path(__file__).resolve().parents[1]
    renderer = skill_root / "assets" / "render_pr_body.py"
    dispatch = tmp_path / "dispatch-S3T1.json"
    dispatch.write_text(
        json.dumps(
            {
                "task_id": "S3T1",
                "branch": "issue-4-s3",
                "base_branch": "plan/issue-4",
                "worktree_abs_path": "/abs/worktree",
            }
        ),
        encoding="utf-8",
    )

    result = subprocess.run(
        [sys.executable, str(renderer), "--dispatch-record", str(dispatch), "--print-dispatch"],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    facts = json.loads(result.stdout)
    assert facts["task_ids"] == ["S3T1"]
    assert facts["sprint_number"] == 3
