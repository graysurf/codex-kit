from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


def write_executable(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, "utf-8")
    path.chmod(0o755)


@pytest.mark.script_smoke
def test_script_smoke_release_and_ci_specs_match_retained_entrypoints() -> None:
    repo = repo_root()

    expected_specs = [
        "tests/script_specs/skills/automation/gh-fix-ci/scripts/gh-fix-ci.sh.json",
        "tests/script_specs/skills/automation/gh-fix-ci/scripts/inspect_ci_checks.py.json",
        "tests/script_specs/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh.json",
        "tests/script_specs/skills/automation/release-workflow/scripts/release-resolve.sh.json",
    ]
    spec_roots = [
        repo / "tests" / "script_specs" / "skills" / "automation" / "gh-fix-ci" / "scripts",
        repo / "tests" / "script_specs" / "skills" / "automation" / "release-workflow" / "scripts",
    ]
    discovered_specs = sorted(
        str(path.relative_to(repo))
        for root in spec_roots
        for path in root.glob("*.json")
    )
    assert discovered_specs == expected_specs

    expected_scripts = [
        "skills/automation/gh-fix-ci/scripts/gh-fix-ci.sh",
        "skills/automation/gh-fix-ci/scripts/inspect_ci_checks.py",
        "skills/automation/release-workflow/scripts/release-publish-from-changelog.sh",
        "skills/automation/release-workflow/scripts/release-resolve.sh",
    ]
    for script_path in expected_scripts:
        assert (repo / script_path).is_file(), script_path

    expected_case_names = {
        "tests/script_specs/skills/automation/gh-fix-ci/scripts/gh-fix-ci.sh.json": {"help-surface"},
        "tests/script_specs/skills/automation/gh-fix-ci/scripts/inspect_ci_checks.py.json": {"help"},
        "tests/script_specs/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh.json": {
            "help-surface"
        },
        "tests/script_specs/skills/automation/release-workflow/scripts/release-resolve.sh.json": {"json-defaults"},
    }
    for spec_path, expected_names in expected_case_names.items():
        payload = json.loads((repo / spec_path).read_text("utf-8"))
        smoke_cases = payload.get("smoke", [])
        names = {case.get("name") for case in smoke_cases if isinstance(case, dict)}
        assert names == expected_names, spec_path


