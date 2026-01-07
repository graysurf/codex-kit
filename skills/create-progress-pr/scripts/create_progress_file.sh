#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  create_progress_file.sh --title "<short title>" [options]

Options:
  --feature <name>            Feature/product prefix for the H1 (default: repo folder name)
  --slug <feature_slug>       Override computed slug
  --date <YYYYMMDD>           Override date (default: today)
  --status <status>           DRAFT | IN PROGRESS | DONE (default: DRAFT)
  --output <path>             Output path relative to repo root (default: docs/progress/<YYYYMMDD>_<slug>.md)
  --use-project-templates     Use repo templates under docs/templates/ instead of skill defaults
  --skip-install-templates    Do not copy default templates into docs/templates/ when missing
  --skip-index                Do not update docs/progress/README.md

Notes:
  - Run inside the target git repo (any subdir is fine).
  - This script only fills a few header placeholders; you still need to replace all remaining [[...]] tokens before commit.
USAGE
}

title=""
feature=""
slug=""
date_yyyymmdd="$(date +%Y%m%d)"
status="DRAFT"
output_path=""
use_project_templates="0"
skip_install_templates="0"
skip_index="0"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --title)
      title="${2:-}"
      shift 2
      ;;
    --feature)
      feature="${2:-}"
      shift 2
      ;;
    --slug)
      slug="${2:-}"
      shift 2
      ;;
    --date)
      date_yyyymmdd="${2:-}"
      shift 2
      ;;
    --status)
      status="${2:-}"
      shift 2
      ;;
    --output)
      output_path="${2:-}"
      shift 2
      ;;
    --use-project-templates)
      use_project_templates="1"
      shift
      ;;
    --skip-install-templates)
      skip_install_templates="1"
      shift
      ;;
    --skip-index)
      skip_index="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$title" ]]; then
  echo "error: --title is required" >&2
  usage >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required" >&2
  exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: must run inside a git work tree" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -z "$feature" ]]; then
  feature="$(basename "$repo_root")"
fi

readarray -t computed < <(python3 - "$title" "$slug" "$date_yyyymmdd" <<'PY'
import datetime
import re
import sys

title, slug, yyyymmdd = sys.argv[1], sys.argv[2], sys.argv[3]

if not re.fullmatch(r"\d{8}", yyyymmdd or ""):
  raise SystemExit(f"error: --date must be YYYYMMDD, got: {yyyymmdd!r}")

dt = datetime.datetime.strptime(yyyymmdd, "%Y%m%d").date()

def slugify(s: str) -> str:
  s = s.lower()
  s = re.sub(r"[^a-z0-9]+", "-", s)
  s = re.sub(r"-{2,}", "-", s).strip("-")
  return s or "progress"

if not slug:
  slug = slugify(title)
else:
  slug = slugify(slug)

print(slug)
print(dt.isoformat())
PY
)

slug="${computed[0]}"
date_iso="${computed[1]}"

case "$status" in
  "DRAFT"|"IN PROGRESS"|"DONE")
    ;;
  *)
    echo "error: --status must be one of: DRAFT, IN PROGRESS, DONE" >&2
    exit 1
    ;;
esac

if [[ -z "$output_path" ]]; then
  output_path="docs/progress/${date_yyyymmdd}_${slug}.md"
fi

if [[ -e "$output_path" ]]; then
  echo "error: output already exists: $output_path" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"

if [[ "$use_project_templates" == "1" ]]; then
  progress_template="docs/templates/PROGRESS_TEMPLATE.md"
  glossary_template="docs/templates/PROGRESS_GLOSSARY.md"

  if [[ ! -f "$progress_template" || ! -f "$glossary_template" ]]; then
    echo "error: --use-project-templates requires:" >&2
    echo "  - ${repo_root}/${progress_template}" >&2
    echo "  - ${repo_root}/${glossary_template}" >&2
    exit 1
  fi
