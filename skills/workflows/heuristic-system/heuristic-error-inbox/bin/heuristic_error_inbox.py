from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


VALID_STATUSES = {"open", "triaged", "planned", "promoted", "wontfix"}
VALID_SEVERITIES = {"low", "medium", "high"}
REQUIRED_SECTIONS = (
    "Status",
    "Signal",
    "Evidence",
    "Impact",
    "Current Workaround",
    "Promotion Criteria",
    "Next Action",
)
STATUS_FIELDS = ("Status", "First observed", "Area", "Severity")
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


@dataclass(frozen=True)
class Violation:
    kind: str
    message: str

    def to_json(self) -> dict[str, str]:
        return {"kind": self.kind, "message": self.message}


class CommandError(Exception):
    def __init__(self, message: str, *, exit_code: int = 1) -> None:
        super().__init__(message)
        self.exit_code = exit_code


def repo_root() -> Path:
    return Path.cwd()


def default_inbox_dir() -> Path:
    return repo_root() / "heuristic-system" / "error-inbox"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise CommandError(f"failed to read {path}: {exc}") from exc


def write_text(path: Path, text: str) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        raise CommandError(f"failed to write {path}: {exc}") from exc


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().casefold())


def title_from_slug(slug: str) -> str:
    return " ".join(part.capitalize() for part in slug.split("-"))


def today_from_record(record: dict[str, Any]) -> str:
    started = str(record.get("started_at") or "")
    if re.match(r"^\d{4}-\d{2}-\d{2}", started):
        return started[:10]
    return dt.date.today().isoformat()


def redact_summary(value: str) -> str:
    patterns = (
        r"sk-[A-Za-z0-9_-]+",
        r"(?i)\b(secret|token|password|credential)[A-Za-z0-9_:=/-]*",
    )
    redacted = value
    for pattern in patterns:
        redacted = re.sub(pattern, "[redacted]", redacted)
    return redacted.strip()


def strip_inline_code(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value.startswith("`") and value.endswith("`"):
        return value[1:-1].strip()
    return value


def extract_title(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def extract_sections(text: str) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in text.splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append(line)
    return {key: "\n".join(lines).strip() for key, lines in sections.items()}


def extract_status_fields(status_section: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in status_section.splitlines():
        match = re.match(r"^-\s+([^:]+):\s*(.*)$", line.strip())
        if not match:
            continue
        key = match.group(1).strip()
        if key in STATUS_FIELDS:
            fields[key.lower().replace(" ", "_")] = strip_inline_code(match.group(2))
    return fields


def extract_raw_records(evidence_section: str) -> list[str]:
    records: list[str] = []
    for line in evidence_section.splitlines():
        match = re.match(r"^-\s+Raw record:\s*(.+?)\s*$", line.strip())
        if match:
            value = strip_inline_code(match.group(1))
            if value:
                records.append(value)
    return records


def parse_entry(path: Path) -> dict[str, Any]:
    text = read_text(path)
    sections = extract_sections(text)
    fields = extract_status_fields(sections.get("Status", ""))
    raw_records = extract_raw_records(sections.get("Evidence", ""))
    return {
        "path": path,
        "title": extract_title(text),
        "sections": sections,
        "fields": fields,
        "raw_records": raw_records,
    }


def entry_json(parsed: dict[str, Any]) -> dict[str, Any]:
    fields = parsed["fields"]
    return {
        "path": str(parsed["path"]),
        "title": parsed["title"],
        "status": fields.get("status", ""),
        "first_observed": fields.get("first_observed", ""),
        "area": fields.get("area", ""),
        "severity": fields.get("severity", ""),
        "raw_records": parsed["raw_records"],
    }


def iter_entries(inbox_dir: Path) -> list[Path]:
    if not inbox_dir.exists():
        return []
    return sorted(
        path
        for path in inbox_dir.glob("*.md")
        if path.is_file() and path.name != "README.md"
    )


def detect_duplicates(path: Path, parsed: dict[str, Any], inbox_dir: Path) -> list[dict[str, Any]]:
    duplicates: list[dict[str, Any]] = []
    title = normalize_text(parsed["title"])
    area = normalize_text(parsed["fields"].get("area", ""))
    raw_records = {normalize_text(item) for item in parsed["raw_records"]}
    resolved = path.resolve()

    for other in iter_entries(inbox_dir):
        if other.resolve() == resolved:
            continue
        other_parsed = parse_entry(other)
        reasons: list[str] = []
        if other.stem == path.stem:
            reasons.append("slug")
        other_title = normalize_text(other_parsed["title"])
        other_area = normalize_text(other_parsed["fields"].get("area", ""))
        if title and other_title == title and (not area or other_area == area):
            reasons.append("title")
        other_raw = {normalize_text(item) for item in other_parsed["raw_records"]}
        if raw_records and raw_records & other_raw:
            reasons.append("raw_record")
        if reasons:
            duplicates.append({"path": str(other), "reasons": sorted(set(reasons))})

    return duplicates


def verify_entry(path: Path, inbox_dir: Path | None = None) -> dict[str, Any]:
    parsed = parse_entry(path)
    violations: list[Violation] = []

    if not parsed["title"]:
        violations.append(Violation("missing_title", "missing H1 title"))

    sections = parsed["sections"]
    for section in REQUIRED_SECTIONS:
        if section not in sections:
            violations.append(Violation("missing_section", f"missing required section: {section}"))

    fields = parsed["fields"]
    for field in ("status", "first_observed", "area", "severity"):
        if not fields.get(field):
            violations.append(Violation("missing_status_field", f"missing status field: {field.replace('_', ' ')}"))

    status = fields.get("status", "")
    if status and status not in VALID_STATUSES:
        violations.append(Violation("invalid_status", f"invalid status: {status}"))

    severity = fields.get("severity", "")
    if severity and severity not in VALID_SEVERITIES:
        violations.append(Violation("invalid_severity", f"invalid severity: {severity}"))

    if not parsed["raw_records"]:
        violations.append(Violation("missing_evidence", "missing raw evidence pointer"))

    scan_dir = inbox_dir or path.parent
    duplicates = detect_duplicates(path, parsed, scan_dir)
    if duplicates:
        violations.append(Violation("duplicate_entry", "duplicate inbox entry detected"))

    return {
        "ok": not violations,
        "path": str(path),
        "title": parsed["title"],
        "fields": fields,
        "raw_records": parsed["raw_records"],
        "duplicates": duplicates,
        "violations": [item.to_json() for item in violations],
        "warnings": [],
    }


def print_payload(payload: dict[str, Any], output_format: str, *, failure_to_stderr: bool = True) -> None:
    if output_format == "json":
        print(json.dumps(payload, indent=2, sort_keys=True))
        return

    if payload.get("ok") is False:
        lines = [f"error: {item['message']}" for item in payload.get("violations", [])]
        target = sys.stderr if failure_to_stderr else sys.stdout
        print("\n".join(lines), file=target)
        return

    if "entries" in payload:
        entries = payload["entries"]
        if not entries:
            print("No heuristic error inbox entries found.")
            return
        for entry in entries:
            print(
                "\t".join(
                    [
                        entry.get("status", ""),
                        entry.get("severity", ""),
                        entry.get("area", ""),
                        entry.get("path", ""),
                        entry.get("title", ""),
                    ]
                )
            )
        return

    if "path" in payload:
        print(f"ok: {payload['path']}")


def load_skill_usage_record(record_input: Path) -> tuple[Path, dict[str, Any]]:
    record_file = record_input / "skill-usage.record.json" if record_input.is_dir() else record_input
    if not record_file.is_file():
        raise CommandError(f"missing skill usage record: {record_file}")
    try:
        record = json.loads(record_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CommandError(f"failed to read skill usage record: {exc}") from exc
    if record.get("schema") != "skill-usage.record.v1":
        raise CommandError("record schema is not skill-usage.record.v1")
    return record_file, record


def create_entry_from_skill_usage(args: argparse.Namespace) -> dict[str, Any]:
    slug = args.slug.strip()
    if not SLUG_RE.match(slug):
        raise CommandError(f"invalid slug: {slug}", exit_code=2)

    status = args.status
    severity = args.severity
    if status not in VALID_STATUSES:
        raise CommandError(f"invalid status: {status}", exit_code=2)
    if severity not in VALID_SEVERITIES:
        raise CommandError(f"invalid severity: {severity}", exit_code=2)

    out_dir = args.out_dir or default_inbox_dir()
    target = out_dir / f"{slug}.md"
    if target.exists():
        raise CommandError(f"inbox entry already exists: {target}")

    record_file, record = load_skill_usage_record(args.from_skill_usage)
    title = args.title or title_from_slug(slug)
    skill = str(record.get("skill") or "unknown skill")
    outcome = record.get("outcome") if isinstance(record.get("outcome"), dict) else {}
    outcome_status = str(outcome.get("status") or "unknown")
    outcome_summary = redact_summary(str(outcome.get("summary") or "See linked skill usage record."))
    area = args.area or skill
    first_observed = today_from_record(record)
    next_action = args.next_action or "Triage this gap and route any implementation work to a focused plan or domain workflow."

    text = f"""# {title}

## Status

- Status: {status}
- First observed: {first_observed}
- Area: {area}
- Severity: {severity}

## Signal

Skill `{skill}` ended with `{outcome_status}`. Summary: {outcome_summary}

## Evidence

- Raw record: `{record_file}`
- Summary: linked `skill-usage.record.v1` envelope; raw runtime details remain in the evidence location.

## Impact

Future agents may repeat this workflow gap unless the retained entry is triaged,
routed, and later promoted into a durable fix, runbook, test, script, or skill
policy.

## Current Workaround

Use the linked raw record for details, apply the safest manual workaround for
the affected workflow, and avoid copying raw logs or secrets into this entry.

## Promotion Criteria

Promote after the durable fix or accepted-risk decision is implemented,
validated, and linked from this entry.

## Next Action

{next_action}
"""
    write_text(target, text)
    verification = verify_entry(target, out_dir)
    if not verification["ok"]:
        return verification
    return {"ok": True, "path": str(target), "status": status, "severity": severity}


def replace_next_action(text: str, *, link: str | None, next_action: str | None) -> str:
    match = re.search(r"(?ms)^## Next Action\n\n(?P<body>.*?)(?=^## |\Z)", text)
    if not match:
        if next_action:
            return text.rstrip() + f"\n\n## Next Action\n\n{next_action}\n"
        if link:
            return text.rstrip() + f"\n\n## Next Action\n\nLifecycle link: `{link}`\n"
        return text

    body = next_action.strip() if next_action else match.group("body").strip()
    if link and link not in body:
        body = (body + "\n\n" if body else "") + f"Lifecycle link: `{link}`"
    replacement = f"## Next Action\n\n{body.strip()}\n"
    return text[: match.start()] + replacement + text[match.end() :]


def set_status(args: argparse.Namespace) -> dict[str, Any]:
    path = args.entry
    status = args.status
    if status not in VALID_STATUSES:
        raise CommandError(f"invalid status: {status}", exit_code=2)

    text = read_text(path)
    new_text, count = re.subn(r"(?m)^-\s+Status:\s*\S+\s*$", f"- Status: {status}", text, count=1)
    if count == 0:
        raise CommandError("entry has no status line")
    new_text = replace_next_action(new_text, link=args.link, next_action=args.next_action)
    write_text(path, new_text)
    return {"ok": True, "path": str(path), "status": status, "link": args.link or ""}


def command_list(args: argparse.Namespace) -> int:
    statuses = {item.strip() for item in (args.status or "").split(",") if item.strip()}
    unknown = sorted(statuses - VALID_STATUSES)
    if unknown:
        raise CommandError(f"invalid status filter: {', '.join(unknown)}", exit_code=2)

    entries = []
    for path in iter_entries(args.inbox_dir):
        parsed = parse_entry(path)
        item = entry_json(parsed)
        if statuses and item["status"] not in statuses:
            continue
        entries.append(item)
    print_payload({"ok": True, "entries": entries}, args.format)
    return 0


def command_verify(args: argparse.Namespace) -> int:
    payload = verify_entry(args.entry, args.inbox_dir)
    print_payload(payload, args.format)
    return 0 if payload["ok"] else 1


def command_new(args: argparse.Namespace) -> int:
    payload = create_entry_from_skill_usage(args)
    print_payload(payload, args.format)
    return 0 if payload.get("ok") else 1


def command_set_status(args: argparse.Namespace) -> int:
    payload = set_status(args)
    print_payload(payload, args.format)
    return 0


def add_format(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--format", choices=("text", "json"), default="text", help="Output format: text or json.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="heuristic-error-inbox.sh",
        usage="heuristic-error-inbox.sh <list|verify|new|set-status> [options]",
        description="Manage curated HEURISTIC_SYSTEM error-inbox entries.",
        epilog="Common output option: --format text|json",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List inbox entries.")
    list_parser.add_argument("--inbox-dir", type=Path, default=default_inbox_dir())
    list_parser.add_argument("--status", default="", help="Comma-separated lifecycle status filter.")
    add_format(list_parser)
    list_parser.set_defaults(func=command_list)

    verify_parser = subparsers.add_parser("verify", help="Verify one inbox entry.")
    verify_parser.add_argument("entry", type=Path)
    verify_parser.add_argument("--inbox-dir", type=Path, default=None)
    add_format(verify_parser)
    verify_parser.set_defaults(func=command_verify)

    new_parser = subparsers.add_parser("new", help="Create a curated entry from a skill usage record.")
    new_parser.add_argument("--from-skill-usage", type=Path, required=True)
    new_parser.add_argument("--slug", required=True)
    new_parser.add_argument("--out-dir", type=Path, default=default_inbox_dir())
    new_parser.add_argument("--title", default="")
    new_parser.add_argument("--area", default="")
    new_parser.add_argument("--status", choices=sorted(VALID_STATUSES), default="open")
    new_parser.add_argument("--severity", choices=sorted(VALID_SEVERITIES), default="medium")
    new_parser.add_argument("--next-action", default="")
    add_format(new_parser)
    new_parser.set_defaults(func=command_new)

    status_parser = subparsers.add_parser("set-status", help="Update an entry lifecycle status.")
    status_parser.add_argument("entry", type=Path)
    status_parser.add_argument("--status", choices=sorted(VALID_STATUSES), required=True)
    status_parser.add_argument("--link", default="")
    status_parser.add_argument("--next-action", default="")
    add_format(status_parser)
    status_parser.set_defaults(func=command_set_status)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except CommandError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
