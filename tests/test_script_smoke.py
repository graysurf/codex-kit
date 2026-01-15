from __future__ import annotations

import re
import shlex
import subprocess
import time
from pathlib import Path
from typing import Any

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, ScriptRunResult, default_smoke_env, load_script_specs, out_dir_smoke, repo_root


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


def write_logs(script: str, case: str, stdout: str, stderr: str) -> tuple[str, str]:
    logs_root = out_dir_smoke() / "logs"
    suffix = f".{case}" if case else ""
    stdout_path = logs_root / f"{script}{suffix}.stdout.txt"
    stderr_path = logs_root / f"{script}{suffix}.stderr.txt"
    stdout_path.parent.mkdir(parents=True, exist_ok=True)
    stderr_path.parent.mkdir(parents=True, exist_ok=True)
    stdout_path.write_text(stdout, "utf-8")
    stderr_path.write_text(stderr, "utf-8")
    return (str(stdout_path), str(stderr_path))


def compile_optional_regex(pattern: str | None) -> re.Pattern[str] | None:
    if not pattern:
        return None
    return re.compile(pattern, re.MULTILINE)


def run_smoke_script(
    script: str,
    case: str,
    spec: dict[str, Any],
    repo: Path,
    *,
    cwd: Path | None = None,
) -> ScriptRunResult:
    script_path = repo / script
    if not script_path.exists():
        raise FileNotFoundError(script)

    args = spec.get("args", [])
    if not isinstance(args, list) or not all(isinstance(x, str) for x in args):
        raise TypeError(f"spec.args must be a list of strings: {script} ({case})")

    command = spec.get("command")
    if command is not None:
        if not isinstance(command, list) or not command or not all(isinstance(x, str) for x in command):
            raise TypeError(f"spec.command must be a non-empty list of strings: {script} ({case})")
        if args:
            raise TypeError(f"spec.args must be empty when spec.command is set: {script} ({case})")

    timeout_sec = spec.get("timeout_sec", 10)
    if not isinstance(timeout_sec, (int, float)):
        raise TypeError(f"spec.timeout_sec must be a number: {script} ({case})")

    env = default_smoke_env(repo)
    extra_env = spec.get("env", {})
    if extra_env:
        if not isinstance(extra_env, dict):
            raise TypeError(f"spec.env must be a JSON object: {script} ({case})")
        for key, value in extra_env.items():
            if value is None:
                env.pop(str(key), None)
            else:
                env[str(key)] = str(value)

    if command is not None:
        argv = list(command)
    else:
        shebang = parse_shebang(script_path)
        if not shebang:
            raise ValueError(f"missing shebang: {script}")
        argv = shebang + [str(script_path)] + list(args)

    expect = spec.get("expect", {})
    if expect and not isinstance(expect, dict):
        raise TypeError(f"spec.expect must be a JSON object: {script} ({case})")

    exit_codes = expect.get("exit_codes", [0])
    if not isinstance(exit_codes, list) or not all(isinstance(x, int) for x in exit_codes):
        raise TypeError(f"expect.exit_codes must be a list of ints: {script} ({case})")

    stdout_re = compile_optional_regex(expect.get("stdout_regex"))
    stderr_re = compile_optional_regex(expect.get("stderr_regex"))

    start = time.monotonic()
    try:
        completed = subprocess.run(
            argv,
            cwd=str(cwd or repo),
            env=env,
            text=True,
            capture_output=True,
            timeout=float(timeout_sec),
        )
        duration_ms = int((time.monotonic() - start) * 1000)
        stdout = completed.stdout
        stderr = completed.stderr
        stdout_path, stderr_path = write_logs(script, case, stdout, stderr)

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
            case=case,
        )
    except subprocess.TimeoutExpired:
        duration_ms = int((time.monotonic() - start) * 1000)
        stdout_path, stderr_path = write_logs(script, case, "", "")
        return ScriptRunResult(
            script=script,
            argv=argv,
            exit_code=124,
            duration_ms=duration_ms,
            stdout_path=stdout_path,
            stderr_path=stderr_path,
            status="fail",
            note=f"timeout after {timeout_sec}s",
            case=case,
        )


def discover_smoke_cases() -> list[tuple[str, str, dict[str, Any]]]:
    repo = repo_root()
    specs = load_script_specs(repo / "tests" / "script_specs")
    discovered: list[tuple[str, str, dict[str, Any]]] = []

    for script, spec in sorted(specs.items()):
        smoke = spec.get("smoke")
        if not smoke:
            continue

        smoke_cases: list[Any]
        if isinstance(smoke, list):
            smoke_cases = smoke
        elif isinstance(smoke, dict) and isinstance(smoke.get("cases"), list):
            smoke_cases = smoke["cases"]
        else:
            raise TypeError(f"spec.smoke must be a list (or {{cases:[...]}}): {script}")

        for idx, case in enumerate(smoke_cases, start=1):
            if not isinstance(case, dict):
                raise TypeError(f"smoke case must be a JSON object: {script} (case {idx})")
            name = case.get("name", f"case-{idx}")
            if not isinstance(name, str) or not name.strip():
                raise TypeError(f"smoke case name must be a non-empty string: {script} (case {idx})")
            discovered.append((script, name.strip(), case))

    return sorted(discovered, key=lambda x: (x[0], x[1]))


@pytest.mark.script_smoke
@pytest.mark.parametrize(("script", "case", "spec"), discover_smoke_cases())
def test_script_smoke_spec(script: str, case: str, spec: dict[str, Any]):
    repo = repo_root()

    result = run_smoke_script(script, case, spec, repo)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    artifacts = spec.get("artifacts", [])
    if artifacts:
        if not isinstance(artifacts, list) or not all(isinstance(x, str) for x in artifacts):
            raise TypeError(f"spec.artifacts must be a list of strings: {script} ({case})")
        for rel in artifacts:
            path = repo / rel
            assert path.exists(), f"missing artifact: {rel} (from {script} {case})"

    assert result.status == "pass", (
        f"script smoke failed: {script} ({case}) (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )


@pytest.mark.script_smoke
def test_script_smoke_fixture_staged_context(tmp_path: Path):
    work_tree = tmp_path / "repo"
    work_tree.mkdir(parents=True, exist_ok=True)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(work_tree), check=True, text=True, capture_output=True)

    run(["git", "init"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])

    tracked = work_tree / "hello.txt"
    tracked.write_text("one\n", "utf-8")
    run(["git", "add", "hello.txt"])
    run(["git", "commit", "-m", "init"])

    tracked.write_text("two\n", "utf-8")
    run(["git", "add", "hello.txt"])

    repo = repo_root()
    script = "skills/tools/devex/semantic-commit/scripts/staged_context.sh"
    spec: dict[str, Any] = {
        "args": [],
        "timeout_sec": 10,
        "env": {"CODEX_HOME": None, "CODEX_COMMANDS_PATH": None},
        "expect": {
            "exit_codes": [0],
            "stdout_regex": r"(?s)# Commit Context.*hello\.txt",
        },
    }

    result = run_smoke_script(script, "staged-context", spec, repo, cwd=work_tree)
    SCRIPT_SMOKE_RUN_RESULTS.append(result)

    assert result.status == "pass", (
        f"script smoke (fixture) failed: {script} (exit={result.exit_code})\n"
        f"argv: {' '.join(result.argv)}\n"
        f"stdout: {result.stdout_path}\n"
        f"stderr: {result.stderr_path}\n"
        f"note: {result.note or 'None'}"
    )
