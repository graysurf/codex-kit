#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  google-sheets-cell-edit.sh --help

Instruction-first skill. No standalone CLI automation is implemented here.

Use the SKILL.md workflow for:
- stable Google Sheets cell targeting
- multiline cell edits
- multiple rich-text hyperlinks inside one cell
- post-run skill improvement suggestions
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
