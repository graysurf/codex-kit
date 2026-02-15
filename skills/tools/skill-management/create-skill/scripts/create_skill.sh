#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $AGENTS_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh \
    --skill-dir <skills/.../skill-name> \
    [--title "<Title>"] \
    [--description "<text>"] \
    [--help]

Creates a new skill skeleton under `skills/` and validates it with:
  - validate_skill_contracts.sh
  - audit-skill-layout.sh --skill-dir
Then updates root README skill catalog for public domains:
  - skills/workflows/**
  - skills/tools/**
  - skills/automation/**

Notes:
  - Writes files on disk; does not stage or commit.
USAGE
}

skill_dir_raw=""
skill_title=""
skill_description="TBD"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --skill-dir)
      if [[ $# -lt 2 ]]; then
        echo "error: --skill-dir requires a path" >&2
        usage >&2
        exit 2
      fi
      skill_dir_raw="${2:-}"
      shift 2
      ;;
    --title)
      if [[ $# -lt 2 ]]; then
        echo "error: --title requires a value" >&2
        usage >&2
        exit 2
      fi
      skill_title="${2:-}"
      shift 2
      ;;
    --description)
      if [[ $# -lt 2 ]]; then
        echo "error: --description requires a value" >&2
        usage >&2
        exit 2
      fi
      skill_description="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$skill_dir_raw" ]]; then
  echo "error: --skill-dir is required" >&2
  usage >&2
  exit 2
fi

for cmd in git python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required" >&2
    exit 1
  fi
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "error: must run inside a git work tree" >&2
  exit 1
fi

cd "$repo_root"

skill_dir="$(
  python3 - "$repo_root" "$skill_dir_raw" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
raw = sys.argv[2].strip()

if not raw:
    print("error: empty --skill-dir", file=sys.stderr)
    raise SystemExit(2)

p = Path(raw)
if p.is_absolute():
    try:
        p = p.resolve().relative_to(repo_root)
    except ValueError:
        print(f"error: --skill-dir must be under repo root: {raw}", file=sys.stderr)
        raise SystemExit(2)

normalized = p.as_posix().lstrip("./").rstrip("/")
if ".." in Path(normalized).parts:
    print(f"error: --skill-dir must not contain '..': {raw}", file=sys.stderr)
    raise SystemExit(2)
if not normalized.startswith("skills/"):
    print(f"error: --skill-dir must start with skills/: {raw}", file=sys.stderr)
    raise SystemExit(2)

print(normalized)
PY
)"

skill_name="$(basename "$skill_dir")"

if [[ -z "$skill_title" ]]; then
  skill_title="$(
    python3 - "$skill_name" <<'PY'
from __future__ import annotations

import sys

slug = sys.argv[1].strip()
words = [w for w in slug.replace("_", "-").split("-") if w]
print(" ".join(w[:1].upper() + w[1:] for w in words) if words else "Skill")
PY
  )"
fi

abs_skill_dir="$repo_root/$skill_dir"
if [[ -e "$abs_skill_dir" ]]; then
  echo "error: already exists: $skill_dir" >&2
  exit 1
fi

mkdir -p "$abs_skill_dir/scripts" "$abs_skill_dir/tests"

stub_script_rel="scripts/${skill_name}.sh"
stub_script_abs="$abs_skill_dir/$stub_script_rel"

test_id="$(
  python3 - "$skill_dir" <<'PY'
from __future__ import annotations

import sys

skill_dir = sys.argv[1]
rel = skill_dir.removeprefix("skills/").strip("/")
parts = []
for p in rel.split("/"):
    p = p.strip()
    if not p:
        continue
    parts.append(p.replace("-", "_"))
print("_".join(parts) if parts else "skill")
PY
)"
test_rel="tests/test_${test_id}.py"
test_abs="$abs_skill_dir/$test_rel"

skill_md_template="${repo_root}/skills/tools/skill-management/create-skill/assets/templates/SKILL_TEMPLATE.md"
if [[ ! -f "$skill_md_template" ]]; then
  echo "error: missing SKILL.md template: $skill_md_template" >&2
  exit 1
fi

skill_md_tmp="${abs_skill_dir}/SKILL.md.tmp"
python3 - "$skill_md_template" "$skill_name" "$skill_description" "$skill_title" "$skill_dir" "$stub_script_rel" <<'PY' >"$skill_md_tmp"
from __future__ import annotations

import sys
from pathlib import Path

template_path = Path(sys.argv[1])
name = sys.argv[2]
description = sys.argv[3]
title = sys.argv[4]
skill_dir = sys.argv[5]
script_rel = sys.argv[6]

text = template_path.read_text("utf-8", errors="replace")
replacements = {
    "{{name}}": name,
    "{{description}}": description,
    "{{title}}": title,
    "{{skill_dir}}": skill_dir,
    "{{script_rel}}": script_rel,
}
for key, value in replacements.items():
    text = text.replace(key, value)

unreplaced = [token for token in replacements.keys() if token in text]
if unreplaced:
    raise SystemExit(f"error: failed to render template (unreplaced: {unreplaced})")
if "{{" in text or "}}" in text:
    raise SystemExit("error: failed to render template (unrecognized placeholders remain)")

sys.stdout.write(text)
PY
mv "$skill_md_tmp" "$abs_skill_dir/SKILL.md"

cat >"$stub_script_abs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  <ENTRYPOINT> [--help]

Placeholder: implement this skill entrypoint.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

usage >&2
exit 2
EOF

cat >"$test_abs" <<EOF
from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_${test_id}_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_${test_id}_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["${stub_script_rel}"])
EOF

chmod +x "$stub_script_abs" || true

validator_contracts="$repo_root/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh"
validator_layout="$repo_root/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh"

if [[ ! -f "$validator_contracts" ]]; then
  echo "error: missing validator: $validator_contracts" >&2
  exit 1
fi
if [[ ! -f "$validator_layout" ]]; then
  echo "error: missing validator: $validator_layout" >&2
  exit 1
fi

"$validator_contracts" --file "$abs_skill_dir/SKILL.md"
"$validator_layout" --skill-dir "$skill_dir"

readme_file="$repo_root/README.md"
if [[ ! -f "$readme_file" ]]; then
  echo "error: missing root README: $readme_file" >&2
  exit 1
fi

readme_action="$(
  python3 - "$readme_file" "$skill_dir" "$skill_name" "$skill_description" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path


def normalize_link_path(raw: str) -> str:
    text = raw.strip()
    if text.startswith("./"):
        text = text[2:]
    return text.rstrip("/")


def titleize_token(token: str) -> str:
    token = token.replace("_", "-").strip("-").strip()
    if not token:
        return ""
    parts = [p for p in token.split("-") if p]
    return " ".join(p[:1].upper() + p[1:] for p in parts)


def parse_table_row(line: str) -> list[str] | None:
    if not line.startswith("|"):
        return None
    cols = [c.strip() for c in line.strip().split("|")[1:-1]]
    if len(cols) < 3:
        return None
    return cols[:3]


def extract_link_path(skill_col: str) -> str | None:
    m = re.search(r"\[[^\]]+\]\(([^)]+)\)", skill_col)
    if not m:
        return None
    return normalize_link_path(m.group(1))


def infer_area_from_existing_rows(rows: list[str], parent_dir: str) -> str | None:
    for row in rows:
        parsed = parse_table_row(row)
        if not parsed:
            continue
        area, skill_col, _ = parsed
        link_path = extract_link_path(skill_col)
        if not link_path:
            continue
        if Path(link_path).parent.as_posix() == parent_dir:
            return area
    return None


def infer_fallback_area(skill_dir: str) -> str:
    parts = Path(skill_dir).parts
    # skills/<domain>/<...>/<skill-name>
    if len(parts) < 4:
        return "General"
    area_parts = [titleize_token(p) for p in parts[2:-1] if titleize_token(p)]
    if not area_parts:
        return "General"
    return " / ".join(area_parts)


readme_path = Path(sys.argv[1])
skill_dir = sys.argv[2].strip().strip("/")
skill_name = sys.argv[3].strip()
skill_description = " ".join(sys.argv[4].split()).replace("|", r"\|").strip()
if not skill_description:
    skill_description = "TBD"

if not readme_path.is_file():
    raise SystemExit(f"error: README not found: {readme_path}")

parts = Path(skill_dir).parts
if len(parts) < 3 or parts[0] != "skills":
    raise SystemExit(f"error: invalid skill-dir for README update: {skill_dir}")

domain = parts[1]
section_heading_by_domain = {
    "workflows": "### Workflows",
    "tools": "### Tools",
    "automation": "### Automation",
}
section_heading = section_heading_by_domain.get(domain)
if section_heading is None:
    print(f"skipped: non-public skill domain '{domain}' is not cataloged in README")
    raise SystemExit(0)

lines = readme_path.read_text("utf-8", errors="replace").splitlines()

try:
    section_idx = next(i for i, line in enumerate(lines) if line.strip() == section_heading)
except StopIteration:
    raise SystemExit(f"error: section not found in README: {section_heading}")

header_idx = None
for i in range(section_idx + 1, len(lines)):
    if lines[i].startswith("### ") and i > section_idx + 1:
        break
    if lines[i].strip() == "| Area | Skill | Description |":
        header_idx = i
        break

if header_idx is None:
    raise SystemExit(f"error: table header not found under section: {section_heading}")

if header_idx + 1 >= len(lines) or not lines[header_idx + 1].strip().startswith("| --- |"):
    raise SystemExit(f"error: malformed table separator under section: {section_heading}")

rows_start = header_idx + 2
rows_end = rows_start
while rows_end < len(lines) and lines[rows_end].startswith("|"):
    rows_end += 1
table_rows = lines[rows_start:rows_end]

normalized_target = normalize_link_path(f"./{skill_dir}/")
for row in table_rows:
    parsed = parse_table_row(row)
    if not parsed:
        continue
    _, skill_col, _ = parsed
    link_path = extract_link_path(skill_col)
    if link_path and normalize_link_path(link_path) == normalized_target:
        print("exists")
        raise SystemExit(0)

parent_dir = Path(skill_dir).parent.as_posix()
area = infer_area_from_existing_rows(table_rows, parent_dir) or infer_fallback_area(skill_dir)
skill_cell = f"[{skill_name}](./{skill_dir}/)"
new_row = f"| {area} | {skill_cell} | {skill_description} |"

insert_at = rows_end
for i in range(rows_end - 1, rows_start - 1, -1):
    parsed = parse_table_row(lines[i])
    if parsed and parsed[0] == area:
        insert_at = i + 1
        break

lines.insert(insert_at, new_row)
readme_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("updated")
PY
)"

case "$readme_action" in
  updated)
    ;;
  exists)
    ;;
  skipped:*)
    echo "note: ${readme_action#skipped: }"
    ;;
  *)
    echo "error: unexpected README update result: $readme_action" >&2
    exit 1
    ;;
esac

echo "ok: created $skill_dir"
