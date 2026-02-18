#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/lint.sh [--shell|--python|--all]

Runs repo-local lint and syntax checks.

Modes:
  --all (default): run both shell + python checks
  --shell:         run shell checks only (bash + zsh)
  --python:        run python checks only (ruff + mypy + pyright)

Setup:
  .venv/bin/pip install -r requirements-dev.txt

Examples:
  scripts/lint.sh
  scripts/lint.sh --shell
  scripts/lint.sh --python
USAGE
}

want_shell=1
want_python=1

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --shell)
      want_shell=1
      want_python=0
      shift
      ;;
    --python)
      want_shell=0
      want_python=1
      shift
      ;;
    --all)
      want_shell=1
      want_python=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

agent_home="${AGENT_HOME:-${AGENTS_HOME:-$repo_root}}"
export AGENT_HOME="$agent_home"
export AGENTS_HOME="$agent_home"

# Reduce color/control sequences for non-interactive usage and logs.
export NO_COLOR=1
export CLICOLOR=0
export CLICOLOR_FORCE=0
export FORCE_COLOR=0
export PY_COLORS=0

rc=0

contains_path() {
  local needle="${1:-}"
  shift || true
  local p=''
  for p in "$@"; do
    if [[ "$p" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ "$want_shell" -eq 1 ]]; then
  echo "lint: shell (bash/zsh)" >&2

  if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required (for git ls-files)" >&2
    exit 1
  fi
  if ! command -v zsh >/dev/null 2>&1; then
    echo "error: zsh is required (for zsh -n syntax checks)" >&2
    exit 1
  fi

  bash_scripts=()
  zsh_scripts=()
  sh_missing_shebang=()

  while IFS= read -r -d '' file; do
    [[ -n "$file" ]] || continue
    case "$file" in
      shell_snapshots/*)
        continue
        ;;
    esac

    [[ -f "$file" ]] || continue

    first_line=""
    if ! IFS= read -r first_line <"$file"; then
      first_line=""
    fi

    if [[ "$file" == *.zsh ]]; then
      if ! contains_path "$file" "${zsh_scripts[@]}"; then
        zsh_scripts+=("$file")
      fi
    fi

    if [[ "$first_line" == '#!'* ]]; then
      if [[ "$first_line" == *zsh* ]]; then
        if ! contains_path "$file" "${zsh_scripts[@]}"; then
          zsh_scripts+=("$file")
        fi
      elif [[ "$first_line" == *bash* ]]; then
        if ! contains_path "$file" "${bash_scripts[@]}"; then
          bash_scripts+=("$file")
        fi
      fi
    else
      if [[ "$file" == *.sh ]]; then
        sh_missing_shebang+=("$file")
      fi
    fi
  done < <(git ls-files -z)

  if [[ ${#sh_missing_shebang[@]} -gt 0 ]]; then
    echo "warning: skipping .sh without shebang (cannot infer bash vs zsh):" >&2
    printf '  - %s\n' "${sh_missing_shebang[@]}" >&2
  fi

  if [[ ${#bash_scripts[@]} -gt 0 ]]; then
    if ! command -v shellcheck >/dev/null 2>&1; then
      echo "error: shellcheck not found (required for bash lint)" >&2
      echo "hint: macOS: brew install shellcheck" >&2
      echo "hint: Ubuntu: sudo apt-get install -y shellcheck" >&2
      exit 1
    fi

    echo "lint: shellcheck (bash scripts)" >&2
    set +e
    shellcheck -S error "${bash_scripts[@]}"
    sc_rc=$?
    set -e
    if [[ "$sc_rc" -ne 0 ]]; then
      rc=1
    fi

    echo "lint: bash -n (syntax)" >&2
    for f in "${bash_scripts[@]}"; do
      set +e
      bash -n "$f"
      bn_rc=$?
      set -e
      if [[ "$bn_rc" -ne 0 ]]; then
        rc=1
      fi
    done
  fi

  if [[ ${#zsh_scripts[@]} -gt 0 ]]; then
    echo "lint: zsh -n (syntax)" >&2
    for f in "${zsh_scripts[@]}"; do
      set +e
      zsh -n "$f"
      zn_rc=$?
      set -e
      if [[ "$zn_rc" -ne 0 ]]; then
        rc=1
      fi
    done
  fi
fi

if [[ "$want_python" -eq 1 ]]; then
  echo "lint: python (ruff/mypy/pyright)" >&2

  python="${repo_root}/.venv/bin/python"
  if [[ ! -x "$python" ]]; then
    python="$(command -v python3 || true)"
  fi
  if [[ -z "$python" ]]; then
    echo "error: python3 not found; create a venv at .venv/ and install requirements-dev.txt" >&2
    exit 1
  fi

  ruff_bin="${repo_root}/.venv/bin/ruff"
  if [[ ! -x "$ruff_bin" ]]; then
    ruff_bin="$(command -v ruff || true)"
  fi
  if [[ -z "$ruff_bin" ]]; then
    echo "error: ruff not found" >&2
    echo "hint: run: .venv/bin/pip install -r requirements-dev.txt" >&2
    exit 1
  fi

  mypy_bin="${repo_root}/.venv/bin/mypy"
  if [[ ! -x "$mypy_bin" ]]; then
    mypy_bin="$(command -v mypy || true)"
  fi
  if [[ -z "$mypy_bin" ]]; then
    echo "error: mypy not found" >&2
    echo "hint: run: .venv/bin/pip install -r requirements-dev.txt" >&2
    exit 1
  fi

  pyright_bin="${repo_root}/.venv/bin/pyright"
  if [[ ! -x "$pyright_bin" ]]; then
    pyright_bin="$(command -v pyright || true)"
  fi
  if [[ -z "$pyright_bin" ]]; then
    echo "error: pyright not found" >&2
    echo "hint: run: .venv/bin/pip install -r requirements-dev.txt" >&2
    exit 1
  fi

  echo "lint: ruff check" >&2
  set +e
  "$ruff_bin" check --output-format concise tests
  ruff_rc=$?
  set -e
  if [[ "$ruff_rc" -ne 0 ]]; then
    rc=1
  fi

  echo "lint: mypy" >&2
  mypy_cfg="${repo_root}/mypy.ini"
  set +e
  if [[ -f "$mypy_cfg" ]]; then
    "$mypy_bin" --no-color-output --config-file "$mypy_cfg" tests
  else
    "$mypy_bin" --no-color-output tests
  fi
  mypy_rc=$?
  set -e
  if [[ "$mypy_rc" -ne 0 ]]; then
    rc=1
  fi

  echo "lint: pyright" >&2
  pyright_cfg="${repo_root}/pyrightconfig.json"
  set +e
  if [[ -f "$pyright_cfg" ]]; then
    "$pyright_bin" --warnings --pythonpath "$python" --project "$pyright_cfg"
  else
    "$pyright_bin" --warnings --pythonpath "$python" tests
  fi
  pyright_rc=$?
  set -e
  if [[ "$pyright_rc" -ne 0 ]]; then
    rc=1
  fi

  echo "lint: python -c compile()" >&2
  set +e
  PYTHONDONTWRITEBYTECODE=1 "$python" - <<'PY'
import subprocess
import sys
from pathlib import Path

tracked = subprocess.check_output(["git", "ls-files", "*.py"], text=True).splitlines()
errors = 0
for p in tracked:
  path = Path(p)
  if not path.is_file():
    continue
  try:
    src = path.read_text("utf-8")
  except Exception as exc:
    print(f"error: failed to read {p}: {exc}", file=sys.stderr)
    errors += 1
    continue
  try:
    compile(src, p, "exec")
  except SyntaxError as exc:
    print(f"error: python syntax error: {p}:{exc.lineno}:{exc.offset}: {exc.msg}", file=sys.stderr)
    errors += 1
if errors:
  raise SystemExit(1)
PY
  pyc_rc=$?
  set -e
  if [[ "$pyc_rc" -ne 0 ]]; then
    rc=1
  fi
fi

exit "$rc"
