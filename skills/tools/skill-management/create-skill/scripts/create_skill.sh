#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $CODEX_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh \
    --skill-dir <skills/.../skill-name> \
    [--title "<Title>"] \
    [--description "<text>"] \
    [--help]

Creates a new skill skeleton under `skills/` and validates it with:
  - validate_skill_contracts.sh
  - audit-skill-layout.sh --skill-dir

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

cat >"$abs_skill_dir/SKILL.md" <<EOF
---
name: ${skill_name}
description: ${skill_description}
---

# ${skill_title}

## Contract

Prereqs:

- TBD

Inputs:

- TBD

Outputs:

- TBD

Exit codes:

- \`0\`: success
- \`1\`: failure
- \`2\`: usage error

Failure modes:

- TBD

## Scripts (only entrypoints)

- \`$CODEX_HOME/${skill_dir}/${stub_script_rel}\`
EOF

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

echo "ok: created $skill_dir"
