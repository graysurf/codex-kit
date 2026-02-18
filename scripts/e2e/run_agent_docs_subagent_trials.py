#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def repo_root() -> Path:
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode == 0:
        return Path(proc.stdout.strip()).resolve()
    return Path.cwd().resolve()


def safe_read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: invalid JSON config: {path}: {exc}") from exc


def substitute_tokens(value: str, tokens: dict[str, str]) -> str:
    out = value
    for key, token_value in tokens.items():
        out = out.replace(f"{{{key}}}", token_value)
    return out


def trim_output(text: str, max_chars: int = 4000) -> str:
    if len(text) <= max_chars:
        return text
    head = max_chars // 2
    tail = max_chars - head
    return f"{text[:head]}\n...[truncated]...\n{text[-tail:]}"


@dataclass
class CommandRun:
    command: str
    cwd: str
    expected_exit: int
    exit_code: int
    duration_ms: int
    stdout: str
    stderr: str
    started_at: str
    finished_at: str

    def as_json(self) -> dict[str, Any]:
        return {
            "command": self.command,
            "cwd": self.cwd,
            "expected_exit": self.expected_exit,
            "exit_code": self.exit_code,
            "duration_ms": self.duration_ms,
            "stdout": self.stdout,
            "stderr": self.stderr,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
        }


