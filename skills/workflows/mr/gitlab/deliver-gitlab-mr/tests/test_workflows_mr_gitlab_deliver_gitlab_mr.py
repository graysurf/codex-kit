from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "deliver-gitlab-mr.sh"


def test_workflows_mr_gitlab_deliver_gitlab_mr_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_workflows_mr_gitlab_deliver_gitlab_mr_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/deliver-gitlab-mr.sh"])


def _run(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    proc_env = os.environ.copy()
    if env:
        proc_env.update(env)
    return subprocess.run(
        args,
        cwd=str(cwd),
        env=proc_env,
        text=True,
        capture_output=True,
        check=False,
    )


def _git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return _run(["git", *args], cwd=repo)


def _assert_ok(proc: subprocess.CompletedProcess[str]) -> None:
    assert proc.returncode == 0, proc.stderr


def _write(repo: Path, rel_path: str, content: str) -> None:
    file_path = repo / rel_path
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content, encoding="utf-8")


def _seed_commit(repo: Path, files: dict[str, str], *, message: str) -> None:
    for rel_path, content in files.items():
        _write(repo, rel_path, content)
    _assert_ok(_git(repo, "add", "-A"))
    _assert_ok(_git(repo, "commit", "-q", "-m", message))


def _init_repo(repo: Path) -> None:
    _assert_ok(_run(["git", "init", "-q"], cwd=repo))
    _assert_ok(_git(repo, "checkout", "-q", "-B", "main"))
    _assert_ok(_git(repo, "config", "user.email", "test@example.com"))
    _assert_ok(_git(repo, "config", "user.name", "Test User"))
    _seed_commit(repo, {"README.md": "seed\n"}, message="chore: seed repository")


def _install_fake_glab(tmp_path: Path) -> tuple[Path, Path]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log_path = tmp_path / "glab.log"
    glab_path = bin_dir / "glab"
    glab_path.write_text(
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        "printf '%s\\n' \"glab $*\" >> \"${GLAB_FAKE_LOG:?}\"\n"
        "if [[ \"${1-}\" == \"auth\" && \"${2-}\" == \"status\" ]]; then\n"
        "  if [[ \"${GLAB_FAKE_AUTH_STATUS:-ok}\" == \"fail\" ]]; then\n"
        "    echo \"auth failed\" >&2\n"
        "    exit 1\n"
        "  fi\n"
        "  exit 0\n"
        "fi\n"
        "if [[ \"${1-}\" == \"ci\" && \"${2-}\" == \"status\" ]]; then\n"
        "  if [[ \"${GLAB_FAKE_PIPELINE_STATUS:-success}\" == \"no_pipeline\" ]]; then\n"
        "    echo \"No pipeline found. It might not exist yet. Check your pipeline configuration.\" >&2\n"
        "    exit 1\n"
        "  fi\n"
        "  if [[ -n \"${GLAB_FAKE_PIPELINE_JSON:-}\" ]]; then\n"
        "    printf '%s\\n' \"${GLAB_FAKE_PIPELINE_JSON}\"\n"
        "    exit 0\n"
        "  fi\n"
        "  printf '{\"status\":\"%s\"}\\n' \"${GLAB_FAKE_PIPELINE_STATUS:-success}\"\n"
        "  exit 0\n"
        "fi\n"
        "if [[ \"${1-}\" == \"mr\" && \"${2-}\" == \"view\" ]]; then\n"
        "  printf '{\"iid\":7,\"web_url\":\"https://gitlab.example/group/project/-/merge_requests/7\",'\n"
        "  printf '\"source_branch\":\"%s\",\"target_branch\":\"main\",' \"${GLAB_FAKE_SOURCE_BRANCH:-feat/demo}\"\n"
        "  printf '\"state\":\"%s\",\"draft\":%s}\\n' \"${GLAB_FAKE_MR_STATE:-opened}\" \"${GLAB_FAKE_DRAFT:-true}\"\n"
        "  exit 0\n"
        "fi\n"
        "if [[ \"${1-}\" == \"mr\" && \"${2-}\" == \"update\" ]]; then\n"
        "  exit 0\n"
        "fi\n"
        "if [[ \"${1-}\" == \"mr\" && \"${2-}\" == \"merge\" ]]; then\n"
        "  exit 0\n"
        "fi\n"
        "echo \"unexpected glab args: $*\" >&2\n"
        "exit 9\n",
        encoding="utf-8",
    )
    glab_path.chmod(glab_path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return bin_dir, log_path


def _setup_repo(tmp_path: Path) -> tuple[Path, dict[str, str], Path]:
    repo = tmp_path / "repo"
    repo.mkdir()
    _init_repo(repo)
    fake_bin, log_path = _install_fake_glab(tmp_path)
    env = {
        "PATH": os.pathsep.join([str(fake_bin), os.environ.get("PATH", "")]),
        "GLAB_FAKE_LOG": str(log_path),
    }
    return repo, env, log_path


def _run_skill(repo: Path, env: dict[str, str], *args: str) -> subprocess.CompletedProcess[str]:
    return _run([str(SCRIPT), *args], cwd=repo, env=env)


def _combined(proc: subprocess.CompletedProcess[str]) -> str:
    return f"{proc.stdout}\n{proc.stderr}".lower()


def test_help_surface() -> None:
    proc = subprocess.run(
        [str(SCRIPT), "--help"],
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode == 0
    assert "deliver-gitlab-mr.sh --kind <feature|bug|config|deploy|docs|chore> <command>" in proc.stdout


def test_preflight_outputs_gitlab_kind_mapping(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)

    proc = _run_skill(repo, env, "--kind", "deploy", "preflight", "--base", "main")

    assert proc.returncode == 0, proc.stderr
    assert "KIND=deploy" in proc.stdout
    assert "BRANCH_PREFIX=chore" in proc.stdout
    assert "CREATE_SKILL=create-gitlab-mr" in proc.stdout
    assert "CLOSE_SKILL=close-gitlab-mr" in proc.stdout
    assert "FINALIZE_COMMAND=close" in proc.stdout


def test_preflight_blocks_branch_mismatch(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    _assert_ok(_git(repo, "checkout", "-q", "-b", "feat/demo"))

    proc = _run_skill(repo, env, "--kind", "feature", "preflight", "--base", "main")

    assert proc.returncode == 1
    assert "initial branch guard failed" in proc.stderr


def test_preflight_surfaces_glab_auth_failure(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_AUTH_STATUS"] = "fail"

    proc = _run_skill(repo, env, "--kind", "feature", "preflight", "--base", "main")

    assert proc.returncode == 1
    assert "auth failed" in proc.stderr


def test_wait_pipeline_passes_on_success_status(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-pipeline",
        "--branch",
        "feat/demo",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 0, proc.stderr
    assert "SOURCE_BRANCH=feat/demo" in proc.stdout
    assert "PIPELINE_STATUS=success" in proc.stdout


def test_wait_pipeline_resolves_branch_from_mr(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_SOURCE_BRANCH"] = "fix/from-mr"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "bug",
        "wait-pipeline",
        "--mr",
        "7",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 0, proc.stderr
    assert "SOURCE_BRANCH=fix/from-mr" in proc.stdout


def test_wait_pipeline_fails_on_failed_status(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_PIPELINE_STATUS"] = "failed"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-pipeline",
        "--branch",
        "feat/demo",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 1
    assert "pipeline is not mergeable" in proc.stderr


def test_wait_pipeline_blocks_nested_skipped_status_with_policy_guidance(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_PIPELINE_JSON"] = '{"pipeline":{"status":"skipped"},"jobs":[]}'

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-pipeline",
        "--branch",
        "feat/demo",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 1
    assert "PIPELINE_STATUS=skipped" in proc.stdout
    assert "failed to parse pipeline status" not in proc.stderr
    assert "target-branch CI" in proc.stderr
    assert "--skip-pipeline" in proc.stderr


def test_wait_pipeline_blocks_nested_manual_detailed_status(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_PIPELINE_JSON"] = '{"pipeline":{"detailed_status":{"group":"manual"}}}'

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "wait-pipeline",
        "--branch",
        "feat/demo",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 1
    assert "PIPELINE_STATUS=manual" in proc.stdout
    assert "failed to parse pipeline status" not in proc.stderr
    assert "--skip-pipeline" in proc.stderr


def test_wait_pipeline_fails_on_missing_pipeline_by_default(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_PIPELINE_STATUS"] = "no_pipeline"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "docs",
        "wait-pipeline",
        "--branch",
        "docs/no-ci",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 1
    assert "PIPELINE_STATUS=missing" in proc.stdout
    assert "use --allow-no-pipeline" in proc.stderr


def test_wait_pipeline_accepts_missing_pipeline_when_explicitly_allowed(tmp_path: Path) -> None:
    repo, env, _ = _setup_repo(tmp_path)
    env["GLAB_FAKE_PIPELINE_STATUS"] = "no_pipeline"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "docs",
        "wait-pipeline",
        "--branch",
        "docs/no-ci",
        "--allow-no-pipeline",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
    )

    assert proc.returncode == 0, proc.stderr
    assert "PIPELINE_STATUS=missing" in proc.stdout
    assert "accepted by --allow-no-pipeline" in proc.stdout


def test_close_marks_draft_ready_and_keeps_remote_source_branch_by_default(tmp_path: Path) -> None:
    repo, env, log_path = _setup_repo(tmp_path)

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "close",
        "--mr",
        "7",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
        "--no-cleanup",
    )

    assert proc.returncode == 0, proc.stderr
    log = log_path.read_text(encoding="utf-8")
    assert "glab mr update 7 --ready --yes" in log
    assert "glab mr merge 7 --yes" in log
    assert "--remove-source-branch" not in log


def test_close_accepts_missing_pipeline_when_explicitly_allowed(tmp_path: Path) -> None:
    repo, env, log_path = _setup_repo(tmp_path)
    env["GLAB_FAKE_PIPELINE_STATUS"] = "no_pipeline"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "docs",
        "close",
        "--mr",
        "7",
        "--allow-no-pipeline",
        "--poll-seconds",
        "1",
        "--max-wait-seconds",
        "1",
        "--no-cleanup",
    )

    assert proc.returncode == 0, proc.stderr
    assert "PIPELINE_STATUS=missing" in proc.stdout
    log = log_path.read_text(encoding="utf-8")
    assert "glab mr merge 7 --yes" in log


def test_close_passes_explicit_merge_controls(tmp_path: Path) -> None:
    repo, env, log_path = _setup_repo(tmp_path)
    env["GLAB_FAKE_DRAFT"] = "false"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "deploy",
        "close",
        "--mr",
        "7",
        "--skip-pipeline",
        "--remove-source-branch",
        "--squash",
        "--sha",
        "abc123",
        "--no-cleanup",
    )

    assert proc.returncode == 0, proc.stderr
    combined = _combined(proc)
    assert "pipeline_status=skipped_by_user_confirmation" in combined
    log = log_path.read_text(encoding="utf-8")
    assert "glab mr update" not in log
    assert "glab mr merge 7 --remove-source-branch --squash --sha abc123 --yes" in log


def test_merge_alias_delegates_to_close_helper(tmp_path: Path) -> None:
    repo, env, log_path = _setup_repo(tmp_path)
    env["GLAB_FAKE_DRAFT"] = "false"

    proc = _run_skill(
        repo,
        env,
        "--kind",
        "feature",
        "merge",
        "--mr",
        "7",
        "--skip-pipeline",
        "--no-cleanup",
    )

    assert proc.returncode == 0, proc.stderr
    assert "PIPELINE_STATUS=skipped_by_user_confirmation" in proc.stdout
    log = log_path.read_text(encoding="utf-8")
    assert "glab mr merge 7 --yes" in log