else
  progress_template="${skill_dir}/references/PROGRESS_TEMPLATE.md"
  glossary_template="${skill_dir}/references/PROGRESS_GLOSSARY.md"

  if [[ "$skip_install_templates" == "0" ]]; then
    mkdir -p "docs/templates"
    if [[ ! -f "docs/templates/PROGRESS_TEMPLATE.md" ]]; then
      cp "$progress_template" "docs/templates/PROGRESS_TEMPLATE.md"
    fi
    if [[ ! -f "docs/templates/PROGRESS_GLOSSARY.md" ]]; then
      cp "$glossary_template" "docs/templates/PROGRESS_GLOSSARY.md"
    fi
  fi
fi

cp "$progress_template" "$output_path"

python3 - "$output_path" "$feature" "$title" "$status" "$date_iso" <<'PY'
import re
import sys

path, feature, title, status, date_iso = sys.argv[1:]

with open(path, "r", encoding="utf-8") as f:
  text = f.read()

text = text.replace("# [[feature]]: [[short title]]", f"# {feature}: {title}")
text = text.replace("[[[repository/pull/number](url) or TBD]]", "TBD")
text = text.replace("[[url or path or TBD or None]]", "TBD")
text = text.replace("[[url or path or TBD]]", "TBD")
text = text.replace("[[DRAFT\\|IN PROGRESS\\|DONE]]", status)
text = text.replace("[[YYYY-MM-DD]]", date_iso)

with open(path, "w", encoding="utf-8") as f:
  f.write(text)

missing = re.findall(r"\[\[.*?\]\]", text)
if not missing:
  print(f"warning: no [[...]] tokens remain in {path}; verify the file content is complete", file=sys.stderr)
PY

if [[ "$skip_index" == "0" && -f "docs/progress/README.md" ]]; then
  python3 - "docs/progress/README.md" "$date_iso" "$title" "$output_path" <<'PY'
import datetime
import re
import sys

index_path, date_iso, title, output_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

if not output_path.startswith("docs/progress/"):
  print(f"warning: output is not under docs/progress/: {output_path}; skipping index update", file=sys.stderr)
  raise SystemExit(0)

link_target = output_path[len("docs/progress/"):]
feature_cell = f"[{title}]({link_target})"

with open(index_path, "r", encoding="utf-8") as f:
  lines = f.readlines()

in_progress_start = None
for i, line in enumerate(lines):
  if line.strip() == "## In progress":
    in_progress_start = i
    break

if in_progress_start is None:
  print("warning: cannot find '## In progress' section in docs/progress/README.md; skipping index update", file=sys.stderr)
  raise SystemExit(0)

table_sep = None
for i in range(in_progress_start, len(lines)):
  if lines[i].startswith("| ---"):
    table_sep = i
    break

if table_sep is None:
  print("warning: cannot find In progress table header separator in docs/progress/README.md; skipping index update", file=sys.stderr)
  raise SystemExit(0)

row = f"| {date_iso} | {feature_cell} | TBD |\n"

if row in lines:
  print("warning: index row already exists; skipping", file=sys.stderr)
  raise SystemExit(0)

lines.insert(table_sep + 1, row)

def row_cells(row_line):
  return [p.strip() for p in row_line.strip().strip("|").split("|")]

def sort_in_progress_rows(sep_idx: int):
  row_start = sep_idx + 1
  row_end = row_start
  rows = []

  while row_end < len(lines) and lines[row_end].startswith("|"):
    if lines[row_end].startswith("| ---"):
      row_end += 1
      continue
    rows.append(lines[row_end])
    row_end += 1

  if not rows:
    return

  def sort_key(row_line: str):
    cells = row_cells(row_line)
    date_cell = cells[0].strip() if len(cells) >= 1 else ""
    pr_cell = cells[2].strip() if len(cells) >= 3 else ""

    try:
      date_ord = datetime.date.fromisoformat(date_cell).toordinal()
    except ValueError:
      date_ord = -1

    m = re.search(r"#(?P<num>\\d+)", pr_cell)
    pr_num = int(m.group("num")) if m else -1

    return (date_ord, pr_num, row_line)

  rows_sorted = sorted(rows, key=sort_key, reverse=True)
  lines[row_start:row_end] = rows_sorted

sort_in_progress_rows(table_sep)

with open(index_path, "w", encoding="utf-8") as f:
  f.writelines(lines)
PY
fi

echo "$output_path"
