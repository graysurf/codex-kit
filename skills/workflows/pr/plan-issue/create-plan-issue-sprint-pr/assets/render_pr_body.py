#!/usr/bin/env python3
"""Render a plan-issue sprint PR body.

The rendered body matches the sprint PR schema enforced by the
issue-pr-review validator:

- `## Summary`
- `## Scope`
- `## Testing`
- `## Issue`

This module intentionally does no GitHub I/O. The shell entrypoint handles
worktree validation and optional `gh pr create`.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REJECTED_PLACEHOLDERS: tuple[str, ...] = (
    "<...>",
    "TODO",
    "TBD",
    "#<number>",
    "not run (reason)",
    "<command> (pass)",
)
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^<>\n]+>")
TASK_ID_RE = re.compile(r"^S(?P<sprint>[0-9]+)T[0-9]+")


@dataclass(frozen=True)
class DispatchFacts:
    task_ids: list[str]
    sprint_number: int
    branch: str
    base_branch: str
    worktree: str


@dataclass(frozen=True)
class SprintPRBodySpec:
    sprint_number: int
    issue_number: int
    task_ids: list[str]
    summary_bullets: list[str]
    scope_bullets: list[str]
    testing_bullets: list[str]
    repo_slug: str | None = None
    title: str | None = None
    extra_summary_bullets: list[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> SprintPRBodySpec:
        try:
            sprint_number = int(data["sprint_number"])
            issue_number = int(data["issue_number"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError(f"sprint_number / issue_number must be ints: {exc}") from exc

        task_ids = _string_list(data.get("task_ids"))
        summary_bullets = _string_list(data.get("summary_bullets"))
        scope_bullets = _string_list(data.get("scope_bullets"))
        testing_bullets = _string_list(data.get("testing_bullets"))

        if not task_ids:
            raise ValueError("task_ids must be a non-empty list")
        if not summary_bullets:
            raise ValueError("summary_bullets must be a non-empty list")
        if not scope_bullets:
            raise ValueError("scope_bullets must be a non-empty list")
        if not testing_bullets:
            raise ValueError("testing_bullets must be a non-empty list")

        return cls(
            sprint_number=sprint_number,
            issue_number=issue_number,
            task_ids=task_ids,
            summary_bullets=summary_bullets,
            scope_bullets=scope_bullets,
            testing_bullets=testing_bullets,
            repo_slug=_optional_string(data.get("repo_slug")),
            title=_optional_string(data.get("title")),
            extra_summary_bullets=_string_list(data.get("extra_summary_bullets")),
        )


def _string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, list):
        raise ValueError("expected a list of strings")
    return [str(item).strip() for item in value if str(item).strip()]


def _optional_string(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def load_dispatch_facts(path: Path) -> DispatchFacts:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"dispatch record not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"dispatch record is not valid JSON: {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ValueError("dispatch record must be a JSON object")

    task_ids = _dispatch_task_ids(data)
    if not task_ids:
        raise ValueError("dispatch record must include task_id or task_ids")

    first_task = task_ids[0]
    match = TASK_ID_RE.match(first_task)
    if not match:
        raise ValueError(f"cannot derive sprint number from task id: {first_task}")

    branch = _optional_string(data.get("branch"))
    base_branch = _optional_string(data.get("base_branch"))
    worktree = _optional_string(data.get("worktree_abs_path")) or _optional_string(data.get("worktree"))

    if not branch:
        raise ValueError("dispatch record missing branch")
    if not base_branch:
        raise ValueError("dispatch record missing base_branch")
    if not worktree:
        raise ValueError("dispatch record missing worktree_abs_path/worktree")

    return DispatchFacts(
        task_ids=task_ids,
        sprint_number=int(match.group("sprint")),
        branch=branch,
        base_branch=base_branch,
        worktree=worktree,
    )


def _dispatch_task_ids(data: dict[str, Any]) -> list[str]:
    candidates: list[str] = []
    for key in ("task_ids", "lane_task_ids", "sibling_task_ids"):
        candidates.extend(_string_list(data.get(key)))
    task_id = _optional_string(data.get("task_id"))
    if task_id:
        candidates.insert(0, task_id)

    seen: set[str] = set()
    ordered: list[str] = []
    for item in candidates:
        if item not in seen:
            seen.add(item)
            ordered.append(item)
    return ordered


def _bullet(text: str) -> str:
    stripped = text.lstrip("-* ").rstrip()
    if not stripped:
        raise ValueError("bullet text is empty after stripping")
    return f"- {stripped}"


def _scan_placeholders(body: str) -> list[str]:
    findings: list[str] = []
    for needle in REJECTED_PLACEHOLDERS:
        if needle in body:
            findings.append(needle)
    for match in ANGLE_PLACEHOLDER_RE.findall(body):
        if match not in findings:
            findings.append(match)
    return findings


def render_body(spec: SprintPRBodySpec) -> str:
    summary = [*spec.summary_bullets, *spec.extra_summary_bullets]
    sections = [
        "## Summary\n\n" + "\n".join(_bullet(item) for item in summary),
        "## Scope\n\n"
        + "\n".join(
            [
                f"- Sprint {spec.sprint_number} task IDs: {', '.join(spec.task_ids)}.",
                *[_bullet(item) for item in spec.scope_bullets],
            ]
        ),
        "## Testing\n\n" + "\n".join(_bullet(item) for item in spec.testing_bullets),
        f"## Issue\n\n- #{spec.issue_number}",
    ]
    body = "\n\n".join(sections) + "\n"
    findings = _scan_placeholders(body)
    if findings:
        raise ValueError(
            "rendered body still contains validator-rejected placeholder(s): "
            + ", ".join(repr(item) for item in findings)
        )
    return body


def derive_title(spec: SprintPRBodySpec) -> str:
    if spec.title:
        return spec.title
    repo_prefix = f"{spec.repo_slug}: " if spec.repo_slug else ""
    return f"{repo_prefix}Sprint {spec.sprint_number} delivery (issue #{spec.issue_number})"


def load_spec(args: argparse.Namespace) -> SprintPRBodySpec:
    dispatch_facts = load_dispatch_facts(Path(args.dispatch_record)) if args.dispatch_record else None

    if args.spec:
        if any((args.summary, args.scope, args.testing, args.task_ids)):
            raise ValueError("--spec cannot be combined with per-field body flags")
        payload = json.load(sys.stdin) if args.spec == "-" else json.loads(Path(args.spec).read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("spec JSON must be an object")
    else:
        payload = {
            "summary_bullets": args.summary or [],
            "scope_bullets": args.scope or [],
            "testing_bullets": args.testing or [],
            "task_ids": args.task_ids or [],
        }

    if dispatch_facts:
        payload.setdefault("sprint_number", dispatch_facts.sprint_number)
        if not payload.get("task_ids"):
            payload["task_ids"] = dispatch_facts.task_ids

    payload["issue_number"] = args.issue if args.issue is not None else payload.get("issue_number")
    if args.sprint is not None:
        payload["sprint_number"] = args.sprint
    if args.repo_slug:
        payload["repo_slug"] = args.repo_slug
    if args.title:
        payload["title"] = args.title

    return SprintPRBodySpec.from_dict(payload)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dispatch-record", help="Path to dispatch-<TASK_ID>.json.")
    parser.add_argument("--spec", help="Path to JSON spec, or '-' for stdin.")
    parser.add_argument("--sprint", type=int, help="Override sprint number.")
    parser.add_argument("--issue", type=int, help="Plan issue number.")
    parser.add_argument("--task-ids", action="append", help="Task ID. Repeatable.")
    parser.add_argument("--summary", action="append", help="Summary bullet. Repeatable.")
    parser.add_argument("--scope", action="append", help="Scope bullet. Repeatable.")
    parser.add_argument("--testing", action="append", help="Testing bullet. Repeatable.")
    parser.add_argument("--repo-slug", help="Optional owner/repo for default title prefix.")
    parser.add_argument("--title", help="Optional title override.")
    parser.add_argument("--print-title", action="store_true", help="Print title marker before body.")
    parser.add_argument("--print-dispatch", action="store_true", help="Print dispatch facts as JSON and exit.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    try:
        if args.print_dispatch:
            if not args.dispatch_record:
                raise ValueError("--print-dispatch requires --dispatch-record")
            facts = load_dispatch_facts(Path(args.dispatch_record))
            print(
                json.dumps(
                    {
                        "task_ids": facts.task_ids,
                        "sprint_number": facts.sprint_number,
                        "branch": facts.branch,
                        "base_branch": facts.base_branch,
                        "worktree": facts.worktree,
                    },
                    sort_keys=True,
                )
            )
            return 0

        spec = load_spec(args)
        body = render_body(spec)
        if args.print_title:
            print(derive_title(spec))
            print("---title-end---")
        sys.stdout.write(body)
        return 0
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
