#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from shutil import which
from typing import Any, Iterable, Sequence

FAILURE_CONCLUSIONS = {
    "failure",
    "cancelled",
    "timed_out",
    "action_required",
}

FAILURE_STATES = {
    "failure",
    "error",
    "cancelled",
    "timed_out",
    "action_required",
}

FAILURE_BUCKETS = {"fail"}

FAILURE_MARKERS = (
    "error",
    "fail",
    "failed",
    "traceback",
    "exception",
    "assert",
    "panic",
    "fatal",
    "timeout",
    "segmentation fault",
)

DEFAULT_MAX_LINES = 160
DEFAULT_CONTEXT_LINES = 30
DEFAULT_RUN_LIMIT = 20
PENDING_LOG_MARKERS = (
    "still in progress",
    "log will be available when it is complete",
)


@dataclass(frozen=True)
class Target:
    kind: str  # "pr" or "ref"
    value: str
    ref_type: str | None = None  # "branch" or "commit"


class GhResult:
    def __init__(self, returncode: int, stdout: str, stderr: str):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def run_gh_command(args: Sequence[str], cwd: Path) -> GhResult:
    process = subprocess.run(
        ["gh", *args],
        cwd=cwd,
        text=True,
        capture_output=True,
    )
    return GhResult(process.returncode, process.stdout, process.stderr)


def run_gh_command_raw(args: Sequence[str], cwd: Path) -> tuple[int, bytes, str]:
    process = subprocess.run(
        ["gh", *args],
        cwd=cwd,
        capture_output=True,
    )
    stderr = process.stderr.decode(errors="replace")
    return process.returncode, process.stdout, stderr


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Inspect failing GitHub Actions checks for a PR or branch/commit, fetch logs, "
            "and extract a failure snippet."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--repo", default=".", help="Path inside the target Git repository.")
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--pr", default=None, help="PR number or URL.")
    target.add_argument("--ref", default=None, help="Branch name or commit SHA to inspect.")
    target.add_argument("--branch", default=None, help="Branch name to inspect (alias of --ref).")
    target.add_argument("--commit", default=None, help="Commit SHA to inspect (alias of --ref).")
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_RUN_LIMIT,
        help="Max workflow runs to inspect when using branch/commit targets.",
    )
    parser.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES)
    parser.add_argument("--context", type=int, default=DEFAULT_CONTEXT_LINES)
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text output.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = find_git_root(Path(args.repo))
    if repo_root is None:
        print("Error: not inside a Git repository.", file=sys.stderr)
        return 1

    if not ensure_gh_available(repo_root):
        return 1

    target = resolve_target(args, repo_root)
    if target is None:
        return 1

    if target.kind == "pr":
        checks = fetch_pr_checks(target.value, repo_root)
    else:
        checks = fetch_runs_for_ref(
            target.value,
            target.ref_type or "branch",
            repo_root,
            max(1, args.limit),
        )

    if checks is None:
        return 1

    if not checks:
        print(f"{format_target_label(target)}: no checks found.")
        return 0

    failing = [c for c in checks if is_failing(c)]
    if not failing:
        print(f"{format_target_label(target)}: no failing checks detected.")
        return 0

    results = []
    for check in failing:
        results.append(
            analyze_check(
                check,
                repo_root=repo_root,
                max_lines=max(1, args.max_lines),
                context=max(1, args.context),
            )
        )

    if args.json:
        print(json.dumps(build_payload(target, results), indent=2))
    else:
        render_results(target, results)

    return 1


def find_git_root(start: Path) -> Path | None:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=start,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return Path(result.stdout.strip())


def ensure_gh_available(repo_root: Path) -> bool:
    if which("gh") is None:
        print("Error: gh is not installed or not on PATH.", file=sys.stderr)
        return False
    result = run_gh_command(["auth", "status"], cwd=repo_root)
    if result.returncode == 0:
        return True
    message = (result.stderr or result.stdout or "").strip()
    print(message or "Error: gh not authenticated.", file=sys.stderr)
    return False


def resolve_target(args: argparse.Namespace, repo_root: Path) -> Target | None:
    if args.pr:
        return Target("pr", str(args.pr))

    ref_value, ref_type = resolve_ref_from_args(args)
    if ref_value:
        return Target("ref", ref_value, ref_type)

    pr_value = resolve_current_pr(repo_root)
    if pr_value:
        return Target("pr", pr_value)

    fallback_ref, fallback_type = resolve_current_ref(repo_root)
    if fallback_ref:
        return Target("ref", fallback_ref, fallback_type)

    print("Error: unable to resolve PR or branch/commit target.", file=sys.stderr)
    return None


def resolve_ref_from_args(args: argparse.Namespace) -> tuple[str | None, str | None]:
    if args.branch:
        return str(args.branch), "branch"
    if args.commit:
        return str(args.commit), "commit"
    if args.ref:
        ref = str(args.ref)
        ref_type = "commit" if is_probable_sha(ref) else "branch"
        return ref, ref_type
    return None, None


def resolve_current_pr(repo_root: Path) -> str | None:
    result = run_gh_command(["pr", "view", "--json", "number"], cwd=repo_root)
    if result.returncode != 0:
        return None
    try:
        data = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return None
    number = data.get("number")
    if not number:
        return None
    return str(number)


def resolve_current_ref(repo_root: Path) -> tuple[str | None, str | None]:
    branch = current_branch(repo_root)
    if branch and branch != "HEAD":
        return branch, "branch"
    sha = current_commit(repo_root)
    if sha:
        return sha, "commit"
    return None, None


def current_branch(repo_root: Path) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=repo_root,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def current_commit(repo_root: Path) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=repo_root,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def is_probable_sha(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-fA-F]{7,40}", value))


def fetch_pr_checks(pr_value: str, repo_root: Path) -> list[dict[str, Any]] | None:
    primary_fields = ["name", "state", "conclusion", "detailsUrl", "startedAt", "completedAt"]
    result = run_gh_command(
        ["pr", "checks", pr_value, "--json", ",".join(primary_fields)],
        cwd=repo_root,
    )
    if result.returncode != 0:
        message = "\n".join(filter(None, [result.stderr, result.stdout])).strip()
        available_fields = parse_available_fields(message)
        if available_fields:
            fallback_fields = [
                "name",
                "state",
                "bucket",
                "link",
                "startedAt",
                "completedAt",
                "workflow",
            ]
            selected_fields = [field for field in fallback_fields if field in available_fields]
            if not selected_fields:
                print("Error: no usable fields available for gh pr checks.", file=sys.stderr)
                return None
            result = run_gh_command(
                ["pr", "checks", pr_value, "--json", ",".join(selected_fields)],
                cwd=repo_root,
            )
            if result.returncode != 0:
                message = (result.stderr or result.stdout or "").strip()
                print(message or "Error: gh pr checks failed.", file=sys.stderr)
                return None
        else:
            print(message or "Error: gh pr checks failed.", file=sys.stderr)
            return None
    try:
        data = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        print("Error: unable to parse checks JSON.", file=sys.stderr)
        return None
    if not isinstance(data, list):
        print("Error: unexpected checks JSON shape.", file=sys.stderr)
        return None
    return data


def fetch_runs_for_ref(
    ref_value: str,
    ref_type: str,
    repo_root: Path,
    limit: int,
) -> list[dict[str, Any]] | None:
    fields = [
        "databaseId",
        "name",
        "status",
        "conclusion",
        "url",
        "headBranch",
        "headSha",
        "workflowName",
    ]
    command = ["run", "list", "--json", ",".join(fields), "--limit", str(limit)]
    if ref_type == "commit":
        command += ["--commit", ref_value]
    else:
        command += ["--branch", ref_value]
    result = run_gh_command(command, cwd=repo_root)
    if result.returncode != 0:
        message = (result.stderr or result.stdout or "").strip()
        print(message or "Error: gh run list failed.", file=sys.stderr)
        return None
    try:
        runs = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        print("Error: unable to parse workflow runs JSON.", file=sys.stderr)
        return None
    if not isinstance(runs, list):
        print("Error: unexpected workflow runs JSON shape.", file=sys.stderr)
        return None

    normalized: list[dict[str, Any]] = []
    for run in runs:
        run_id = run.get("databaseId")
        name = run.get("name") or run.get("workflowName") or ""
        normalized.append(
            {
                "name": name,
                "state": run.get("status"),
                "conclusion": run.get("conclusion"),
                "detailsUrl": run.get("url") or "",
                "runId": str(run_id) if run_id else None,
            }
        )
    return normalized