def run_command(argv: list[str], *, cwd: Path, env: dict[str, str], expected_exit: int) -> CommandRun:
    started = now_iso()
    t0 = time.monotonic()
    proc = subprocess.run(
        argv,
        cwd=str(cwd),
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    duration_ms = int((time.monotonic() - t0) * 1000)
    finished = now_iso()
    return CommandRun(
        command=shlex.join(argv),
        cwd=str(cwd),
        expected_exit=expected_exit,
        exit_code=proc.returncode,
        duration_ms=duration_ms,
        stdout=trim_output(proc.stdout),
        stderr=trim_output(proc.stderr),
        started_at=started,
        finished_at=finished,
    )


def execute_command_sequence(
    *,
    scenario: dict[str, Any],
    tokens: dict[str, str],
    base_env: dict[str, str],
) -> tuple[str, str, list[dict[str, Any]]]:
    status = "pass"
    failure_reason = ""
    trace: list[dict[str, Any]] = []
    for idx, command_spec in enumerate(scenario.get("commands", []), start=1):
        raw_argv = command_spec.get("argv")
        if not isinstance(raw_argv, list) or not raw_argv:
            status = "fail"
            failure_reason = f"invalid command spec at index {idx}"
            break

        argv = [substitute_tokens(str(arg), tokens) for arg in raw_argv]
        expected_exit = int(command_spec.get("expected_exit", 0))
        cwd_value = substitute_tokens(str(command_spec.get("cwd", "{REPO_ROOT}")), tokens)
        cwd = Path(cwd_value).resolve()

        env = base_env.copy()
        env["AGENT_HOME"] = tokens["AGENT_HOME"]
        env["PROJECT_PATH"] = tokens["PROJECT_PATH"]

        run = run_command(argv, cwd=cwd, env=env, expected_exit=expected_exit)
        trace.append(run.as_json())
        if run.exit_code != expected_exit:
            status = "fail"
            failure_reason = (
                f"exit mismatch at step {idx}: expected {expected_exit}, got {run.exit_code} "
                f"for `{run.command}`"
            )
            break

    return status, failure_reason, trace


def build_temp_missing_doc_scenario(
    scenario: dict[str, Any], tokens: dict[str, str], base_env: dict[str, str]
) -> tuple[str, str, list[dict[str, Any]], dict[str, str]]:
    with tempfile.TemporaryDirectory(prefix="agent-docs-trial-missing-") as temp_dir:
        temp_root = Path(temp_dir)
        temp_home = temp_root / "agent-home"
        temp_project = temp_root / "project"
        temp_home.mkdir(parents=True, exist_ok=True)
        temp_project.mkdir(parents=True, exist_ok=True)

        local_tokens = tokens.copy()
        local_tokens["TEMP_HOME"] = str(temp_home)
        local_tokens["TEMP_PROJECT"] = str(temp_project)

        scenario_commands = {
            "commands": [
                {
                    "argv": [
                        "agent-docs",
                        "--agent-home",
                        "{TEMP_HOME}",
                        "--project-path",
                        "{TEMP_PROJECT}",
                        "resolve",
                        "--context",
                        "project-dev",
                        "--strict",
                        "--format",
                        "text",
                    ],
                    "expected_exit": int(scenario.get("expected_exit", 1)),
                }
            ]
        }
        status, failure_reason, trace = execute_command_sequence(
            scenario=scenario_commands,
            tokens=local_tokens,
            base_env=base_env,
        )
        extras = {
            "temp_home": str(temp_home),
            "temp_project": str(temp_project),
        }
        return status, failure_reason, trace, extras


def build_temp_auto_init_scenario(
    scenario: dict[str, Any], tokens: dict[str, str], base_env: dict[str, str]
) -> tuple[str, str, list[dict[str, Any]], dict[str, str]]:
    with tempfile.TemporaryDirectory(prefix="agent-docs-trial-init-") as temp_dir:
        temp_root = Path(temp_dir)
        temp_home = temp_root / "agent-home"
        temp_project = temp_root / "project"
        temp_home.mkdir(parents=True, exist_ok=True)
        temp_project.mkdir(parents=True, exist_ok=True)

        local_tokens = tokens.copy()
        local_tokens["TEMP_HOME"] = str(temp_home)
        local_tokens["TEMP_PROJECT"] = str(temp_project)
        local_tokens["AGENT_DOC_INIT"] = str(
            Path(tokens["REPO_ROOT"]) / "skills" / "tools" / "agent-doc-init" / "scripts" / "agent_doc_init.sh"
        )

        scenario_commands = {
            "commands": [
                {
                    "argv": [
                        "{AGENT_DOC_INIT}",
                        "--apply",
                        "--agent-home",
                        "{TEMP_HOME}",
                        "--project-path",
                        "{TEMP_PROJECT}",
                    ],
                    "expected_exit": 0,
                },
                {
                    "argv": [
                        "agent-docs",
                        "--agent-home",
                        "{TEMP_HOME}",
                        "--project-path",
                        "{TEMP_PROJECT}",
                        "baseline",
                        "--check",
                        "--target",
                        "all",
                        "--strict",
                        "--format",
                        "text",
                    ],
                    "expected_exit": 0,
                },
                {
                    "argv": [
                        "{AGENT_DOC_INIT}",
                        "--dry-run",
                        "--agent-home",
                        "{TEMP_HOME}",
                        "--project-path",
                        "{TEMP_PROJECT}",
                    ],
                    "expected_exit": 0,
                },
            ]
        }
        status, failure_reason, trace = execute_command_sequence(
            scenario=scenario_commands,
            tokens=local_tokens,
            base_env=base_env,
        )
        extras = {
            "temp_home": str(temp_home),
            "temp_project": str(temp_project),
        }
        return status, failure_reason, trace, extras


def run_scenario(
    *,
    scenario: dict[str, Any],
    tokens: dict[str, str],
    base_env: dict[str, str],
) -> dict[str, Any]:
    started = now_iso()
    t0 = time.monotonic()
    kind = str(scenario.get("kind", "command-sequence"))
    status = "fail"
    failure_reason = ""
    trace: list[dict[str, Any]] = []
    extras: dict[str, str] = {}

    if kind == "command-sequence":
        status, failure_reason, trace = execute_command_sequence(
            scenario=scenario,
            tokens=tokens,
            base_env=base_env,
        )
    elif kind == "temp-missing-doc-strict":
        status, failure_reason, trace, extras = build_temp_missing_doc_scenario(scenario, tokens, base_env)
    elif kind == "temp-auto-init-success":
        status, failure_reason, trace, extras = build_temp_auto_init_scenario(scenario, tokens, base_env)
    else:
        status = "fail"
        failure_reason = f"unsupported scenario kind: {kind}"

    duration_ms = int((time.monotonic() - t0) * 1000)
    finished = now_iso()
    return {
        "scenario_id": scenario.get("id", ""),
        "name": scenario.get("name", ""),
        "kind": kind,
        "prompt": scenario.get("prompt", ""),
        "status": status,
        "failure_reason": failure_reason,
        "command_trace": trace,
        "context": scenario.get("context", ""),
        "started_at": started,
        "finished_at": finished,
        "duration_ms": duration_ms,
        "meta": extras,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run deterministic agent-docs subagent feasibility trials.")
    parser.add_argument("--config", required=True, help="Path to trial config JSON.")
    parser.add_argument("--output", required=True, help="Path to output trial results JSON.")
    args = parser.parse_args()

    config_path = Path(args.config).resolve()
    output_path = Path(args.output).resolve()

    config = safe_read_json(config_path)
    scenarios = config.get("scenarios", [])
    if not isinstance(scenarios, list) or not scenarios:
        raise SystemExit("error: config must include a non-empty `scenarios` array")

    root = repo_root()
    effective_AGENT_HOME = Path(
        os.environ.get("AGENT_HOME") or os.environ.get("AGENTS_HOME") or str(root)
    ).resolve()
    effective_project_path = Path(os.environ.get("PROJECT_PATH", str(root))).resolve()
    tokens = {
        "REPO_ROOT": str(root),
        "AGENT_HOME": str(effective_AGENT_HOME),
        "PROJECT_PATH": str(effective_project_path),
    }

    base_env = os.environ.copy()
    results: list[dict[str, Any]] = []
    for scenario in scenarios:
        results.append(run_scenario(scenario=scenario, tokens=tokens, base_env=base_env))

    passed = sum(1 for item in results if item.get("status") == "pass")
    total = len(results)
    failed = total - passed
    pass_rate = round((passed / total) * 100.0, 2) if total else 0.0

    payload = {
        "schema_version": 1,
        "generated_at": now_iso(),
        "config_path": str(config_path),
        "output_path": str(output_path),
        "trial_mode": "deterministic-subagent-feasibility",
        "environment": {
            "repo_root": str(root),
            "AGENT_HOME": str(effective_AGENT_HOME),
            "project_path": str(effective_project_path),
        },
        "scenarios": scenarios,
        "results": results,
        "summary": {
            "total": total,
            "passed": passed,
            "failed": failed,
            "pass_rate": pass_rate,
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(f"ok: wrote trial results to {output_path}")
    print(f"summary: total={total} passed={passed} failed={failed} pass_rate={pass_rate}%")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
