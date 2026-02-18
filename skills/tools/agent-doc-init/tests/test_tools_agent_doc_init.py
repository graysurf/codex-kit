from __future__ import annotations

import os
import subprocess
import textwrap
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def _skill_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _script_path() -> Path:
    return _skill_root() / "scripts" / "agent_doc_init.sh"


def _write_agent_docs_stub(tmp_path: Path) -> Path:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    stub = bin_dir / "agent-docs"
    stub.write_text(
        textwrap.dedent(
            """\
            #!/usr/bin/env python3
            from __future__ import annotations

            import json
            import os
            import shlex
            import sys
            from pathlib import Path

            args = sys.argv[1:]
            log_path = Path(os.environ["AGENT_DOCS_STUB_LOG"])
            state_path = Path(os.environ["AGENT_DOCS_STUB_STATE"])
            seq_raw = os.environ.get("AGENT_DOCS_STUB_BASELINE_SEQ", "0")
            seq = [int(x) for x in seq_raw.split(",") if x.strip()]
            if not seq:
                seq = [0]

            with log_path.open("a", encoding="utf-8") as f:
                f.write(" ".join(shlex.quote(a) for a in args) + "\\n")

            if not args:
                print("usage: agent-docs <command>", file=sys.stderr)
                raise SystemExit(2)

            command = args[0]
            if command == "baseline":
                idx = 0
                if state_path.exists():
                    raw = state_path.read_text(encoding="utf-8").strip()
                    if raw:
                        idx = int(raw)
                missing_required = seq[idx] if idx < len(seq) else seq[-1]
                state_path.write_text(str(idx + 1), encoding="utf-8")

                payload = {
                    "missing_required": missing_required,
                    "missing_optional": 0,
                    "items": [],
                    "suggested_actions": [],
                }
                fmt = "text"
                if "--format" in args:
                    pos = args.index("--format")
                    if pos + 1 < len(args):
                        fmt = args[pos + 1]
                if fmt == "json":
                    print(json.dumps(payload))
                else:
                    print(f"missing_required: {missing_required}")
                raise SystemExit(0)

            if command == "scaffold-baseline":
                if os.environ.get("AGENT_DOCS_STUB_SCAFFOLD_FAIL") == "1":
                    print("scaffold failed", file=sys.stderr)
                    raise SystemExit(4)
                print("scaffold-baseline: ok")
                raise SystemExit(0)

            if command == "add":
                print("add: target=project action=updated config=/tmp/AGENT_DOCS.toml entries=1")
                raise SystemExit(0)

            print(f"unsupported command: {command}", file=sys.stderr)
            raise SystemExit(2)
            """
        ),
        encoding="utf-8",
    )
    stub.chmod(0o755)
    return bin_dir


def _run_script(
    tmp_path: Path,
    args: list[str],
    *,
    baseline_seq: str = "0,0",
    extra_env: dict[str, str | None] | None = None,
) -> tuple[subprocess.CompletedProcess[str], list[str]]:
    bin_dir = _write_agent_docs_stub(tmp_path)
    log_path = tmp_path / "agent_docs_calls.log"
    state_path = tmp_path / "agent_docs_state.txt"
    state_path.write_text("0", encoding="utf-8")

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    env["AGENT_DOCS_STUB_LOG"] = str(log_path)
    env["AGENT_DOCS_STUB_STATE"] = str(state_path)
    env["AGENT_DOCS_STUB_BASELINE_SEQ"] = baseline_seq
    if extra_env:
        for key, value in extra_env.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value

    project_path = tmp_path / "project"
    project_path.mkdir(parents=True, exist_ok=True)

    proc = subprocess.run(
        [str(_script_path()), *args],
        text=True,
        capture_output=True,
        env=env,
    )
    calls = log_path.read_text(encoding="utf-8").splitlines() if log_path.exists() else []
    return proc, calls


def _write_template_docs(project_path: Path) -> None:
    (project_path / "AGENTS.md").write_text(
        textwrap.dedent(
            """\
            # AGENTS.md

            ## Startup Policy

            Resolve required startup policies before task execution:

            ```bash
            agent-docs resolve --context startup
            ```

            ## Project Development Policy

            Resolve project development docs before implementing changes:

            ```bash
            agent-docs resolve --context project-dev
            ```

            ## Extension Point

            Use `AGENT_DOCS.toml` to register additional required documents by context and scope.
            """
        ),
        encoding="utf-8",
    )
    (project_path / "DEVELOPMENT.md").write_text(
        textwrap.dedent(
            """\
            # DEVELOPMENT.md

            ## Setup

            Run setup before editing or building:

            ```bash
            echo "Define setup command for this repository"
            ```

            ## Build

            Run build commands before sharing changes:

            ```bash
            echo "Define build command for this repository"
            ```

            ## Test

            Run checks before delivery:

            ```bash
            echo "Define test command for this repository"
            ```

            ## Notes

            - Keep commands deterministic and runnable from the repository root.
            - Update this file when your build or test workflow changes.
            """
        ),
        encoding="utf-8",
    )


def test_tools_agent_doc_init_contract() -> None:
    assert_skill_contract(_skill_root())


def test_tools_agent_doc_init_entrypoints_exist() -> None:
    assert_entrypoints_exist(_skill_root(), ["scripts/agent_doc_init.sh"])


