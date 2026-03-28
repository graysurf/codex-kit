from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from .conftest import repo_root


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, check=False)


def _combined_output(proc: subprocess.CompletedProcess[str]) -> str:
    return f"{proc.stdout}\n{proc.stderr}"


def _copy(repo: Path, fixture: Path, rel: str) -> None:
    source = repo / rel
    target = fixture / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def _prepare_third_party_fixture(tmp_path: Path) -> Path:
    repo = repo_root()
    fixture = tmp_path / "fixture"
    fixture.mkdir(parents=True, exist_ok=True)

    required_files = [
        "scripts/generate-third-party-artifacts.sh",
        "scripts/ci/third-party-artifacts-audit.sh",
        "requirements-dev.txt",
        ".rumdl.toml",
        "scripts/ci/markdownlint-audit.sh",
        "skills/tools/browser/playwright/scripts/playwright_cli.sh",
        "skills/tools/browser/agent-browser/scripts/agent-browser.sh",
        "scripts/chrome-devtools-mcp.sh",
        "scripts/lint.sh",
        "scripts/install-homebrew-nils-cli.sh",
        ".github/workflows/lint.yml",
        "Dockerfile",
    ]

    for rel in required_files:
        _copy(repo, fixture, rel)

    subprocess.run(["git", "init"], cwd=str(fixture), check=True, text=True, capture_output=True)

    return fixture


def test_generate_third_party_artifacts_write_and_check(tmp_path: Path) -> None:
    fixture = _prepare_third_party_fixture(tmp_path)

    write_proc = _run(["bash", "scripts/generate-third-party-artifacts.sh", "--write"], fixture)
    write_output = _combined_output(write_proc)
    assert write_proc.returncode == 0, write_output
    assert "PASS [write] third-party artifacts generated" in write_output

    licenses_file = fixture / "THIRD_PARTY_LICENSES.md"
    notices_file = fixture / "THIRD_PARTY_NOTICES.md"

    assert licenses_file.is_file()
    assert notices_file.is_file()

    check_proc = _run(["bash", "scripts/generate-third-party-artifacts.sh", "--check"], fixture)
    check_output = _combined_output(check_proc)
    assert check_proc.returncode == 0, check_output
    assert "PASS [check] third-party artifacts are up to date" in check_output

    licenses_text = licenses_file.read_text("utf-8")
    notices_text = notices_file.read_text("utf-8")

    assert "# THIRD_PARTY_LICENSES" in licenses_text
    assert "chrome-devtools-mcp" in licenses_text
    assert "# THIRD_PARTY_NOTICES" in notices_text
    assert "Component Notice References" in notices_text


def test_third_party_artifacts_audit_strict_and_warning_modes(tmp_path: Path) -> None:
    fixture = _prepare_third_party_fixture(tmp_path)

    seed_proc = _run(["bash", "scripts/generate-third-party-artifacts.sh", "--write"], fixture)
    assert seed_proc.returncode == 0, _combined_output(seed_proc)

    strict_clean_proc = _run(["bash", "scripts/ci/third-party-artifacts-audit.sh", "--strict"], fixture)
    strict_clean_output = _combined_output(strict_clean_proc)
    assert strict_clean_proc.returncode == 0, strict_clean_output
    assert "PASS [third-party-artifacts] third-party artifact audit passed (strict=1)" in strict_clean_output

    licenses_file = fixture / "THIRD_PARTY_LICENSES.md"
    licenses_file.write_text(licenses_file.read_text("utf-8") + "\n<!-- drift marker -->\n", "utf-8")

    warning_proc = _run(["bash", "scripts/ci/third-party-artifacts-audit.sh"], fixture)
    warning_output = _combined_output(warning_proc)
    assert warning_proc.returncode == 0, warning_output
    assert "WARN [third-party-artifacts] artifact drift detected" in warning_output

    strict_fail_proc = _run(["bash", "scripts/ci/third-party-artifacts-audit.sh", "--strict"], fixture)
    strict_fail_output = _combined_output(strict_fail_proc)
    assert strict_fail_proc.returncode == 1, strict_fail_output
    assert "FAIL [third-party-artifacts] strict mode treats warnings as failures" in strict_fail_output
