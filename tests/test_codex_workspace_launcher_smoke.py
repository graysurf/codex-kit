from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

import pytest

from .conftest import default_smoke_env, repo_root


def launcher_path() -> Path:
    return repo_root() / "docker" / "codex-env" / "bin" / "codex-workspace"


def run_launcher(args: list[str], extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    env = default_smoke_env(repo_root())
    env["CODEX_DOCKER_STUB_MODE_ENABLED"] = "true"
    env["CODEX_ENV_IMAGE"] = "stub/codex-env:latest"
    env["CODEX_WORKSPACE_PREFIX"] = "codex-ws"
    env["DEFAULT_SECRETS_MOUNT"] = "/home/codex/codex_secrets"
    env["CODEX_DOCKER_STUB_CONTAINER_EXISTS"] = "true"
    env["CODEX_DOCKER_STUB_CONTAINER_RUNNING"] = "true"
    env["CODEX_DOCKER_STUB_IMAGE_EXISTS"] = "true"
    env["CODEX_DOCKER_STUB_HAS_CODE"] = "true"
    env["CODEX_DOCKER_STUB_TUNNEL_RUNNING"] = "false"
    env["CODEX_DOCKER_STUB_REPO_PRESENT"] = "false"
    if extra_env:
        env.update(extra_env)

    return subprocess.run(
        [str(launcher_path()), *args],
        env=env,
        cwd=str(repo_root()),
        text=True,
        capture_output=True,
    )


@pytest.mark.script_smoke
def test_capabilities_command_outputs_json() -> None:
    completed = run_launcher(["capabilities"])
    assert completed.returncode == 0, completed.stderr
    payload = json.loads(completed.stdout)
    assert payload["version"]
    assert "output-json" in payload["capabilities"]


@pytest.mark.script_smoke
def test_supports_flag_exit_codes() -> None:
    supported = run_launcher(["--supports", "output-json"])
    assert supported.returncode == 0

    unsupported = run_launcher(["--supports", "does-not-exist"])
    assert unsupported.returncode == 1


@pytest.mark.script_smoke
def test_help_includes_create_and_output() -> None:
    completed = run_launcher(["--help"])
    assert completed.returncode == 0
    assert "up|create" in completed.stdout
    assert "--output json" in completed.stdout


@pytest.mark.script_smoke
def test_create_output_json_stdout_is_pure_json() -> None:
    completed = run_launcher(["create", "--no-clone", "--name", "ws-test", "--output", "json"])
    assert completed.returncode == 0, completed.stderr

    payload: dict[str, Any] = json.loads(completed.stdout)
    assert payload["command"] == "create"
    assert payload["workspace"] == "codex-ws-ws-test"
    assert payload["repo"] is None
    assert payload["path"] == "/work"
    assert payload["image"] == "stub/codex-env:latest"
    assert payload["secrets"]["enabled"] is False

    assert "workspace:" in completed.stderr
    assert "workspace:" not in completed.stdout


@pytest.mark.script_smoke
def test_secrets_mount_requires_secrets_dir() -> None:
    completed = run_launcher(
        ["up", "--no-clone", "--name", "ws-test", "--secrets-mount", "/home/codex/codex_secrets"]
    )
    assert completed.returncode != 0
    assert "--secrets-mount requires --secrets-dir" in completed.stderr


@pytest.mark.script_smoke
def test_codex_profile_requires_secrets_dir() -> None:
    completed = run_launcher(["create", "--no-clone", "--name", "ws-test", "--codex-profile", "personal"])
    assert completed.returncode != 0
    assert "--codex-profile requires --secrets-dir" in completed.stderr


@pytest.mark.script_smoke
def test_codex_profile_sets_secrets_metadata_and_runs_codex_use(tmp_path: Path) -> None:
    secrets_dir = tmp_path / "secrets"
    secrets_dir.mkdir(parents=True, exist_ok=True)

    log_dir = tmp_path / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    completed = run_launcher(
        [
            "create",
            "--no-clone",
            "--name",
            "ws-test",
            "--secrets-dir",
            str(secrets_dir),
            "--codex-profile",
            "personal",
            "--output",
            "json",
        ],
        extra_env={
            "CODEX_DOCKER_STUB_CONTAINER_EXISTS": "false",
            "CODEX_STUB_LOG_DIR": str(log_dir),
        },
    )
    assert completed.returncode == 0, completed.stderr

    payload: dict[str, Any] = json.loads(completed.stdout)
    assert payload["secrets"]["enabled"] is True
    assert payload["secrets"]["dir"] == str(secrets_dir)
    assert payload["secrets"]["mount"] == "/home/codex/codex_secrets"
    assert payload["secrets"]["codex_profile"] == "personal"

    calls = (log_dir / "docker.calls.txt").read_text("utf-8")
    assert "zsh -lic codex-use personal" in calls


@pytest.mark.script_smoke
def test_setup_git_implies_persist_token_when_present(tmp_path: Path) -> None:
    log_dir = tmp_path / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    completed = run_launcher(
        ["create", "--no-clone", "--name", "ws-test", "--setup-git", "--output", "json"],
        extra_env={
            "CODEX_DOCKER_STUB_CONTAINER_EXISTS": "false",
            "CODEX_STUB_LOG_DIR": str(log_dir),
            "GH_TOKEN": "stub-token",
            "GITHUB_TOKEN": "",
        },
    )
    assert completed.returncode == 0, completed.stderr

    calls = (log_dir / "docker.calls.txt").read_text("utf-8")
    assert "-e GH_TOKEN=stub-token" in calls


@pytest.mark.script_smoke
def test_tunnel_output_json_requires_detach() -> None:
    completed = run_launcher(["tunnel", "ws-test", "--output", "json"])
    assert completed.returncode != 0
    assert "--output json requires --detach" in completed.stderr
    assert completed.stdout.strip() == ""


@pytest.mark.script_smoke
def test_tunnel_detach_json_has_short_sanitized_name() -> None:
    long_container = "codex-ws-super-long-owner-super-long-repo-20260122-123456"
    completed = run_launcher(["tunnel", long_container, "--detach", "--output", "json"])
    assert completed.returncode == 0, completed.stderr

    payload: dict[str, Any] = json.loads(completed.stdout)
    tunnel_name = str(payload["tunnel_name"])
    assert 1 <= len(tunnel_name) <= 20
    assert tunnel_name == tunnel_name.lower()
    assert tunnel_name.replace("-", "").isalnum()
    assert payload["log_path"]
    assert payload["detach"] is True


@pytest.mark.script_smoke
def test_tunnel_detach_json_name_override_is_sanitized() -> None:
    completed = run_launcher(["tunnel", "ws-test", "--detach", "--output", "json", "--name", "My Name!!"])
    assert completed.returncode == 0, completed.stderr

    payload: dict[str, Any] = json.loads(completed.stdout)
    assert payload["tunnel_name"] == "my-name"


@pytest.mark.script_smoke
def test_rm_default_removes_volumes() -> None:
    completed = run_launcher(["rm", "ws-test"])
    assert completed.returncode == 0, completed.stderr
    assert "volumes removed" in completed.stdout


@pytest.mark.script_smoke
def test_rm_keep_volumes_skips_volume_removal() -> None:
    completed = run_launcher(["rm", "ws-test", "--keep-volumes"])
    assert completed.returncode == 0, completed.stderr
    assert "volumes removed" not in completed.stdout
