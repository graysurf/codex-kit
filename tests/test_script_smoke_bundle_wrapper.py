from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, default_smoke_env, repo_root
from .test_script_smoke import run_smoke_script


def write_executable(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, "utf-8")
    path.chmod(0o755)


@pytest.mark.script_smoke
def test_script_smoke_bundle_wrapper_embeds_sources_and_tools(tmp_path: Path):
    zdotdir = tmp_path / "zdotdir"
    scripts_dir = zdotdir / "scripts"

    write_executable(
        scripts_dir / "lib" / "hello.zsh",
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                "",
                "hello_main() {",
                '  print -r -- "hello-main"',
                '  echo-tool "arg1"',
                "}",
                "",
            ]
        ),
    )

    write_executable(
        zdotdir / "tools" / "echo-tool.zsh",
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                'print -r -- "tool:${1-}"',
                "",
            ]
        ),
    )

    wrapper = tmp_path / "wrapper.zsh"
    wrapper.write_text(
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                'typeset -a sources=(',
                '  "lib/hello.zsh"',
                ")",
                'typeset -a exec_sources=(',
                '  "tools/echo-tool.zsh"',
                ")",
                "",
            ]
        ),
        "utf-8",
    )

    output = tmp_path / "out" / "bundled.zsh"

    repo = repo_root()
    script = "scripts/build/bundle-wrapper.zsh"
    spec = {
        "args": ["--input", "wrapper.zsh", "--output", str(output), "--entry", "hello_main"],
        "env": {
            "ZDOTDIR": str(zdotdir),
            "ZSH_CONFIG_DIR": str(zdotdir / "config"),
            "ZSH_BOOTSTRAP_SCRIPT_DIR": str(zdotdir / "bootstrap"),
            "ZSH_SCRIPT_DIR": str(zdotdir / "scripts"),
        },
        "timeout_sec": 20,
        "expect": {"exit_codes": [0]},
    }

    result = run_smoke_script(script, "bundle-wrapper", spec, repo, cwd=tmp_path)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )

    assert output.exists(), f"missing bundle output: {output}"
    assert output.stat().st_mode & 0o111, f"bundle output is not executable: {output}"

    env = default_smoke_env(repo)
    env["ZDOTDIR"] = str(zdotdir)
    env["ZSH_CONFIG_DIR"] = str(zdotdir / "config")
    env["ZSH_BOOTSTRAP_SCRIPT_DIR"] = str(zdotdir / "bootstrap")
    env["ZSH_SCRIPT_DIR"] = str(zdotdir / "scripts")

    completed = subprocess.run(
        [str(output)],
        cwd=str(tmp_path),
        env=env,
        text=True,
        capture_output=True,
        timeout=10,
        check=False,
    )
    assert completed.returncode == 0, f"bundled wrapper failed: rc={completed.returncode}\nstderr={completed.stderr}"
    assert "hello-main" in completed.stdout
    assert "tool:arg1" in completed.stdout


@pytest.mark.script_smoke
def test_script_smoke_bundle_wrapper_parses_single_line_arrays(tmp_path: Path):
    zdotdir = tmp_path / "zdotdir"
    scripts_dir = zdotdir / "scripts"

    write_executable(
        scripts_dir / "lib" / "hello.zsh",
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                "",
                "hello_main() {",
                '  print -r -- "hello-main"',
                '  echo-tool "arg1"',
                "}",
                "",
            ]
        ),
    )

    write_executable(
        zdotdir / "tools" / "echo-tool.zsh",
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                'print -r -- "tool:${1-}"',
                "",
            ]
        ),
    )

    wrapper = tmp_path / "wrapper.zsh"
    wrapper.write_text(
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                'typeset -a sources=("lib/hello.zsh")',
                'typeset -a exec_sources=("tools/echo-tool.zsh")',
                "",
            ]
        ),
        "utf-8",
    )

    output = tmp_path / "out" / "bundled.zsh"

    repo = repo_root()
    script = "scripts/build/bundle-wrapper.zsh"
    spec = {
        "args": ["--input", "wrapper.zsh", "--output", str(output), "--entry", "hello_main"],
        "env": {
            "ZDOTDIR": str(zdotdir),
            "ZSH_CONFIG_DIR": str(zdotdir / "config"),
            "ZSH_BOOTSTRAP_SCRIPT_DIR": str(zdotdir / "bootstrap"),
            "ZSH_SCRIPT_DIR": str(zdotdir / "scripts"),
        },
        "timeout_sec": 20,
        "expect": {"exit_codes": [0]},
    }

    result = run_smoke_script(script, "bundle-wrapper-single-line", spec, repo, cwd=tmp_path)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )

    assert output.exists(), f"missing bundle output: {output}"
    assert output.stat().st_mode & 0o111, f"bundle output is not executable: {output}"

    env = default_smoke_env(repo)
    env["ZDOTDIR"] = str(zdotdir)
    env["ZSH_CONFIG_DIR"] = str(zdotdir / "config")
    env["ZSH_BOOTSTRAP_SCRIPT_DIR"] = str(zdotdir / "bootstrap")
    env["ZSH_SCRIPT_DIR"] = str(zdotdir / "scripts")

    completed = subprocess.run(
        [str(output)],
        cwd=str(tmp_path),
        env=env,
        text=True,
        capture_output=True,
        timeout=10,
        check=False,
    )
    assert completed.returncode == 0, f"bundled wrapper failed: rc={completed.returncode}\nstderr={completed.stderr}"
    assert "hello-main" in completed.stdout
    assert "tool:arg1" in completed.stdout


