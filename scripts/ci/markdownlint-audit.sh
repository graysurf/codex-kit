#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  markdownlint-audit.sh [--strict]

Run repository Markdown lint checks using rumdl and the repo config.

Options:
  --strict   Treat lint failures as hard failures (exit 1)
  -h, --help Show this help
USAGE
}

strict=0
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --strict)
      strict=1
      shift
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

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" || ! -d "$repo_root" ]]; then
  echo "error: must run inside a git work tree" >&2
  exit 2
fi
cd "$repo_root"

if ! command -v npx >/dev/null 2>&1; then
  echo "error: missing required tool on PATH: npx" >&2
  echo "hint: install Node.js (includes npx)" >&2
  exit 2
fi

config_file="$repo_root/.rumdl.toml"
if [[ ! -f "$config_file" ]]; then
  echo "error: missing rumdl config: $config_file" >&2
  exit 2
fi

md_files=()
while IFS= read -r -d '' file; do
  md_files+=("$file")
done < <(git ls-files -z '*.md')

if [[ "${#md_files[@]}" -eq 0 ]]; then
  echo "PASS: markdown lint audit (strict=$strict; no markdown files)"
  exit 0
fi

lint_cmd=(
  npx --yes rumdl@0.1.62
  check
  --config "$config_file"
  "${md_files[@]}"
)

echo "+ ${lint_cmd[*]}"
if "${lint_cmd[@]}"; then
  echo "PASS: markdown lint audit (strict=$strict)"
  exit 0
fi

if [[ "$strict" -eq 1 ]]; then
  echo "FAIL: markdown lint audit (strict=$strict)" >&2
  exit 1
fi

echo "WARN: markdown lint audit found issues (strict=$strict)" >&2
echo "PASS: markdown lint audit (warning mode)"