@pytest.mark.script_smoke
def test_script_smoke_release_publish_from_changelog(tmp_path: Path):
    work_dir = tmp_path / "release"
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
            ]
        )
        + "\n",
        "utf-8",
    )

    fixture_bin = tmp_path / "bin"
    write_executable(
        fixture_bin / "gh",
        "\n".join(
            [
                "#!/usr/bin/env bash",
                "set -euo pipefail",
                'state_dir="${GH_STUB_STATE_DIR:-.gh-state}"',
                "mkdir -p \"$state_dir\"",
                "",
                'if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then',
                "  exit 0",
                "fi",
                "",
                'if [[ "${1:-}" == "release" && "${2:-}" == "view" ]]; then',
                '  tag="${3:-}"',
                "  shift 3",
                '  state_file="${state_dir}/release-${tag}.body"',
                '  if [[ ! -f "$state_file" ]]; then',
                "    exit 1",
                "  fi",
                '  if [[ "${1:-}" == "--json" ]]; then',
                '    json="${2:-}"',
                "    shift 2",
                '    if [[ "$json" == "body" && "${1:-}" == "--jq" && "${2:-}" == ".body | length" ]]; then',
                "      wc -c <\"$state_file\" | tr -d '[:space:]'",
                "      exit 0",
                "    fi",
                '    if [[ "$json" == "url" && "${1:-}" == "--jq" && "${2:-}" == ".url" ]]; then',
                "      printf \"https://example.invalid/releases/tag/%s\\n\" \"$tag\"",
                "      exit 0",
                "    fi",
                "    exit 2",
                "  fi",
                "  printf \"title:\\t%s\\n\" \"$tag\"",
                "  exit 0",
                "fi",
                "",
                'if [[ "${1:-}" == "release" && "${2:-}" == "create" ]]; then',
                '  tag="${3:-}"',
                "  shift 3",
                "  notes_file=''",
                "  while [[ $# -gt 0 ]]; do",
                '    case "${1:-}" in',
                "      -F|--notes-file)",
                '        notes_file="${2:-}"',
                "        shift 2",
                "        ;;",
                "      --title|-t)",
                "        shift 2",
                "        ;;",
                "      *)",
                "        shift",
                "        ;;",
                "    esac",
                "  done",
                '  [[ -n "$notes_file" ]] || exit 2',
                "  cp \"$notes_file\" \"${state_dir}/release-${tag}.body\"",
                "  printf \"https://example.invalid/releases/tag/%s\\n\" \"$tag\"",
                "  exit 0",
                "fi",
                "",
                'if [[ "${1:-}" == "release" && "${2:-}" == "edit" ]]; then',
                '  tag="${3:-}"',
                "  shift 3",
                "  notes_file=''",
                "  while [[ $# -gt 0 ]]; do",
                '    case "${1:-}" in',
                "      --notes-file|-F)",
                '        notes_file="${2:-}"',
                "        shift 2",
                "        ;;",
                "      --title|-t)",
                "        shift 2",
                "        ;;",
                "      *)",
                "        shift",
                "        ;;",
                "    esac",
                "  done",
                '  [[ -n "$notes_file" ]] || exit 2',
                "  cp \"$notes_file\" \"${state_dir}/release-${tag}.body\"",
                "  printf \"https://example.invalid/releases/tag/%s\\n\" \"$tag\"",
                "  exit 0",
                "fi",
                "",
                "echo \"gh fixture: unsupported args: $*\" >&2",
                "exit 91",
                "",
            ]
        ),
    )

    repo = repo_root()
    stub_bin = repo / "tests" / "stubs" / "bin"
    system_path = os.environ.get("PATH", "")
    path = os.pathsep.join([str(fixture_bin), str(stub_bin), system_path])

    script = "skills/automation/release-workflow/scripts/release-publish-from-changelog.sh"
    spec = {
        "args": [
            "--repo",
            ".",
            "--version",
            version,
            "--changelog",
            "CHANGELOG.md",
            "--notes-output",
            "release-notes.md",
        ],
        "env": {"PATH": path, "GH_STUB_STATE_DIR": ".gh-state"},
        "timeout_sec": 10,
        "expect": {
            "exit_codes": [0],
            "stdout_regex": r"^https://example\.invalid/releases/tag/v1\.2\.3$",
        },
    }

    result = run_smoke_script(script, "release-publish", spec, repo, cwd=work_dir)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\\n"
        f"argv: {' '.join(result.argv)}\\n"
        f"stdout: {result.stdout_path}\\n"
        f"stderr: {result.stderr_path}\\n"
        f"note: {result.note or 'None'}"
    )

    out_path = work_dir / "release-notes.md"
    assert out_path.exists(), f"missing release notes output: {out_path}"
    out_text = out_path.read_text("utf-8")
    assert f"## {version} - " in out_text


@pytest.mark.script_smoke
def test_script_smoke_release_publish_keeps_existing_output_on_failure(tmp_path: Path):
    work_dir = tmp_path / "release"
    work_dir.mkdir(parents=True, exist_ok=True)

    changelog = work_dir / "CHANGELOG.md"
    changelog.write_text(
        "\n".join(
            [
                "# Changelog",
                "",
                "All notable changes to this project will be documented in this file.",
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

    out_path = work_dir / "release-notes.md"
    out_path.write_text("sentinel-old-content\n", "utf-8")

    repo = repo_root()
    script = "skills/automation/release-workflow/scripts/release-publish-from-changelog.sh"
    spec = {
        "args": [
            "--repo",
            ".",
            "--version",
            "v9.9.9",
            "--changelog",
            "CHANGELOG.md",
            "--notes-output",
            "release-notes.md",
        ],
        "timeout_sec": 10,
        "expect": {"exit_codes": [2], "stderr_regex": r"version section not found"},
    }

    result = run_smoke_script(script, "release-publish-missing-version", spec, repo, cwd=work_dir)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\\n"
        f"argv: {' '.join(result.argv)}\\n"
        f"stdout: {result.stdout_path}\\n"
        f"stderr: {result.stderr_path}\\n"
        f"note: {result.note or 'None'}"
    )

    assert out_path.read_text("utf-8") == "sentinel-old-content\n"