def is_failing(check: dict[str, Any]) -> bool:
    conclusion = normalize_field(check.get("conclusion"))
    if conclusion in FAILURE_CONCLUSIONS:
        return True
    state = normalize_field(check.get("state") or check.get("status"))
    if state in FAILURE_STATES:
        return True
    bucket = normalize_field(check.get("bucket"))
    return bucket in FAILURE_BUCKETS


def analyze_check(
    check: dict[str, Any],
    repo_root: Path,
    max_lines: int,
    context: int,
) -> dict[str, Any]:
    url = check.get("detailsUrl") or check.get("link") or ""
    run_id = check.get("runId")
    if run_id is not None:
        run_id = str(run_id)
    else:
        run_id = extract_run_id(url)
    job_id = check.get("jobId")
    if job_id is not None:
        job_id = str(job_id)
    else:
        job_id = extract_job_id(url)
    base: dict[str, Any] = {
        "name": check.get("name", ""),
        "detailsUrl": url,
        "runId": run_id,
        "jobId": job_id,
    }

    if run_id is None:
        base["status"] = "external"
        base["note"] = "No GitHub Actions run id detected in detailsUrl."
        return base

    metadata = fetch_run_metadata(run_id, repo_root)
    log_text, log_error, log_status = fetch_check_log(
        run_id=run_id,
        job_id=job_id,
        repo_root=repo_root,
    )

    if log_status == "pending":
        base["status"] = "log_pending"
        base["note"] = log_error or "Logs are not available yet."
        if metadata:
            base["run"] = metadata
        return base

    if log_error:
        base["status"] = "log_unavailable"
        base["error"] = log_error
        if metadata:
            base["run"] = metadata
        return base

    snippet = extract_failure_snippet(log_text, max_lines=max_lines, context=context)
    base["status"] = "ok"
    base["run"] = metadata or {}
    base["logSnippet"] = snippet
    base["logTail"] = tail_lines(log_text, max_lines)
    return base


def extract_run_id(url: str) -> str | None:
    if not url:
        return None
    for pattern in (r"/actions/runs/(\d+)", r"/runs/(\d+)"):
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def extract_job_id(url: str) -> str | None:
    if not url:
        return None
    match = re.search(r"/actions/runs/\d+/job/(\d+)", url)
    if match:
        return match.group(1)
    match = re.search(r"/job/(\d+)", url)
    if match:
        return match.group(1)
    return None


def fetch_run_metadata(run_id: str, repo_root: Path) -> dict[str, Any] | None:
    fields = [
        "conclusion",
        "status",
        "workflowName",
        "name",
        "event",
        "headBranch",
        "headSha",
        "url",
    ]
    result = run_gh_command(["run", "view", run_id, "--json", ",".join(fields)], cwd=repo_root)
    if result.returncode != 0:
        return None
    try:
        data = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict):
        return None
    return data


def fetch_check_log(
    run_id: str,
    job_id: str | None,
    repo_root: Path,
) -> tuple[str, str, str]:
    log_text, log_error = fetch_run_log(run_id, repo_root)
    if not log_error:
        return log_text, "", "ok"

    if is_log_pending_message(log_error) and job_id:
        job_log, job_error = fetch_job_log(job_id, repo_root)
        if job_log:
            return job_log, "", "ok"
        if job_error and is_log_pending_message(job_error):
            return "", job_error, "pending"
        if job_error:
            return "", job_error, "error"
        return "", log_error, "pending"

    if is_log_pending_message(log_error):
        return "", log_error, "pending"

    return "", log_error, "error"


def fetch_run_log(run_id: str, repo_root: Path) -> tuple[str, str]:
    result = run_gh_command(["run", "view", run_id, "--log"], cwd=repo_root)
    if result.returncode != 0:
        error = (result.stderr or result.stdout or "").strip()
        return "", error or "gh run view failed"
    return result.stdout, ""


def fetch_job_log(job_id: str, repo_root: Path) -> tuple[str, str]:
    repo_slug = fetch_repo_slug(repo_root)
    if not repo_slug:
        return "", "Error: unable to resolve repository name for job logs."
    endpoint = f"/repos/{repo_slug}/actions/jobs/{job_id}/logs"
    returncode, stdout_bytes, stderr = run_gh_command_raw(["api", endpoint], cwd=repo_root)
    if returncode != 0:
        message = (stderr or stdout_bytes.decode(errors="replace")).strip()
        return "", message or "gh api job logs failed"
    if is_zip_payload(stdout_bytes):
        return "", "Job logs returned a zip archive; unable to parse."
    return stdout_bytes.decode(errors="replace"), ""


