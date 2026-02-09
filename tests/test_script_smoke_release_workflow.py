from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


def write_executable(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, "utf-8")
    path.chmod(0o755)


@pytest.mark.script_smoke
def test_script_smoke_release_notes_from_changelog(tmp_path: Path):
    work_dir = tmp_path / "changelog"
    work_dir.mkdir(parents=True, exist_ok=True)

    version = "v1.2.3"
    changelog = work_dir / "CHANGELOG.md"
    changelog.write_text(
        "\n".join(
            [
                "# Changelog",
                "",
                "All notable changes to this project will be documented in this file.",
                "",
                "## v1.2.3 - 2026-01-01",
                "",
                "### Added",
                "",
                "- Added a thing",
                "",
                "### Changed",
                "",
                "- Changed a thing",
                "",
                "### Fixed",
                "",
                "- Fixed a thing",
                "",
                "## v1.2.2 - 2025-12-31",
                "",
                "### Added",
                "",
                "- Older entry",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    repo = repo_root()
    script = "skills/automation/release-workflow/scripts/release-notes-from-changelog.sh"
    spec = {
        "args": ["--version", version, "--changelog", "CHANGELOG.md", "--output", "release-notes.md"],
        "timeout_sec": 10,
        "expect": {"exit_codes": [0], "stdout_regex": r"^release-notes\.md$"},
    }

    result = run_smoke_script(script, "release-notes", spec, repo, cwd=work_dir)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )

    out_path = work_dir / "release-notes.md"
    assert out_path.exists(), f"missing release notes output: {out_path}"
    out_text = out_path.read_text("utf-8")
    assert f"## {version} - " in out_text
    assert "## v1.2.2 - " not in out_text


@pytest.mark.script_smoke
def test_script_smoke_release_audit_strict(tmp_path: Path):
    work_tree = tmp_path / "repo"
    work_tree.mkdir(parents=True, exist_ok=True)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(work_tree), check=True, text=True, capture_output=True)

    run(["git", "init", "-b", "main"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])

    (work_tree / "README.md").write_text("fixture\n", "utf-8")

    changelog = work_tree / "CHANGELOG.md"
    changelog.write_text(
        "\n".join(
            [
                "# Changelog",
                "",
                "All notable changes to this project will be documented in this file.",
                "",
                "## v1.2.3 - 2026-01-01",
                "",
                "### Added",
                "",
                "- Added a thing",
                "",
                "### Changed",
                "",
                "- Changed a thing",
                "",
                "### Fixed",
                "",
                "- Fixed a thing",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    run(["git", "add", "README.md", "CHANGELOG.md"])
    run(["git", "commit", "-m", "init"])

    fixture_bin = tmp_path / "bin"
    write_executable(
        fixture_bin / "gh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                'if [[ \"${1:-}\" == \"auth\" && \"${2:-}\" == \"status\" ]]; then',
                "  exit 0",
                "fi",
                "echo \"warn: gh stub called with unsupported args: $*\" >&2",
                "exit 0",
                "",
            ]
        ),
    )

    repo = repo_root()
    stub_bin = repo / "tests" / "stubs" / "bin"
    system_path = os.environ.get("PATH", "")
    path = os.pathsep.join([str(fixture_bin), str(stub_bin), system_path])

    script = "skills/automation/release-workflow/scripts/release-audit.sh"
    spec = {
        "args": ["--repo", ".", "--branch", "main", "--changelog", "CHANGELOG.md", "--version", "v1.2.3", "--strict"],
        "env": {"PATH": path},
        "timeout_sec": 30,
        "expect": {"exit_codes": [0], "stdout_regex": r"ok: working tree clean"},
    }

    result = run_smoke_script(script, "release-audit", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )


@pytest.mark.script_smoke
def test_script_smoke_release_audit_strict_allow_dirty_changelog(tmp_path: Path):
    work_tree = tmp_path / "repo"
    work_tree.mkdir(parents=True, exist_ok=True)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(work_tree), check=True, text=True, capture_output=True)

    run(["git", "init", "-b", "main"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])

    (work_tree / "README.md").write_text("fixture\n", "utf-8")

    changelog = work_tree / "CHANGELOG.md"
    changelog.write_text(
        "\n".join(
            [
                "# Changelog",
                "",
                "All notable changes to this project will be documented in this file.",
                "",
                "## v1.2.3 - 2026-01-01",
                "",
                "### Added",
                "",
                "- Added a thing",
                "",
                "### Changed",
                "",
                "- Changed a thing",
                "",
                "### Fixed",
                "",
                "- Fixed a thing",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    run(["git", "add", "README.md", "CHANGELOG.md"])
    run(["git", "commit", "-m", "init"])

    changelog.write_text(
        changelog.read_text("utf-8").replace("- Fixed a thing", "- Fixed a thing (edited)", 1),
        "utf-8",
    )

    fixture_bin = tmp_path / "bin"
    write_executable(
        fixture_bin / "gh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                'if [[ \"${1:-}\" == \"auth\" && \"${2:-}\" == \"status\" ]]; then',
                "  exit 0",
                "fi",
                "echo \"warn: gh stub called with unsupported args: $*\" >&2",
                "exit 0",
                "",
            ]
        ),
    )

    repo = repo_root()
    stub_bin = repo / "tests" / "stubs" / "bin"
    system_path = os.environ.get("PATH", "")
    path = os.pathsep.join([str(fixture_bin), str(stub_bin), system_path])

    script = "skills/automation/release-workflow/scripts/release-audit.sh"
    spec = {
        "args": [
            "--repo",
            ".",
            "--branch",
            "main",
            "--changelog",
            "CHANGELOG.md",
            "--version",
            "v1.2.3",
            "--allow-dirty-path",
            "CHANGELOG.md",
            "--strict",
        ],
        "env": {"PATH": path},
        "timeout_sec": 30,
        "expect": {
            "exit_codes": [0],
            "stdout_regex": r"ok: working tree changes limited to allowed paths: CHANGELOG\.md",
        },
    }

    result = run_smoke_script(script, "release-audit-allow-dirty", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )


@pytest.mark.script_smoke
def test_script_smoke_release_audit_strict_allows_omitted_none_sections(tmp_path: Path):
    work_tree = tmp_path / "repo"
    work_tree.mkdir(parents=True, exist_ok=True)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(work_tree), check=True, text=True, capture_output=True)

    run(["git", "init", "-b", "main"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])

    (work_tree / "README.md").write_text("fixture\n", "utf-8")

    changelog = work_tree / "CHANGELOG.md"
    changelog.write_text(
        "\n".join(
            [
                "# Changelog",
                "",
                "All notable changes to this project will be documented in this file.",
                "",
                "## v1.2.3 - 2026-01-01",
                "",
                "### Fixed",
                "",
                "- Fixed a thing",
                "",
            ]
        )
        + "\n",
        "utf-8",
    )

    run(["git", "add", "README.md", "CHANGELOG.md"])
    run(["git", "commit", "-m", "init"])

    fixture_bin = tmp_path / "bin"
    write_executable(
        fixture_bin / "gh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                'if [[ \"${1:-}\" == \"auth\" && \"${2:-}\" == \"status\" ]]; then',
                "  exit 0",
                "fi",
                "echo \"warn: gh stub called with unsupported args: $*\" >&2",
                "exit 0",
                "",
            ]
        ),
    )

    repo = repo_root()
    stub_bin = repo / "tests" / "stubs" / "bin"
    system_path = os.environ.get("PATH", "")
    path = os.pathsep.join([str(fixture_bin), str(stub_bin), system_path])

    script = "skills/automation/release-workflow/scripts/release-audit.sh"
    spec = {
        "args": ["--repo", ".", "--branch", "main", "--changelog", "CHANGELOG.md", "--version", "v1.2.3", "--strict"],
        "env": {"PATH": path},
        "timeout_sec": 30,
        "expect": {"exit_codes": [0], "stdout_regex": r"ok: changelog entry exists: v1\.2\.3"},
    }

    result = run_smoke_script(script, "release-audit-omit-none-sections", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )
