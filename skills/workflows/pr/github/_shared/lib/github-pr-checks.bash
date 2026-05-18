github_pr_checks_is_missing_output() {
  local text="${1:-}"
  printf '%s\n' "$text" | grep -Eqi 'no (checks|check runs|status checks|check suites)|checks? (have|has) not been reported|no checks reported|no check runs found|no status checks found'
}

github_pr_checks_contains_failed_state() {
  local text="${1:-}"
  printf '%s\n' "$text" | grep -Eqi '(^|[[:space:]])(fail|failed|cancel|cancelled|timed_out|timed out|action_required|startup_failure|blocked|skipped)([[:space:]]|$)'
}

github_pr_checks_contains_pending_state() {
  local text="${1:-}"
  printf '%s\n' "$text" | grep -Eqi '(^|[[:space:]])(pending|queued|waiting|in_progress|in progress|requested|expected)([[:space:]]|$)'
}

github_pr_checks_status_code() {
  case "${1:-}" in
    passed)
      return 0
      ;;
    missing)
      return 3
      ;;
    failed|unknown|"")
      return 4
      ;;
    pending)
      return 5
      ;;
  esac
  return 4
}

github_pr_checks_classify_json() {
  python3 -c '
import json
import sys

try:
    checks = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit(2)

if not isinstance(checks, list):
    raise SystemExit(2)
if not checks:
    print("missing")
    raise SystemExit(0)

failed_buckets = {"fail", "cancel"}
pending_buckets = {"pending", "skipping"}
failed_states = {
    "fail",
    "failed",
    "cancel",
    "cancelled",
    "timed_out",
    "action_required",
    "startup_failure",
    "blocked",
    "skipped",
}
pending_states = {"pending", "queued", "waiting", "in_progress", "requested", "expected"}
pass_states = {"pass", "passed", "success", "successful", "completed"}

for check in checks:
    if not isinstance(check, dict):
        print("unknown")
        raise SystemExit(0)
    bucket = str(check.get("bucket", "")).lower()
    state = str(check.get("state", "")).lower()
    if bucket in failed_buckets or state in failed_states:
        print("failed")
        raise SystemExit(0)
    if bucket in pending_buckets or state in pending_states:
        print("pending")
        raise SystemExit(0)
    if bucket == "pass" or state in pass_states:
        continue
    print("unknown")
    raise SystemExit(0)

print("passed")
'
}

github_pr_checks_status_from_text() {
  local output="${1:-}"

  if github_pr_checks_is_missing_output "$output"; then
    printf '%s\n' "missing"
    return 3
  fi

  if github_pr_checks_contains_failed_state "$output"; then
    printf '%s\n' "failed"
    return 4
  fi

  if github_pr_checks_contains_pending_state "$output"; then
    printf '%s\n' "pending"
    return 5
  fi

  printf '%s\n' "unknown"
  return 4
}

github_pr_checks_status_from_json_or_text() {
  local output="${1:-}"
  local rc="${2:-0}"
  local status=''

  if [[ "$rc" -eq 0 || "$rc" -eq 8 ]]; then
    status="$(printf '%s' "$output" | github_pr_checks_classify_json 2>/dev/null || true)"
    if [[ -n "$status" ]]; then
      printf '%s\n' "$status"
      github_pr_checks_status_code "$status"
      return $?
    fi
  fi

  github_pr_checks_status_from_text "$output"
}

github_pr_checks_all_status_for_pr() {
  local pr="${1:-}"
  local output=''
  local rc=0
  local status=''

  set +e
  output="$(gh pr checks "$pr" --json name,state,bucket 2>&1)"
  rc=$?
  set -e

  set +e
  status="$(github_pr_checks_status_from_json_or_text "$output" "$rc")"
  rc=$?
  set -e
  printf '%s\n' "$status"
  return "$rc"
}

github_pr_checks_status_for_pr() {
  local pr="${1:-}"
  local output=''
  local rc=0
  local status=''

  set +e
  output="$(gh pr checks "$pr" --required --json name,state,bucket 2>&1)"
  rc=$?
  set -e

  set +e
  status="$(github_pr_checks_status_from_json_or_text "$output" "$rc")"
  rc=$?
  set -e

  if [[ "$status" == "missing" ]]; then
    github_pr_checks_all_status_for_pr "$pr"
    return $?
  fi

  printf '%s\n' "$status"
  return "$rc"
}
