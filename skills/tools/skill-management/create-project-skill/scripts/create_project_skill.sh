#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $CODEX_HOME/skills/tools/skill-management/create-project-skill/scripts/create_project_skill.sh \
    --skill-dir <.codex/skills/...|<skill-name>> \
    [--project-path <path>] \
    [--title "<Title>"] \
    [--description "<text>"] \
    [--help]

Scaffolds a project-local skill under .codex/skills and validates:
  - SKILL contract headings (via validate_skill_contracts.sh --file)
  - project-skill layout (local validator)

Notes:
  - If --skill-dir does not start with .codex/skills/, it is treated as
    <skill-name> and expanded to .codex/skills/<skill-name>.
  - This command writes files and does not stage/commit.
USAGE
}

project_path_raw="$PWD"
skill_dir_raw=""
skill_title=""
skill_description="TBD"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --project-path)
      if [[ $# -lt 2 ]]; then
        echo "error: --project-path requires a path" >&2
        usage >&2
        exit 2
      fi
      project_path_raw="${2:-}"
      shift 2
      ;;
    --skill-dir)
      if [[ $# -lt 2 ]]; then
        echo "error: --skill-dir requires a path or name" >&2
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
codex_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$codex_root" ]]; then
  echo "error: unable to resolve codex-kit repository root" >&2
  exit 1
fi

project_root="$(
  python3 - "$project_path_raw" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

raw = sys.argv[1].strip()
if not raw:
    print("error: empty --project-path", file=sys.stderr)
    raise SystemExit(2)

p = Path(raw).expanduser().resolve()
if not p.exists():
    print(f"error: project path not found: {raw}", file=sys.stderr)
    raise SystemExit(2)
if not p.is_dir():
    print(f"error: project path must be a directory: {raw}", file=sys.stderr)
    raise SystemExit(2)

print(p.as_posix())
PY
)"

if ! git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: --project-path must be inside a git work tree: $project_root" >&2
  exit 1
fi

skill_dir="$(
  python3 - "$project_root" "$skill_dir_raw" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

project_root = Path(sys.argv[1]).resolve()
raw = sys.argv[2].strip()

if not raw:
    print("error: empty --skill-dir", file=sys.stderr)
    raise SystemExit(2)

p = Path(raw)
if p.is_absolute():
    try:
        p = p.resolve().relative_to(project_root)
    except ValueError:
        print(f"error: --skill-dir absolute path must be under project root: {raw}", file=sys.stderr)
        raise SystemExit(2)

normalized = p.as_posix().rstrip("/")
if normalized.startswith("./"):
    normalized = normalized[2:]
if ".." in Path(normalized).parts:
    print(f"error: --skill-dir must not contain '..': {raw}", file=sys.stderr)
    raise SystemExit(2)
if normalized in {".codex", ".codex/skills"}:
    print(f"error: --skill-dir must include a skill name under .codex/skills/: {raw}", file=sys.stderr)
    raise SystemExit(2)

if normalized.startswith(".codex/"):
    if not normalized.startswith(".codex/skills/"):
        print(f"error: --skill-dir must be under .codex/skills/: {raw}", file=sys.stderr)
        raise SystemExit(2)
    resolved = normalized
else:
    resolved = f".codex/skills/{normalized}"

if resolved.endswith("/"):
    resolved = resolved.rstrip("/")
if not resolved.startswith(".codex/skills/"):
    print(f"error: resolved --skill-dir must be under .codex/skills/: {resolved}", file=sys.stderr)
    raise SystemExit(2)
if len(Path(resolved).parts) < 3:
    print(f"error: --skill-dir must include a skill name under .codex/skills/: {raw}", file=sys.stderr)
    raise SystemExit(2)

print(resolved)
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
print(" ".join(w[:1].upper() + w[1:] for w in words) if words else "Project Skill")
PY
  )"
fi

abs_skill_dir="${project_root}/${skill_dir}"
if [[ -e "$abs_skill_dir" ]]; then
  echo "error: already exists: $abs_skill_dir" >&2
  exit 1
fi

mkdir -p "$abs_skill_dir/scripts" "$abs_skill_dir/tests"

stub_script_rel="scripts/${skill_name}.sh"
stub_script_abs="${abs_skill_dir}/${stub_script_rel}"

test_id="$(
  python3 - "$skill_dir" <<'PY'
from __future__ import annotations

import sys

skill_dir = sys.argv[1]
rel = skill_dir.removeprefix(".codex/skills/").strip("/")
parts = []
for p in rel.split("/"):
    p = p.strip()
    if not p:
        continue
    parts.append(p.replace("-", "_"))
print("_".join(parts) if parts else "project_skill")
PY
)"
test_rel="tests/test_${test_id}.sh"
test_abs="${abs_skill_dir}/${test_rel}"

