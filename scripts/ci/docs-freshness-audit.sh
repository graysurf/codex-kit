#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/ci/docs-freshness-audit.sh [--check] [--rules <path>]

Audits docs command/path freshness using rules from:
  docs/testing/docs-freshness-rules.md

Rules block format (between marker comments):
  DOC|<doc path>
  REQUIRED_COMMAND|<exact command text>
  REQUIRED_PATH|<repo-relative path>
  ALLOW_MISSING_PATH|<repo-relative path>

Checks performed:
  - Scoped docs exist.
  - Required commands are still documented.
  - Required critical paths exist and are still documented.
  - Repo-local command/path references in scoped docs resolve to existing paths.

Options:
  --check         Exit non-zero on freshness violations.
  --rules <path>  Override rules file path (repo-relative or absolute).
  -h, --help      Show this help.
USAGE
}

check_mode=0
rules_file="docs/testing/docs-freshness-rules.md"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --check)
      check_mode=1
      shift
      ;;
    --rules)
      if [[ $# -lt 2 ]]; then
        echo "error: --rules requires a path argument" >&2
        usage >&2
        exit 2
      fi
      rules_file="${2:-}"
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

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" || ! -d "$repo_root" ]]; then
  echo "error: must run inside a git work tree" >&2
  exit 2
fi
cd "$repo_root"

has_rg=0
if command -v rg >/dev/null 2>&1; then
  has_rg=1
fi

if [[ ! -f "$rules_file" ]]; then
  echo "error: rules file not found: ${rules_file}" >&2
  exit 2
fi

pass() {
  printf 'PASS [docs-freshness] %s\n' "$1"
}

warn() {
  printf 'WARN [docs-freshness] %s\n' "$1"
}

fail() {
  printf 'FAIL [docs-freshness] %s\n' "$1" >&2
}

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

contains_literal_in_file() {
  local needle="${1:-}"
  local file_path="${2:-}"
  if [[ "$has_rg" -eq 1 ]]; then
    rg -F -q -- "$needle" "$file_path"
  else
    grep -F -q -- "$needle" "$file_path"
  fi
}

scan_doc_tokens() {
  local file_path="${1:-}"
  # Order alternatives longest-prefix-first so `.agents/scripts/...` is captured
  # as a single token rather than fragmenting into a bare `scripts/...` match.
  local token_pattern='\$AGENT_HOME/(scripts/[A-Za-z0-9._/-]+|skills/[A-Za-z0-9._/-]+/scripts/[A-Za-z0-9._/-]+)|(\.agents/scripts/[A-Za-z0-9._/-]+|skills/[A-Za-z0-9._/-]+/scripts/[A-Za-z0-9._/-]+|scripts/[A-Za-z0-9._/-]+)'
  if [[ "$has_rg" -eq 1 ]]; then
    rg -H -n -o -e "$token_pattern" "$file_path"
  else
    grep -H -n -E -o -- "$token_pattern" "$file_path"
  fi
}

rules_raw="$(mktemp)"
path_hits_raw="$(mktemp)"
trap 'rm -f "$rules_raw" "$path_hits_raw"' EXIT

awk '/docs-freshness-audit:begin/{in_block=1;next}/docs-freshness-audit:end/{in_block=0}in_block{print}' "$rules_file" >"$rules_raw"

if [[ ! -s "$rules_raw" ]]; then
  echo "error: rules block is missing or empty in ${rules_file}" >&2
  exit 2
fi

if [[ "$has_rg" -ne 1 ]]; then
  warn "rg not found; using grep fallback for docs freshness scan"
fi

docs=()
required_commands=()
required_paths=()
allow_missing_paths=()
violation_count=0

record_violation() {
  fail "$1"
  violation_count=$((violation_count + 1))
}

while IFS= read -r raw_line; do
  line="$(trim "$raw_line")"
  [[ -n "$line" ]] || continue
  [[ "$line" == \#* ]] && continue

  if [[ "$line" != *"|"* ]]; then
    record_violation "invalid rule line (missing '|'): ${line}"
    continue
  fi

  kind="$(trim "${line%%|*}")"
  value="$(trim "${line#*|}")"

  if [[ -z "$kind" || -z "$value" ]]; then
    record_violation "invalid rule line (empty kind/value): ${line}"
    continue
  fi

  case "$kind" in
    DOC)
      docs+=("$value")
      ;;
    REQUIRED_COMMAND)
      required_commands+=("$value")
      ;;
    REQUIRED_PATH)
      required_paths+=("$value")
      ;;
    ALLOW_MISSING_PATH)
      allow_missing_paths+=("$value")
      ;;
    *)
      record_violation "unknown rule kind '${kind}' in line: ${line}"
      ;;
  esac
done <"$rules_raw"

if [[ "${#docs[@]}" -eq 0 ]]; then
  record_violation "no DOC rules configured in ${rules_file}"
fi

if [[ "${#required_commands[@]}" -eq 0 ]]; then
  record_violation "no REQUIRED_COMMAND rules configured in ${rules_file}"
fi

if [[ "${#required_paths[@]}" -eq 0 ]]; then
  record_violation "no REQUIRED_PATH rules configured in ${rules_file}"
fi

for doc_path in "${docs[@]}"; do
  if [[ -f "$doc_path" ]]; then
    pass "scope doc present: ${doc_path}"
  else
    record_violation "scope doc missing: ${doc_path}"
  fi
done

for command_text in "${required_commands[@]}"; do
  found=0
  for doc_path in "${docs[@]}"; do
    if [[ ! -f "$doc_path" ]]; then
      continue
    fi
    if contains_literal_in_file "$command_text" "$doc_path"; then
      found=1
      break
    fi
  done

  if [[ "$found" -eq 1 ]]; then
    pass "required command documented: ${command_text}"
  else
    record_violation "required command missing from scoped docs: ${command_text}"
  fi
done

for required_path in "${required_paths[@]}"; do
  if [[ -e "$required_path" ]]; then
    pass "required path exists: ${required_path}"
  else
    record_violation "required path missing from repo: ${required_path}"
    continue
  fi

  documented=0
  for doc_path in "${docs[@]}"; do
    if [[ ! -f "$doc_path" ]]; then
      continue
    fi
    if contains_literal_in_file "$required_path" "$doc_path" || contains_literal_in_file "\$AGENT_HOME/${required_path}" "$doc_path"; then
      documented=1
      break
    fi
  done

  if [[ "$documented" -eq 1 ]]; then
    pass "required path documented: ${required_path}"
  else
    record_violation "required path not referenced in scoped docs: ${required_path}"
  fi
done

is_allowlisted_missing_path() {
  local candidate="${1:-}"
  local allowed_path
  for allowed_path in "${allow_missing_paths[@]-}"; do
    if [[ "$candidate" == "$allowed_path" ]]; then
      return 0
    fi
  done
  return 1
}

should_skip_discovered_token() {
  local candidate="${1:-}"
  if [[ "$candidate" == *"..."* ]]; then
    return 0
  fi
  if [[ "$candidate" == *.json ]]; then
    return 0
  fi
  return 1
}

for doc_path in "${docs[@]}"; do
  [[ -f "$doc_path" ]] || continue
  set +e
  scan_doc_tokens "$doc_path" >>"$path_hits_raw"
  rg_status=$?
  set -e

  if [[ "$rg_status" -gt 1 ]]; then
    record_violation "failed to scan doc for repo-local paths: ${doc_path}"
  fi
done

reference_count=0
if [[ -s "$path_hits_raw" ]]; then
  while IFS= read -r hit; do
    doc_path="${hit%%:*}"
    remainder="${hit#*:}"
    line_no="${remainder%%:*}"
    token="${remainder#*:}"

    normalized="${token#\$AGENT_HOME/}"

    if should_skip_discovered_token "$normalized"; then
      continue
    fi

    if is_allowlisted_missing_path "$normalized"; then
      warn "allowlisted missing path: ${doc_path}:${line_no}:${normalized}"
      continue
    fi

    reference_count=$((reference_count + 1))

    if [[ ! -e "$normalized" ]]; then
      record_violation "stale path reference: ${doc_path}:${line_no}:${normalized}"
    fi
  done < <(sort -u "$path_hits_raw")
fi

if [[ "$reference_count" -gt 0 ]]; then
  pass "validated ${reference_count} repo-local path references"
else
  warn "no repo-local path references discovered in scoped docs"
fi

if [[ "$violation_count" -eq 0 ]]; then
  pass "docs freshness audit passed (check=${check_mode})"
  exit 0
fi

if [[ "$check_mode" -eq 1 ]]; then
  fail "docs freshness audit failed with ${violation_count} violation(s)"
  exit 1
fi

warn "docs freshness audit completed with ${violation_count} violation(s) (check=${check_mode})"
exit 0
