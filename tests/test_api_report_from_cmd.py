from __future__ import annotations

import shlex
import subprocess
from pathlib import Path

from .conftest import default_env, repo_root


def _run(cmd: list[str], *, cwd: Path, env: dict[str, str], stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        env=env,
        input=stdin,
        text=True,
        capture_output=True,
        check=True,
    )


def test_api_report_from_cmd_expands_tilde_config_dir() -> None:
    repo = repo_root()
    env = default_env(repo)
    home = Path(env["HOME"])

    project = home / "sample-project"
    config_dir = project / "setup" / "graphql"
    config_dir.mkdir(parents=True, exist_ok=True)

    _run(["git", "init"], cwd=project, env=env)

    gql_script = repo / "skills" / "tools" / "testing" / "graphql-api-testing" / "scripts" / "gql.sh"
    snippet = (
        f"{gql_script} --config-dir ~/sample-project/setup/graphql --env local "
        "setup/graphql/operations/test.graphql "
        "setup/graphql/operations/test.variables.json"
    )

    cmd = [str(repo / "commands" / "api-report-from-cmd"), "--dry-run", "--stdin"]
    completed = _run(cmd, cwd=repo, env=env, stdin=snippet)

    args = shlex.split(completed.stdout.strip())
    assert "--config-dir" in args, f"missing --config-dir in output: {completed.stdout}"
    assert "--project-root" in args, f"missing --project-root in output: {completed.stdout}"
    assert "--op" in args, f"missing --op in output: {completed.stdout}"

    config_idx = args.index("--config-dir")
    project_idx = args.index("--project-root")
    op_idx = args.index("--op")

    assert args[config_idx + 1] == str(config_dir)
    assert args[project_idx + 1] == str(project)
    assert args[op_idx + 1] == str(project / "setup" / "graphql" / "operations" / "test.graphql")