template_path="${codex_root}/skills/tools/skill-management/create-project-skill/assets/templates/PROJECT_SKILL_TEMPLATE.md"
if [[ ! -f "$template_path" ]]; then
  echo "error: missing template: $template_path" >&2
  exit 1
fi

skill_md_tmp="${abs_skill_dir}/SKILL.md.tmp"
python3 - "$template_path" "$skill_name" "$skill_description" "$skill_title" "$skill_dir" "$stub_script_rel" <<'PY' >"$skill_md_tmp"
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

if any(token in text for token in replacements):
    raise SystemExit("error: failed to render project skill template (unreplaced placeholders remain)")
if "{{" in text or "}}" in text:
    raise SystemExit("error: failed to render project skill template (unknown placeholders remain)")

sys.stdout.write(text)
PY
mv "$skill_md_tmp" "${abs_skill_dir}/SKILL.md"

cat >"$stub_script_abs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  <ENTRYPOINT> [--help]

Placeholder: implement this project skill entrypoint.
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
#!/usr/bin/env bash
set -euo pipefail

script_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
skill_root="\$(cd "\${script_dir}/.." && pwd)"

if [[ ! -f "\${skill_root}/SKILL.md" ]]; then
  echo "error: missing SKILL.md" >&2
  exit 1
fi
if [[ ! -f "\${skill_root}/${stub_script_rel}" ]]; then
  echo "error: missing ${stub_script_rel}" >&2
  exit 1
fi

echo "ok: project skill smoke checks passed"
EOF

chmod +x "$stub_script_abs" "$test_abs" || true

python3 - "$abs_skill_dir" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

skill_root = Path(sys.argv[1]).resolve()
allowed_top_level = {"SKILL.md", "scripts", "bin", "references", "assets", "tests"}
required_top_level = {"SKILL.md", "tests"}

errors: list[str] = []
tops = {p.name for p in skill_root.iterdir()}
missing = sorted(item for item in required_top_level if item not in tops)
unexpected = sorted(item for item in tops if item not in allowed_top_level)
if missing:
    errors.append(f"missing top-level entries: {', '.join(missing)}")
if unexpected:
    errors.append(f"unexpected top-level entries: {', '.join(unexpected)}")

for md in skill_root.rglob("*TEMPLATE*.md"):
    rel = md.relative_to(skill_root)
    parts = rel.parts
    if not (parts[:1] == ("references",) or parts[:2] == ("assets", "templates")):
        errors.append(f"template markdown must be under references/ or assets/templates/: {rel.as_posix()}")

if errors:
    for item in errors:
        print(f"error: {item}", file=sys.stderr)
    raise SystemExit(1)
PY

validator_contracts="${codex_root}/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh"
if [[ ! -f "$validator_contracts" ]]; then
  echo "error: missing validator: $validator_contracts" >&2
  exit 1
fi

"$validator_contracts" --file "${abs_skill_dir}/SKILL.md"

echo "ok: created project skill ${skill_dir}"
