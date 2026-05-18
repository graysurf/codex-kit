from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def skill_root() -> Path:
    return Path(__file__).resolve().parents[1]


def repo_root() -> Path:
    return Path(__file__).resolve().parents[5]


def run_script(*args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["AGENT_HOME"] = str(repo_root())
    return subprocess.run(
        [str(skill_root() / "scripts" / "heuristic-error-inbox.sh"), *args],
        text=True,
        capture_output=True,
        env=env,
    )


def write_entry(
    path: Path,
    *,
    title: str = "Fixture Gap",
    status: str = "open",
    severity: str = "medium",
    raw_record: str = "out/projects/example/skill-usage.record.json",
    evidence_extra: str = "- Durable fix: `docs/fix.md`\n",
    next_action: str = "Create a focused implementation plan.",
) -> None:
    path.write_text(
        f"""# {title}

## Status

- Status: {status}
- First observed: 2026-05-18
- Area: fixture skill
- Severity: {severity}

## Signal

The fixture workflow gap was observed and needs triage.

## Evidence

- Raw record: `{raw_record}`
- Summary: fixture evidence summary
{evidence_extra.rstrip()}

## Impact

Future agents need a retained tracker for this gap.

## Current Workaround

Use the documented manual workaround.

## Promotion Criteria

Promote after a durable fix and validation are linked.

## Next Action

{next_action}
""",
        encoding="utf-8",
    )


def write_skill_usage_record(record_dir: Path) -> Path:
    record_dir.mkdir(parents=True, exist_ok=True)
    record_file = record_dir / "skill-usage.record.json"
    record_file.write_text(
        json.dumps(
            {
                "schema": "skill-usage.record.v1",
                "skill": "skills/workflows/mr/gitlab/deliver-gitlab-mr",
                "started_at": "2026-05-18T07:00:00Z",
                "cwd": "/tmp/project",
                "trigger": "user_explicit",
                "intent": "deliver MR",
                "inputs": {
                    "user_request_summary": "Deliver a GitLab MR",
                    "referenced_files": [],
                    "external_sources": [],
                },
                "outcome": {
                    "status": "fail",
                    "summary": "Pipeline status parsing failed.",
                },
                "failures": [
                    {
                        "phase": "validation",
                        "classification": "script_bug",
                        "symptom": "Pipeline status parsing failed. SECRET_TOKEN_SHOULD_NOT_COPY",
                        "diagnosis": "The script did not read pipeline.status.",
                        "handling": "Recorded an inbox entry.",
                        "result": "blocked",
                    }
                ],
                "artifacts": [],
                "linked_records": [],
                "validation": [],
                "follow_up": [],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return record_file


def test_workflows_heuristic_system_heuristic_error_inbox_contract() -> None:
    assert_skill_contract(skill_root())


def test_workflows_heuristic_system_heuristic_error_inbox_entrypoints_exist() -> None:
    assert_entrypoints_exist(skill_root(), ["scripts/heuristic-error-inbox.sh"])


def test_heuristic_error_inbox_help_lists_commands() -> None:
    proc = run_script("--help")

    assert proc.returncode == 0
    assert "heuristic-error-inbox.sh <list|verify|new|set-status|archive>" in proc.stdout
    assert "--format text|json" in proc.stdout


def test_heuristic_error_inbox_verify_valid_entry(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "fixture-gap.md"
    write_entry(entry)

    proc = run_script("verify", str(entry), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["fields"]["status"] == "open"
    assert payload["fields"]["severity"] == "medium"


def test_heuristic_error_inbox_verify_rejects_invalid_status(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "bad-status.md"
    write_entry(entry, status="done")

    proc = run_script("verify", str(entry), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert payload["ok"] is False
    assert any("invalid status" in item["message"] for item in payload["violations"])


def test_heuristic_error_inbox_verify_rejects_missing_evidence(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "missing-evidence.md"
    write_entry(entry)
    entry.write_text(entry.read_text(encoding="utf-8").replace("- Raw record: `out/projects/example/skill-usage.record.json`\n", ""))

    proc = run_script("verify", str(entry), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert any("missing raw evidence pointer" in item["message"] for item in payload["violations"])


def test_heuristic_error_inbox_verify_detects_duplicates(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    first = inbox / "fixture-gap.md"
    second = inbox / "fixture-gap-copy.md"
    write_entry(first, title="Duplicate Gap", raw_record="out/projects/shared/skill-usage.record.json")
    write_entry(second, title="Duplicate Gap", raw_record="out/projects/shared/skill-usage.record.json")

    proc = run_script("verify", str(first), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert payload["duplicates"]
    assert any("duplicate" in item["message"] for item in payload["violations"])


def test_heuristic_error_inbox_list_outputs_json(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    write_entry(inbox / "fixture-gap.md", status="triaged", severity="high")

    proc = run_script("list", "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["entries"][0]["status"] == "triaged"
    assert payload["entries"][0]["severity"] == "high"
    assert payload["entries"][0]["archived"] is False


def test_heuristic_error_inbox_list_excludes_archived_by_default(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    archive = inbox / "archive" / "2026"
    archive.mkdir(parents=True)
    inbox.mkdir(parents=True, exist_ok=True)
    write_entry(inbox / "active-gap.md", status="open")
    write_entry(archive / "archived-gap.md", status="promoted", next_action="None. Done.")

    active_proc = run_script("list", "--inbox-dir", str(inbox), "--format", "json")
    archived_proc = run_script("list", "--inbox-dir", str(inbox), "--include-archived", "--format", "json")

    assert active_proc.returncode == 0, active_proc.stderr
    assert archived_proc.returncode == 0, archived_proc.stderr
    active_payload = json.loads(active_proc.stdout)
    archived_payload = json.loads(archived_proc.stdout)
    assert [Path(item["path"]).name for item in active_payload["entries"]] == ["active-gap.md"]
    assert {Path(item["path"]).name for item in archived_payload["entries"]} == {"active-gap.md", "archived-gap.md"}
    archived_item = next(item for item in archived_payload["entries"] if Path(item["path"]).name == "archived-gap.md")
    assert archived_item["archived"] is True


def test_heuristic_error_inbox_new_from_skill_usage_redacts_raw_details(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    record_dir = tmp_path / "out" / "skill-usage"
    write_skill_usage_record(record_dir)

    proc = run_script(
        "new",
        "--from-skill-usage",
        str(record_dir),
        "--slug",
        "pipeline-status-gap",
        "--out-dir",
        str(inbox),
        "--severity",
        "high",
        "--format",
        "json",
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    entry = Path(payload["path"])
    text = entry.read_text(encoding="utf-8")
    assert "- Status: open" in text
    assert "- Severity: high" in text
    assert "skill-usage.record.json" in text
    assert "SECRET_TOKEN_SHOULD_NOT_COPY" not in text


def test_heuristic_error_inbox_set_status_updates_status_and_link(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "fixture-gap.md"
    write_entry(entry)

    proc = run_script(
        "set-status",
        str(entry),
        "--status",
        "planned",
        "--link",
        "docs/plans/example/example-plan.md",
        "--format",
        "json",
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["status"] == "planned"
    text = entry.read_text(encoding="utf-8")
    assert "- Status: planned" in text
    assert "docs/plans/example/example-plan.md" in text


def test_heuristic_error_inbox_archive_dry_run_reports_destination(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "fixture-gap.md"
    write_entry(entry, status="promoted", next_action="None. Fixed and validated.")

    proc = run_script(
        "archive",
        str(entry),
        "--inbox-dir",
        str(inbox),
        "--date",
        "2026-05-18",
        "--dry-run",
        "--format",
        "json",
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["ok"] is True
    assert payload["dry_run"] is True
    assert payload["archive_ready"] is True
    assert payload["destination"].endswith("archive/2026/fixture-gap.md")
    assert entry.exists()


def test_heuristic_error_inbox_archive_moves_promoted_entry(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "fixture-gap.md"
    write_entry(entry, status="promoted", next_action="None. Fixed and validated.")

    proc = run_script(
        "archive",
        str(entry),
        "--inbox-dir",
        str(inbox),
        "--date",
        "2026-05-18",
        "--reason",
        "Fixed and compressed into docs.",
        "--format",
        "json",
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    destination = Path(payload["destination"])
    assert payload["ok"] is True
    assert entry.exists() is False
    assert destination.exists()
    text = destination.read_text(encoding="utf-8")
    assert "## Archive" in text
    assert "- Archived: 2026-05-18" in text
    assert "- Reason: Fixed and compressed into docs." in text


def test_heuristic_error_inbox_archive_accepts_wontfix_entry_with_link(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "accepted-risk.md"
    write_entry(
        entry,
        status="wontfix",
        evidence_extra="",
        next_action="None. Risk accepted.",
    )

    proc = run_script(
        "archive",
        str(entry),
        "--inbox-dir",
        str(inbox),
        "--date",
        "2026-05-18",
        "--link",
        "docs/accepted-risk.md",
        "--format",
        "json",
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    destination = Path(payload["destination"])
    assert destination.exists()
    text = destination.read_text(encoding="utf-8")
    assert "- Durable link: `docs/accepted-risk.md`" in text


def test_heuristic_error_inbox_archive_rejects_active_status(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "active-gap.md"
    write_entry(entry, status="planned")

    proc = run_script("archive", str(entry), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert payload["ok"] is False
    assert any("closed status" in item["message"] for item in payload["violations"])
    assert entry.exists()


def test_heuristic_error_inbox_archive_rejects_actionable_next_action(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "actionable-gap.md"
    write_entry(entry, status="promoted", next_action="Create a follow-up plan.")

    proc = run_script("archive", str(entry), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert any("Next Action" in item["message"] for item in payload["violations"])


def test_heuristic_error_inbox_archive_rejects_missing_durable_link(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    inbox.mkdir(parents=True)
    entry = inbox / "missing-link.md"
    write_entry(entry, status="promoted", evidence_extra="", next_action="None. Fixed.")

    proc = run_script("archive", str(entry), "--inbox-dir", str(inbox), "--format", "json")

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert any("durable outcome link" in item["message"] for item in payload["violations"])


def test_heuristic_error_inbox_archive_rejects_duplicate_destination(tmp_path: Path) -> None:
    inbox = tmp_path / "heuristic-system" / "error-inbox"
    archive = inbox / "archive" / "2026"
    archive.mkdir(parents=True)
    entry = inbox / "fixture-gap.md"
    write_entry(entry, status="promoted", next_action="None. Fixed.")
    write_entry(archive / "fixture-gap.md", status="promoted", next_action="None. Already archived.")

    proc = run_script(
        "archive",
        str(entry),
        "--inbox-dir",
        str(inbox),
        "--date",
        "2026-05-18",
        "--format",
        "json",
    )

    assert proc.returncode == 1
    payload = json.loads(proc.stdout)
    assert any("archive target already exists" in item["message"] for item in payload["violations"])
