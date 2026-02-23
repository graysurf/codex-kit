from __future__ import annotations

from pathlib import Path
from typing import Any

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script

ScriptSpec = dict[str, Any]


def test_validate_skill_contracts_passes_for_repo() -> None:
    repo = repo_root()
    script = "skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh"
    spec: ScriptSpec = {
        "args": [],
        "timeout_sec": 10,
        "expect": {"exit_codes": [0], "stdout_regex": r"\A\Z", "stderr_regex": r"\A\Z"},
    }
    result = run_smoke_script(script, "audit-skill-contracts-pass", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_validate_skill_contracts_fails_for_invalid_contract(tmp_path: Path) -> None:
    fixture = tmp_path / "bad-skill.md"
    fixture.write_text(
        "\n".join(
            [
                "# Fixture Skill",
                "",
                "## Contract",
                "",
                "Prereqs:",
                "- N/A",
                "",
                "Inputs:",
                "- N/A",
                "",
                "Outputs:",
                "- N/A",
                "",
                "Exit codes:",
                "- N/A",
                "",
                "# Missing Failure modes:",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    repo = repo_root()
    script = "skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh"
    spec: ScriptSpec = {
        "args": ["--file", str(fixture)],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"Failure modes"},
    }
    result = run_smoke_script(script, "audit-skill-contracts-fail", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_fix_shell_style_passes_for_repo() -> None:
    repo = repo_root()
    script = "scripts/fix-shell-style.zsh"
    spec: ScriptSpec = {
        "args": ["--check"],
        "timeout_sec": 10,
        "expect": {"exit_codes": [0], "stdout_regex": r"\A\Z", "stderr_regex": r"\A\Z"},
    }
    result = run_smoke_script(script, "audit-shell-style-pass", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result