def test_agent_doc_init_default_dry_run_noop(tmp_path: Path) -> None:
    proc, calls = _run_script(
        tmp_path,
        ["--project-path", str(Path.cwd())],
        baseline_seq="0,0",
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert "agent_doc_init mode=dry-run" in proc.stdout
    assert "scaffold_action=skipped" in proc.stdout
    assert "result changed=false" in proc.stdout
    assert sum(1 for line in calls if line.startswith("baseline ")) == 2
    assert all(not line.startswith("scaffold-baseline ") for line in calls)


def test_agent_doc_init_uses_agent_home_env_when_cli_agent_home_unset(tmp_path: Path) -> None:
    agent_home = tmp_path / "agent-home"
    agent_home.mkdir(parents=True, exist_ok=True)

    proc, calls = _run_script(
        tmp_path,
        ["--project-path", str(Path.cwd())],
        baseline_seq="0,0",
        extra_env={"AGENT_HOME": str(agent_home)},
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert f"agent_doc_init AGENT_HOME={agent_home}" in proc.stdout
    baseline_calls = [line for line in calls if line.startswith("baseline ")]
    assert baseline_calls
    assert f"--agent-home {agent_home}" in baseline_calls[0]


def test_agent_doc_init_uses_agents_home_env_when_agent_home_unset(tmp_path: Path) -> None:
    agents_home = tmp_path / "agents-home"
    agents_home.mkdir(parents=True, exist_ok=True)

    proc, calls = _run_script(
        tmp_path,
        ["--project-path", str(Path.cwd())],
        baseline_seq="0,0",
        extra_env={"AGENT_HOME": None, "AGENTS_HOME": str(agents_home)},
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert f"agent_doc_init AGENT_HOME={agents_home}" in proc.stdout
    baseline_calls = [line for line in calls if line.startswith("baseline ")]
    assert baseline_calls
    assert f"--agent-home {agents_home}" in baseline_calls[0]


def test_agent_doc_init_cli_agent_home_overrides_env(tmp_path: Path) -> None:
    env_home = tmp_path / "env-home"
    env_home.mkdir(parents=True, exist_ok=True)
    cli_home = tmp_path / "cli-home"
    cli_home.mkdir(parents=True, exist_ok=True)

    proc, calls = _run_script(
        tmp_path,
        ["--project-path", str(Path.cwd()), "--agent-home", str(cli_home)],
        baseline_seq="0,0",
        extra_env={"AGENT_HOME": str(env_home)},
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert f"agent_doc_init AGENT_HOME={cli_home}" in proc.stdout
    baseline_calls = [line for line in calls if line.startswith("baseline ")]
    assert baseline_calls
    assert f"--agent-home {cli_home}" in baseline_calls[0]


def test_agent_doc_init_apply_runs_missing_only_scaffold(tmp_path: Path) -> None:
    proc, calls = _run_script(
        tmp_path,
        ["--apply", "--project-path", str(Path.cwd())],
        baseline_seq="2,0",
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    scaffolds = [line for line in calls if line.startswith("scaffold-baseline ")]
    assert len(scaffolds) == 1
    assert "--missing-only" in scaffolds[0]
    assert "--dry-run" not in scaffolds[0]
    assert "scaffold_action=applied" in proc.stdout
    assert "result changed=true" in proc.stdout


def test_agent_doc_init_force_requires_apply(tmp_path: Path) -> None:
    proc, _ = _run_script(
        tmp_path,
        ["--force", "--project-path", str(Path.cwd())],
        baseline_seq="0,0",
    )
    assert proc.returncode == 2
    assert "--force requires --apply" in proc.stderr


def test_agent_doc_init_apply_project_required_entry(tmp_path: Path) -> None:
    proc, calls = _run_script(
        tmp_path,
        [
            "--apply",
            "--project-path",
            str(Path.cwd()),
            "--project-required",
            "project-dev:BINARY_DEPENDENCIES.md:External runtime tools",
        ],
        baseline_seq="0,0",
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    add_calls = [line for line in calls if line.startswith("add ")]
    assert len(add_calls) == 1
    assert "--context project-dev" in add_calls[0]
    assert "--path BINARY_DEPENDENCIES.md" in add_calls[0]
    assert "project_entries requested=1 applied=1" in proc.stdout


def test_agent_doc_init_dry_run_plans_template_hydration(tmp_path: Path) -> None:
    project_path = tmp_path / "project"
    project_path.mkdir(parents=True, exist_ok=True)
    _write_template_docs(project_path)

    proc, _calls = _run_script(
        tmp_path,
        ["--project-path", str(project_path)],
        baseline_seq="0,0",
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert "doc_hydration action=planned" in proc.stdout
    assert "template_guard=pending" in proc.stdout

    dev = (project_path / "DEVELOPMENT.md").read_text(encoding="utf-8")
    assert 'echo "Define setup command for this repository"' in dev


def test_agent_doc_init_apply_rewrites_template_docs(tmp_path: Path) -> None:
    project_path = tmp_path / "project"
    project_path.mkdir(parents=True, exist_ok=True)
    _write_template_docs(project_path)

    proc, _calls = _run_script(
        tmp_path,
        ["--apply", "--project-path", str(project_path)],
        baseline_seq="0,0",
    )
    assert proc.returncode == 0, f"exit={proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    assert "doc_hydration action=applied" in proc.stdout
    assert "template_guard=passed" in proc.stdout

    agents = (project_path / "AGENTS.md").read_text(encoding="utf-8")
    dev = (project_path / "DEVELOPMENT.md").read_text(encoding="utf-8")
    assert "agent-docs resolve --context startup --strict --format checklist" in agents
    assert 'echo "Define setup command for this repository"' not in dev
    assert "CI workflows inspected:" in dev
