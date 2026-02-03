from __future__ import annotations

import json
import subprocess
from typing import Any

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script

ScriptSpec = dict[str, Any]


def test_validate_plans_passes_for_repo() -> None:
    repo = repo_root()
    script = "plan-tooling"
    spec: ScriptSpec = {
        "command": ["plan-tooling", "validate"],
        "args": [],
        "timeout_sec": 10,
        "expect": {"exit_codes": [0], "stdout_regex": r"\A\Z", "stderr_regex": r"\A\Z"},
    }
    result = run_smoke_script(script, "audit-plans-pass", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_validate_plans_fails_for_invalid_fixture() -> None:
    repo = repo_root()
    fixture = repo / "tests" / "fixtures" / "plan" / "invalid-plan.md"
    assert fixture.is_file()

    script = "plan-tooling"
    spec: ScriptSpec = {
        "command": ["plan-tooling", "validate", "--file", fixture.as_posix()],
        "args": [],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"missing Validation"},
    }
    result = run_smoke_script(script, "audit-plans-fail", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_plan_to_json_emits_expected_schema() -> None:
    repo = repo_root()
    fixture = repo / "tests" / "fixtures" / "plan" / "valid-plan.md"
    assert fixture.is_file()

    proc = subprocess.run(
        ["plan-tooling", "to-json", "--file", fixture.as_posix()],
        cwd=str(repo),
        text=True,
        capture_output=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr

    data = json.loads(proc.stdout)
    assert "sprints" in data
    sprints = data["sprints"]
    assert isinstance(sprints, list) and len(sprints) == 1

    tasks = sprints[0]["tasks"]
    assert isinstance(tasks, list) and len(tasks) == 3
    assert {t["id"] for t in tasks} == {"Task 1.1", "Task 1.2", "Task 1.3"}


def test_plan_batches_computes_parallel_layers() -> None:
    repo = repo_root()
    fixture = repo / "tests" / "fixtures" / "plan" / "valid-plan.md"
    assert fixture.is_file()

    proc = subprocess.run(
        ["plan-tooling", "batches", "--file", fixture.as_posix(), "--sprint", "1"],
        cwd=str(repo),
        text=True,
        capture_output=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr

    data = json.loads(proc.stdout)
    assert data["batches"] == [["Task 1.1"], ["Task 1.2", "Task 1.3"]]
