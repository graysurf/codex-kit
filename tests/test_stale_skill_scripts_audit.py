from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, check=False)


def _combined_output(proc: subprocess.CompletedProcess[str]) -> str:
    return f"{proc.stdout}\n{proc.stderr}"


def _copy(repo: Path, fixture: Path, rel: str) -> None:
    source = repo / rel
    target = fixture / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, "utf-8")


def _prepare_fixture(tmp_path: Path, *, include_stale: bool) -> Path:
    repo = Path(__file__).resolve().parents[1]
    fixture = tmp_path / "fixture"
    fixture.mkdir(parents=True, exist_ok=True)

    _copy(repo, fixture, "scripts/ci/stale-skill-scripts-audit.sh")

    _write(
        fixture / "skills/tools/demo/SKILL.md",
        "\n".join(
            [
                "# Demo Skill",
                "",
                "Use this entrypoint:",
                "- `scripts/active.sh`",
                "",
            ]
        ),
    )
    _write(
        fixture / "skills/tools/demo/tests/test_tools_demo.py",
        "\n".join(
            [
                "from skills._shared.python.skill_testing import assert_entrypoints_exist",
                "",
                "",
                "def test_entrypoints() -> None:",
                "    assert_entrypoints_exist(None, [\"scripts/active.sh\"])",
                "",
            ]
        ),
    )
    _write(
        fixture / "skills/tools/demo/scripts/active.sh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                "echo active",
                "",
            ]
        ),
    )
    _write(
        fixture / "tests/script_specs/skills/tools/demo/scripts/active.sh.json",
        "{\n  \"smoke\": []\n}\n",
    )

    if include_stale:
        _write(
            fixture / "skills/tools/demo/scripts/stale.sh",
            "\n".join(
                [
                    "#!/usr/bin/env bash",
                    "set -euo pipefail",
                    "echo stale",
                    "",
                ]
            ),
        )

    subprocess.run(["git", "init"], cwd=str(fixture), check=True, text=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=str(fixture), check=True, text=True, capture_output=True)
    return fixture


@pytest.mark.script_regression
def test_stale_skill_scripts_audit_detects_removable_scripts(tmp_path: Path) -> None:
    fixture = _prepare_fixture(tmp_path, include_stale=True)
    proc = _run(["bash", "scripts/ci/stale-skill-scripts-audit.sh", "--check"], fixture)
    output = _combined_output(proc)

    assert proc.returncode == 1, output
    assert "ACTIVE\tskills/tools/demo/scripts/active.sh" in output
    assert "REMOVABLE\tskills/tools/demo/scripts/stale.sh" in output
    assert "FAIL [stale-skill-scripts] remove or justify removable scripts before merge" in output


@pytest.mark.script_regression
def test_stale_skill_scripts_audit_passes_without_removable_scripts(tmp_path: Path) -> None:
    fixture = _prepare_fixture(tmp_path, include_stale=False)
    proc = _run(["bash", "scripts/ci/stale-skill-scripts-audit.sh", "--check"], fixture)
    output = _combined_output(proc)

    assert proc.returncode == 0, output
    assert "ACTIVE\tskills/tools/demo/scripts/active.sh" in output
    assert "SUMMARY\tactive=1\ttransitional=0\tremovable=0" in output
    assert "PASS [stale-skill-scripts] stale-skill-scripts audit complete (check=1)" in output