def fetch_repo_slug(repo_root: Path) -> str | None:
    result = run_gh_command(["repo", "view", "--json", "nameWithOwner"], cwd=repo_root)
    if result.returncode != 0:
        return None
    try:
        data = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return None
    name_with_owner = data.get("nameWithOwner")
    if not name_with_owner:
        return None
    return str(name_with_owner)


def normalize_field(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip().lower()


def parse_available_fields(message: str) -> list[str]:
    if "Available fields:" not in message:
        return []
    fields: list[str] = []
    collecting = False
    for line in message.splitlines():
        if "Available fields:" in line:
            collecting = True
            continue
        if not collecting:
            continue
        field = line.strip()
        if not field:
            continue
        fields.append(field)
    return fields


def is_log_pending_message(message: str) -> bool:
    lowered = message.lower()
    return any(marker in lowered for marker in PENDING_LOG_MARKERS)


def is_zip_payload(payload: bytes) -> bool:
    return payload.startswith(b"PK")


def extract_failure_snippet(log_text: str, max_lines: int, context: int) -> str:
    lines = log_text.splitlines()
    if not lines:
        return ""

    marker_index = find_failure_index(lines)
    if marker_index is None:
        return "\n".join(lines[-max_lines:])

    start = max(0, marker_index - context)
    end = min(len(lines), marker_index + context)
    window = lines[start:end]
    if len(window) > max_lines:
        window = window[-max_lines:]
    return "\n".join(window)


def find_failure_index(lines: Sequence[str]) -> int | None:
    for idx in range(len(lines) - 1, -1, -1):
        lowered = lines[idx].lower()
        if any(marker in lowered for marker in FAILURE_MARKERS):
            return idx
    return None


def tail_lines(text: str, max_lines: int) -> str:
    if max_lines <= 0:
        return ""
    lines = text.splitlines()
    return "\n".join(lines[-max_lines:])


def render_results(target: Target, results: Iterable[dict[str, Any]]) -> None:
    results_list = list(results)
    print(f"{format_target_label(target)}: {len(results_list)} failing checks analyzed.")
    for result in results_list:
        print("-" * 60)
        print(f"Check: {result.get('name', '')}")
        if result.get("detailsUrl"):
            print(f"Details: {result['detailsUrl']}")
        run_id = result.get("runId")
        if run_id:
            print(f"Run ID: {run_id}")
        job_id = result.get("jobId")
        if job_id:
            print(f"Job ID: {job_id}")
        status = result.get("status", "unknown")
        print(f"Status: {status}")

        run_meta = result.get("run", {})
        if run_meta:
            branch = run_meta.get("headBranch", "")
            sha = (run_meta.get("headSha") or "")[:12]
            workflow = run_meta.get("workflowName") or run_meta.get("name") or ""
            conclusion = run_meta.get("conclusion") or run_meta.get("status") or ""
            print(f"Workflow: {workflow} ({conclusion})")
            if branch or sha:
                print(f"Branch/SHA: {branch} {sha}")
            if run_meta.get("url"):
                print(f"Run URL: {run_meta['url']}")

        if result.get("note"):
            print(f"Note: {result['note']}")

        if result.get("error"):
            print(f"Error fetching logs: {result['error']}")
            continue

        snippet = result.get("logSnippet") or ""
        if snippet:
            print("Failure snippet:")
            print(indent_block(snippet, prefix="  "))
        else:
            print("No snippet available.")
    print("-" * 60)


def build_payload(target: Target, results: Iterable[dict[str, Any]]) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "target": {"type": target.kind, "value": target.value},
        "results": list(results),
    }
    if target.kind == "pr":
        payload["pr"] = target.value
    else:
        payload["ref"] = target.value
        payload["refType"] = target.ref_type
        payload["target"]["refType"] = target.ref_type
    return payload


def format_target_label(target: Target) -> str:
    if target.kind == "pr":
        return f"PR #{target.value}"
    if target.ref_type == "commit":
        return f"Commit {target.value[:12]}"
    return f"Branch {target.value}"


def indent_block(text: str, prefix: str = "  ") -> str:
    return "\n".join(f"{prefix}{line}" for line in text.splitlines())


if __name__ == "__main__":
    raise SystemExit(main())
