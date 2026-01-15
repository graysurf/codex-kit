from __future__ import annotations

from pathlib import Path
from typing import Any

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script

ScriptSpec = dict[str, Any]


def test_validate_skill_contracts_passes_for_repo():
    repo = repo_root()
    script = "scripts/validate_skill_contracts.sh"
    spec: ScriptSpec = {
        "args": [],
        "timeout_sec": 10,
        "expect": {"exit_codes": [0], "stdout_regex": r"\A\Z", "stderr_regex": r"\A\Z"},
    }
    result = run_smoke_script(script, "audit-skill-contracts-pass", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_validate_skill_contracts_fails_for_invalid_contract(tmp_path: Path):
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
    script = "scripts/validate_skill_contracts.sh"
    spec: ScriptSpec = {
        "args": ["--file", str(fixture)],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"Failure modes"},
    }
    result = run_smoke_script(script, "audit-skill-contracts-fail", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_validate_progress_index_passes_for_repo():
    repo = repo_root()
    script = repo / "skills" / "workflows" / "pr" / "progress" / "create-progress-pr" / "scripts" / "validate_progress_index.sh"
    spec: ScriptSpec = {
        "args": [],
        "timeout_sec": 10,
        "expect": {"exit_codes": [0], "stdout_regex": r"\A\Z", "stderr_regex": r"\A\Z"},
    }
    result = run_smoke_script(script.relative_to(repo).as_posix(), "audit-progress-index-pass", spec, repo, cwd=repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result


def test_fix_shell_style_passes_for_repo():
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


def test_validate_progress_index_fails_for_invalid_pr_cell(tmp_path: Path):
    repo = repo_root()
    original = repo / "docs" / "progress" / "README.md"
    mutated = tmp_path / "progress-readme.md"
    mutated.write_text(original.read_text("utf-8"), "utf-8")

    lines = mutated.read_text("utf-8").splitlines()
    try:
        in_progress_idx = next(i for i, line in enumerate(lines) if line.strip() == "## In progress")
        archived_idx = next(i for i, line in enumerate(lines) if line.strip() == "## Archived")
    except StopIteration as exc:
        raise AssertionError("docs/progress/README.md missing required headings") from exc

    in_sep = None
    for i in range(in_progress_idx, archived_idx):
        if lines[i].startswith("| ---"):
            in_sep = i
            break

    assert in_sep is not None, "docs/progress/README.md missing In progress table separator"

    mutated_row_idx = None
    for i in range(in_sep + 1, archived_idx):
        if not lines[i].startswith("|") or lines[i].startswith("| ---"):
            continue
        parts = [p.strip() for p in lines[i].strip().strip("|").split("|")]
        if len(parts) == 3:
            mutated_row_idx = i
            break

    if mutated_row_idx is None:
        lines.insert(in_sep + 1, "| 2099-01-01 | Fixture | NOT_A_LINK |")
    else:
        parts = [p.strip() for p in lines[mutated_row_idx].strip().strip("|").split("|")]
        parts[2] = "NOT_A_LINK"
        lines[mutated_row_idx] = f"| {parts[0]} | {parts[1]} | {parts[2]} |"

    mutated.write_text("\n".join(lines).rstrip() + "\n", "utf-8")

    script = repo / "skills" / "workflows" / "pr" / "progress" / "create-progress-pr" / "scripts" / "validate_progress_index.sh"
    spec: ScriptSpec = {
        "args": ["--file", str(mutated)],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"invalid PR cell"},
    }
    result = run_smoke_script(
        script.relative_to(repo).as_posix(),
        "audit-progress-index-fail",
        spec,
        repo,
        cwd=repo,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result
