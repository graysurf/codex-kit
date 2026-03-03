from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

RULES_PATH = "docs/plans/artifacts/repo-refactor-ci-skills-docs/docs-freshness-rules.md"


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


def _write_repo_scaffold(fixture: Path) -> None:
    _write(
        fixture / "README.md",
        "\n".join(
            [
                "# Fixture README",
                "",
                "Commands:",
                "- `scripts/check.sh --all`",
                "- `$AGENT_HOME/scripts/test.sh -m script_smoke`",
                "",
            ]
        ),
    )
    _write(
        fixture / "DEVELOPMENT.md",
        "\n".join(
            [
                "# Fixture Development",
                "",
                "- `scripts/check.sh --all`",
                "",
            ]
        ),
    )
    _write(
        fixture / "scripts/check.sh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                "echo check",
                "",
            ]
        ),
    )
    _write(
        fixture / "scripts/test.sh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                "echo test",
                "",
            ]
        ),
    )


def _rules_text() -> str:
    return "\n".join(
        [
            "# Fixture docs freshness rules",
            "",
            "<!-- docs-freshness-audit:begin -->",
            "DOC|README.md",
            "DOC|DEVELOPMENT.md",
            "REQUIRED_COMMAND|scripts/check.sh --all",
            "REQUIRED_COMMAND|$AGENT_HOME/scripts/test.sh -m script_smoke",
            "REQUIRED_PATH|scripts/check.sh",
            "REQUIRED_PATH|scripts/test.sh",
            "<!-- docs-freshness-audit:end -->",
            "",
        ]
    )


def _prepare_fixture(tmp_path: Path) -> Path:
    repo = Path(__file__).resolve().parents[1]
    fixture = tmp_path / "fixture"
    fixture.mkdir(parents=True, exist_ok=True)

    _copy(repo, fixture, "scripts/ci/docs-freshness-audit.sh")
    _write_repo_scaffold(fixture)
    _write(fixture / RULES_PATH, _rules_text())

    subprocess.run(["git", "init"], cwd=str(fixture), check=True, text=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=str(fixture), check=True, text=True, capture_output=True)
    return fixture


@pytest.mark.script_regression
def test_docs_freshness_audit_passes_with_fresh_docs(tmp_path: Path) -> None:
    fixture = _prepare_fixture(tmp_path)
    proc = _run(["bash", "scripts/ci/docs-freshness-audit.sh", "--check"], fixture)
    output = _combined_output(proc)

    assert proc.returncode == 0, output
    assert "PASS [docs-freshness] docs freshness audit passed (check=1)" in output


@pytest.mark.script_regression
def test_docs_freshness_audit_fails_when_required_command_missing(tmp_path: Path) -> None:
    fixture = _prepare_fixture(tmp_path)
    _write(
        fixture / "README.md",
        "\n".join(
            [
                "# Fixture README",
                "",
                "- `$AGENT_HOME/scripts/test.sh -m script_smoke`",
                "",
            ]
        ),
    )
    _write(
        fixture / "DEVELOPMENT.md",
        "\n".join(
            [
                "# Fixture Development",
                "",
                "- no check command here",
                "",
            ]
        ),
    )

    proc = _run(["bash", "scripts/ci/docs-freshness-audit.sh", "--check"], fixture)
    output = _combined_output(proc)

    assert proc.returncode == 1, output
    assert "required command missing from scoped docs: scripts/check.sh --all" in output


@pytest.mark.script_regression
def test_docs_freshness_audit_fails_on_stale_path_reference(tmp_path: Path) -> None:
    fixture = _prepare_fixture(tmp_path)
    _write(
        fixture / "README.md",
        "\n".join(
            [
                "# Fixture README",
                "",
                "Commands:",
                "- `scripts/check.sh --all`",
                "- `$AGENT_HOME/scripts/test.sh -m script_smoke`",
                "- `scripts/ci/missing-audit.sh --check`",
                "",
            ]
        ),
    )

    proc = _run(["bash", "scripts/ci/docs-freshness-audit.sh", "--check"], fixture)
    output = _combined_output(proc)

    assert proc.returncode == 1, output
    assert "stale path reference: README.md" in output
    assert "scripts/ci/missing-audit.sh" in output
