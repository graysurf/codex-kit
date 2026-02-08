from __future__ import annotations

import os
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def _skill_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _script_path() -> Path:
    return _skill_root() / "scripts" / "playwright_cli.sh"


def _run_wrapper(args: list[str], *, cwd: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", str(_script_path()), *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        env=env,
    )


def _install_fake_npx(tmp_path: Path) -> tuple[Path, Path]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    args_log = tmp_path / "npx-args.log"
    fake_npx = bin_dir / "npx"
    fake_npx.write_text(
        "\n".join(
            [
                "#!/bin/bash",
                "set -euo pipefail",
                ': "${NPX_ARGS_LOG:?NPX_ARGS_LOG is required}"',
                'printf "%s\\n" "$@" > "$NPX_ARGS_LOG"',
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    fake_npx.chmod(0o755)
    return bin_dir, args_log


def test_tools_browser_playwright_contract() -> None:
    assert_skill_contract(_skill_root())


def test_tools_browser_playwright_entrypoints_exist() -> None:
    assert_entrypoints_exist(_skill_root(), ["scripts/playwright_cli.sh"])


def test_tools_browser_playwright_help_is_local(tmp_path: Path) -> None:
    env = os.environ.copy()
    env["PATH"] = "/nonexistent"
    env.pop("PLAYWRIGHT_CLI_SESSION", None)
    proc = _run_wrapper(["--help"], cwd=tmp_path, env=env)
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    haystack = (proc.stdout + proc.stderr).lower()
    assert "playwright cli wrapper" in haystack
    assert "usage:" in haystack


def test_tools_browser_playwright_missing_npx_error(tmp_path: Path) -> None:
    env = os.environ.copy()
    env["PATH"] = "/nonexistent"
    env.pop("PLAYWRIGHT_CLI_SESSION", None)
    proc = _run_wrapper(["open", "https://example.com"], cwd=tmp_path, env=env)
    assert proc.returncode == 1, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert "npx is required but not found on path." in proc.stderr.lower()


def test_tools_browser_playwright_session_injection_is_deterministic(tmp_path: Path) -> None:
    bin_dir, args_log = _install_fake_npx(tmp_path)
    env = os.environ.copy()
    env["PATH"] = str(bin_dir)
    env["NPX_ARGS_LOG"] = str(args_log)
    env["PLAYWRIGHT_CLI_SESSION"] = "ci"
    proc = _run_wrapper(["open", "https://example.com"], cwd=tmp_path, env=env)
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert args_log.read_text(encoding="utf-8").splitlines() == [
        "--yes",
        "--package",
        "@playwright/cli@latest",
        "playwright-cli",
        "--session",
        "ci",
        "open",
        "https://example.com",
    ]


def test_tools_browser_playwright_session_flag_wins_over_env(tmp_path: Path) -> None:
    bin_dir, args_log = _install_fake_npx(tmp_path)
    env = os.environ.copy()
    env["PATH"] = str(bin_dir)
    env["NPX_ARGS_LOG"] = str(args_log)
    env["PLAYWRIGHT_CLI_SESSION"] = "ci"
    proc = _run_wrapper(["--session=manual", "open", "https://example.com"], cwd=tmp_path, env=env)
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert args_log.read_text(encoding="utf-8").splitlines() == [
        "--yes",
        "--package",
        "@playwright/cli@latest",
        "playwright-cli",
        "--session=manual",
        "open",
        "https://example.com",
    ]