@pytest.mark.script_smoke
def test_script_smoke_bundle_wrapper_parses_unquoted_arrays(tmp_path: Path):
    zdotdir = tmp_path / "zdotdir"
    scripts_dir = zdotdir / "scripts"

    write_executable(
        scripts_dir / "lib" / "hello.zsh",
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                "",
                "hello_main() {",
                '  print -r -- "hello-main"',
                '  echo-tool "arg1"',
                "}",
                "",
            ]
        ),
    )

    write_executable(
        zdotdir / "tools" / "echo-tool.zsh",
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                'print -r -- "tool:${1-}"',
                "",
            ]
        ),
    )

    wrapper = tmp_path / "wrapper.zsh"
    wrapper.write_text(
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                "typeset -a sources=(lib/hello.zsh)",
                "typeset -a exec_sources=(tools/echo-tool.zsh)",
                "",
            ]
        ),
        "utf-8",
    )

    output = tmp_path / "out" / "bundled.zsh"

    repo = repo_root()
    script = "scripts/build/bundle-wrapper.zsh"
    spec = {
        "args": ["--input", "wrapper.zsh", "--output", str(output), "--entry", "hello_main"],
        "env": {
            "ZDOTDIR": str(zdotdir),
            "ZSH_CONFIG_DIR": str(zdotdir / "config"),
            "ZSH_BOOTSTRAP_SCRIPT_DIR": str(zdotdir / "bootstrap"),
            "ZSH_SCRIPT_DIR": str(zdotdir / "scripts"),
        },
        "timeout_sec": 20,
        "expect": {"exit_codes": [0]},
    }

    result = run_smoke_script(script, "bundle-wrapper-unquoted", spec, repo, cwd=tmp_path)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )

    assert output.exists(), f"missing bundle output: {output}"
    assert output.stat().st_mode & 0o111, f"bundle output is not executable: {output}"

    env = default_smoke_env(repo)
    env["ZDOTDIR"] = str(zdotdir)
    env["ZSH_CONFIG_DIR"] = str(zdotdir / "config")
    env["ZSH_BOOTSTRAP_SCRIPT_DIR"] = str(zdotdir / "bootstrap")
    env["ZSH_SCRIPT_DIR"] = str(zdotdir / "scripts")

    completed = subprocess.run(
        [str(output)],
        cwd=str(tmp_path),
        env=env,
        text=True,
        capture_output=True,
        timeout=10,
        check=False,
    )
    assert completed.returncode == 0, f"bundled wrapper failed: rc={completed.returncode}\nstderr={completed.stderr}"
    assert "hello-main" in completed.stdout
    assert "tool:arg1" in completed.stdout


@pytest.mark.script_smoke
def test_script_smoke_bundle_wrapper_copies_bundled_input(tmp_path: Path):
    home_dir = tmp_path / "home"
    home_dir.mkdir(parents=True, exist_ok=True)

    input_path = home_dir / "wrapper.zsh"
    write_executable(
        input_path,
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                "set -e",
                "",
                "# Bundled from: /tmp/old-source",
                "# --- BEGIN fake.zsh",
                "hello_main() {",
                '  print -r -- "hello-main"',
                "}",
                "# --- END fake.zsh",
                "",
                'if ! typeset -f hello_main >/dev/null 2>&1; then',
                '  print -u2 -r -- "❌ missing function: hello_main"',
                "  exit 1",
                "fi",
                "",
                'hello_main "$@"',
                "",
            ]
        ),
    )

    output = tmp_path / "out" / "bundled.zsh"

    repo = repo_root()
    script = "scripts/build/bundle-wrapper.zsh"
    spec = {
        "args": ["--input", str(input_path), "--output", str(output), "--entry", "hello_main"],
        "env": {"HOME": str(home_dir)},
        "timeout_sec": 20,
        "expect": {"exit_codes": [0]},
    }

    result = run_smoke_script(script, "bundle-wrapper-copy", spec, repo, cwd=tmp_path)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )

    assert output.exists(), f"missing bundle output: {output}"
    assert output.stat().st_mode & 0o111, f"bundle output is not executable: {output}"

    out_text = output.read_text("utf-8")
    assert "# Bundled from: $HOME/wrapper.zsh" in out_text

    env = default_smoke_env(repo)
    env["HOME"] = str(home_dir)
    completed = subprocess.run(
        [str(output)],
        cwd=str(tmp_path),
        env=env,
        text=True,
        capture_output=True,
        timeout=10,
        check=False,
    )
    assert completed.returncode == 0, f"bundled wrapper failed: rc={completed.returncode}\nstderr={completed.stderr}"
    assert "hello-main" in completed.stdout
