from __future__ import annotations

import re
from pathlib import Path

import pytest

REQUIRED_WORKFLOW_MODES = {
    "--lint-shell",
    "--lint-python",
    "--markdown",
    "--third-party",
    "--contracts",
    "--skills-layout",
    "--plans",
    "--env-bools",
    "--tests",
}

REQUIRED_CHECK_SCRIPT_MODES = REQUIRED_WORKFLOW_MODES | {
    "--lint",
    "--all",
}

LEGACY_PHASE_COMMAND_PATTERNS = {
    "scripts/lint.sh --shell": r"(?m)^\s*\$AGENT_HOME/scripts/lint\.sh --shell\s*$",
    "scripts/lint.sh --python": r"(?m)^\s*\$AGENT_HOME/scripts/lint\.sh --python\s*$",
    "scripts/ci/markdownlint-audit.sh --strict": r"(?m)^\s*\$AGENT_HOME/scripts/ci/markdownlint-audit\.sh --strict\s*$",
    "scripts/ci/third-party-artifacts-audit.sh --strict": r"(?m)^\s*\$AGENT_HOME/scripts/ci/third-party-artifacts-audit\.sh --strict\s*$",
    "zsh -f scripts/audit-env-bools.zsh --check": r"(?m)^\s*zsh -f \$AGENT_HOME/scripts/audit-env-bools\.zsh --check\s*$",
    "validate_skill_contracts.sh": r"(?m)^\s*\$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts\.sh\s*$",
    "audit-skill-layout.sh": r"(?m)^\s*\$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout\.sh\s*$",
    "scripts/test.sh": r"(?m)^\s*\$AGENT_HOME/scripts/test\.sh\s*$",
}

CHECK_COMMAND_PATTERN = re.compile(r"scripts/check\.sh(?P<args>[^\n\r]*)")
MODE_PATTERN = re.compile(r"--[a-z0-9-]+")


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (_repo_root() / path).read_text("utf-8")


def _collect_check_modes(workflow_text: str) -> set[str]:
    modes: set[str] = set()
    for match in CHECK_COMMAND_PATTERN.finditer(workflow_text):
        args = match.group("args")
        modes.update(MODE_PATTERN.findall(args))
    return modes


@pytest.mark.script_regression
def test_ci_check_parity_required_modes_defined_in_check_script() -> None:
    check_script = _read("scripts/check.sh")
    missing = sorted(mode for mode in REQUIRED_CHECK_SCRIPT_MODES if f"{mode})" not in check_script)
    assert not missing, f"scripts/check.sh missing modes: {missing}"


@pytest.mark.script_regression
def test_ci_check_parity_workflow_uses_required_check_modes() -> None:
    lint_workflow = _read(".github/workflows/lint.yml")
    workflow_modes = _collect_check_modes(lint_workflow)
    missing = sorted(REQUIRED_WORKFLOW_MODES - workflow_modes)
    assert not missing, f".github/workflows/lint.yml missing scripts/check.sh modes: {missing}"


@pytest.mark.script_regression
def test_ci_check_parity_workflow_removes_redundant_ad_hoc_phase_commands() -> None:
    lint_workflow = _read(".github/workflows/lint.yml")
    legacy_hits = [
        label
        for label, pattern in LEGACY_PHASE_COMMAND_PATTERNS.items()
        if re.search(pattern, lint_workflow)
    ]
    assert not legacy_hits, f"replace ad-hoc phase commands with scripts/check.sh modes: {legacy_hits}"
