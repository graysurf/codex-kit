from __future__ import annotations

import os
import re
import shlex
import subprocess
import time
from pathlib import Path
from typing import Any

import pytest

from .conftest import SCRIPT_RUN_RESULTS, ScriptRunResult, default_env, discover_scripts, load_script_specs, out_dir, repo_root


def parse_shebang(script_path: Path) -> list[str]:
    first = script_path.read_text("utf-8", errors="ignore").splitlines()[:1]
    if not first:
        return []
    line = first[0].strip()
    if not line.startswith("#!"):
        return []

    tokens = shlex.split(line[2:].strip())
    if not tokens:
        return []

    if Path(tokens[0]).name == "env":
        tokens = tokens[1:]
        if tokens[:1] == ["-S"]:
            tokens = tokens[1:]

    return tokens


def write_logs(script: str, stdout: str, stderr: str) -> tuple[str, str]:
    logs_root = out_dir() / "logs"
    stdout_path = logs_root / f"{script}.stdout.txt"
    stderr_path = logs_root / f"{script}.stderr.txt"
    stdout_path.parent.mkdir(parents=True, exist_ok=True)
    stderr_path.parent.mkdir(parents=True, exist_ok=True)
    stdout_path.write_text(stdout, "utf-8")
    stderr_path.write_text(stderr, "utf-8")
    return (str(stdout_path), str(stderr_path))


def compile_optional_regex(pattern: str | None) -> re.Pattern[str] | None:
    if not pattern:
        return None
    return re.compile(pattern, re.MULTILINE)


def run_script(script: str, spec: dict[str, Any], repo: Path) -> ScriptRunResult:
    script_path = repo / script
    if not script_path.exists():
        raise FileNotFoundError(script)

    args = spec.get("args", ["--help"])
    if not isinstance(args, list) or not all(isinstance(x, str) for x in args):
        raise TypeError(f"spec.args must be a list of strings: {script}")

    timeout_sec = spec.get("timeout_sec", 5)
    if not isinstance(timeout_sec, (int, float)):
        raise TypeError(f"spec.timeout_sec must be a number: {script}")

    env = default_env(repo)
    extra_env = spec.get("env", {})
    if extra_env:
        if not isinstance(extra_env, dict):
            raise TypeError(f"spec.env must be a JSON object: {script}")
        for k, v in extra_env.items():
            if v is None:
                env.pop(str(k), None)
            else:
                env[str(k)] = str(v)

    shebang = parse_shebang(script_path)
    if not shebang:
        raise ValueError(f"missing shebang: {script}")

    argv = shebang + [str(script_path)] + list(args)

    expect = spec.get("expect", {})
    if expect and not isinstance(expect, dict):
        raise TypeError(f"spec.expect must be a JSON object: {script}")

    exit_codes = expect.get("exit_codes", [0])
    if not isinstance(exit_codes, list) or not all(isinstance(x, int) for x in exit_codes):
        raise TypeError(f"expect.exit_codes must be a list of ints: {script}")

    stdout_re = compile_optional_regex(expect.get("stdout_regex"))
    stderr_re = compile_optional_regex(expect.get("stderr_regex"))

    start = time.monotonic()
    try:
        completed = subprocess.run(
            argv,
            cwd=str(repo),
            env=env,
            text=True,
            capture_output=True,
            timeout=float(timeout_sec),
        )
        duration_ms = int((time.monotonic() - start) * 1000)
        stdout = completed.stdout
        stderr = completed.stderr
        stdout_path, stderr_path = write_logs(script, stdout, stderr)

        ok = completed.returncode in exit_codes
        note_parts: list[str] = []
        if completed.returncode not in exit_codes:
            note_parts.append(f"exit={completed.returncode} expected={exit_codes}")
        if stdout_re and not stdout_re.search(stdout):
            ok = False
            note_parts.append("stdout_regex_mismatch")
        if stderr_re and not stderr_re.search(stderr):
            ok = False
            note_parts.append("stderr_regex_mismatch")

        status = "pass" if ok else "fail"
        note = "; ".join(note_parts) if note_parts else None
        return ScriptRunResult(
            script=script,
            argv=argv,
            exit_code=completed.returncode,
            duration_ms=duration_ms,
            stdout_path=stdout_path,
            stderr_path=stderr_path,
            status=status,
            note=note,
        )
    except subprocess.TimeoutExpired:
        duration_ms = int((time.monotonic() - start) * 1000)
        stdout_path, stderr_path = write_logs(script, "", "")
        return ScriptRunResult(
            script=script,
            argv=argv,
            exit_code=124,
            duration_ms=duration_ms,
            stdout_path=stdout_path,
            stderr_path=stderr_path,
            status="fail",
            note=f"timeout after {timeout_sec}s",
        )


@pytest.mark.script_regression
@pytest.mark.parametrize("script", discover_scripts())
def test_script_regression(script: str):
    repo = repo_root()
    specs = load_script_specs(repo / "tests" / "script_specs")
    spec = specs.get(script, {})

    result = run_script(script, spec, repo)
    SCRIPT_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script regression failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )
