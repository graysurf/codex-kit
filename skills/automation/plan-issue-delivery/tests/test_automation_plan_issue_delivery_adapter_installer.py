from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[4]


def _run_adapter(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    repo = _repo_root()
    cmd = [sys.executable, str(repo / "scripts" / "plan-issue-adapter"), *args]
    return subprocess.run(
        cmd,
        cwd=str(cwd or repo),
        text=True,
        capture_output=True,
        check=False,
    )


def test_plan_issue_adapter_claude_install_dry_run_does_not_write_files(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()

    completed = _run_adapter(
        "install",
        "--runtime",
        "claude",
        "--project-path",
        str(project),
    )

    assert completed.returncode == 0, completed.stderr
    assert "mode: dry-run" in completed.stdout
    assert "runtime: claude" in completed.stdout
    assert "create" in completed.stdout
    assert not (project / ".claude").exists()


def test_plan_issue_adapter_codex_install_merges_managed_sections(tmp_path: Path) -> None:
    home = tmp_path / "home"
    codex_root = home / ".codex"
    codex_root.mkdir(parents=True)
    config_path = codex_root / "config.toml"
    config_path.write_text(
        'model = "gpt-5.4"\n\n[agents.existing]\ndescription = "keep-me"\n',
        encoding="utf-8",
    )

    completed = _run_adapter(
        "install",
        "--runtime",
        "codex",
        "--home-path",
        str(home),
        "--apply",
    )

    assert completed.returncode == 0, completed.stderr
    config_text = config_path.read_text(encoding="utf-8")
    assert 'model = "gpt-5.4"' in config_text
    assert '[agents.existing]' in config_text
    assert "[agents.plan_issue_worker]" in config_text
    assert "[agents.plan_issue_reviewer]" in config_text
    assert "[agents.plan_issue_monitor]" in config_text
    assert (codex_root / "agents" / "plan-issue-worker.toml").exists()
    assert (codex_root / "agents" / "plan-issue-reviewer.toml").exists()
    assert (codex_root / "agents" / "plan-issue-monitor.toml").exists()


def test_plan_issue_adapter_opencode_sync_merges_existing_json(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    opencode_path = project / "opencode.json"
    opencode_path.write_text(
        json.dumps(
            {
                "$schema": "https://opencode.ai/config.json",
                "agent": {
                    "existing-agent": {"mode": "subagent"},
                    "plan-issue-orchestrator": {
                        "description": "old",
                        "mode": "primary",
                    },
                },
                "theme": "custom",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    completed = _run_adapter(
        "sync",
        "--runtime",
        "opencode",
        "--project-path",
        str(project),
        "--apply",
    )

    assert completed.returncode == 0, completed.stderr
    updated = json.loads(opencode_path.read_text(encoding="utf-8"))
    assert updated["theme"] == "custom"
    assert "existing-agent" in updated["agent"]
    orchestrator = updated["agent"]["plan-issue-orchestrator"]
    assert orchestrator["mode"] == "primary"
    assert "plan-issue-delivery orchestration" in orchestrator["description"]
    assert (project / ".opencode" / "prompts" / "plan-issue-orchestrator.txt").exists()
    assert (project / ".opencode" / "agents" / "plan-issue-review.md").exists()
