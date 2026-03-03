#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="${1:-}"
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
}

print_cmd() {
  local out=''
  local arg=''
  for arg in "$@"; do
    out+=" $(printf '%q' "$arg")"
  done
  printf '%s\n' "${out# }"
}

run_cmd() {
  if [[ "${dry_run}" == "1" ]]; then
    echo "dry-run: $(print_cmd "$@")" >&2
    return 0
  fi
  "$@"
}

usage() {
  cat <<'USAGE'
Usage:
  manage_issue_pr_review.sh <request-followup|merge|close-pr> [options]

Canonical entrypoint:
  $AGENT_HOME/skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh

Simplification note:
  Legacy wrappers were removed; use this entrypoint directly.

Subcommands:
  request-followup  Main agent comments on PR and mirrors explicit comment URL to issue
  merge             Merge PR and optionally close issue
  close-pr          Close PR without merge and optionally add issue note

Common options:
  --repo <owner/repo>    Target repository (passed to gh with -R)
  --dry-run              Print actions without executing commands

request-followup options:
  --pr <number>                  PR number (required)
  --issue <number>               Issue number (required)
  --body <text>                  PR review comment body
  --body-file <path>             PR review comment body file
  --enforce-review-evidence      Validate review body against review-evidence gate
  --issue-note <text>            Optional extra note appended to issue sync comment
  --issue-note-file <path>       Optional extra note file appended to issue sync comment
  --row-status <in-progress|blocked>
                                Structured follow-up row status (use instead of --issue-note*)
  --next-owner <name>            Structured follow-up next owner (use instead of --issue-note*)
  --lane-action <text>           Structured follow-up lane action (default: continue on existing assigned lane)
  --requested-by <name>          Structured follow-up requester (default: main-agent)

merge options:
  --pr <number>                  PR number (required)
  --method <merge|squash|rebase> Merge method (default: merge)
  --delete-branch                Ask gh to delete branch after merge
  --pr-body <text>               Corrected PR body to apply before merge if current body fails validation
  --pr-body-file <path>          Corrected PR body file to apply before merge if current body fails validation
  --review-evidence <text>       Review evidence comment body for merge decision
  --review-evidence-file <path>  Review evidence comment body file for merge decision
  --enforce-review-evidence      Require and validate merge review evidence before merge
  --issue <number>               Related issue number
  --close-issue                  Close the related issue after merge
  --reason <completed|not planned>
                                Issue close reason when --close-issue is used (default: completed)
  --issue-comment <text>         Optional comment on issue after merge/close
  --issue-comment-file <path>    Optional issue comment file after merge/close

close-pr options:
  --pr <number>                  PR number (required)
  --pr-body <text>               Corrected PR body to apply before close if current body fails validation
  --pr-body-file <path>          Corrected PR body file to apply before close if current body fails validation
  --review-evidence <text>       Review evidence comment body for close-pr decision
  --review-evidence-file <path>  Review evidence comment body file for close-pr decision
  --enforce-review-evidence      Require and validate close-pr review evidence before close
  --comment <text>               Comment to leave on PR close
  --issue <number>               Related issue number (optional)
  --issue-comment <text>         Optional issue comment for traceability
  --issue-comment-file <path>    Optional issue comment file for traceability
  --close-reason <text>          Structured close reason (use instead of --issue-comment*)
  --replacement-pr <value>       Structured replacement PR/lane ref (default: pending)
  --row-status <blocked|in-progress|done>
                                Structured row status after close (default: blocked)
  --next-action <text>           Structured explicit next action (required with --close-reason)
USAGE
}

load_body() {
  local body_text="${1:-}"
  local body_file="${2:-}"

  if [[ -n "$body_text" && -n "$body_file" ]]; then
    die "use either --body or --body-file, not both"
  fi

  if [[ -n "$body_file" ]]; then
    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    cat "$body_file"
    return 0
  fi

  printf '%s' "$body_text"
}

validate_review_evidence_text() {
  local body_text="${1:-}"
  local expected_decision="${2:-}"
  local source_label="${3:-review-evidence}"

  if [[ -z "${body_text//[[:space:]]/}" ]]; then
    echo "error: ${source_label}: review evidence cannot be empty" >&2
    return 1
  fi

  local required_heading_regexes=(
    '^[[:space:]]*##[[:space:]]+Decision[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Review Scope[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Hard Gates[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Task Fidelity[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Correctness[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Integration Readiness[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Evidence Links[[:space:]]*$'
  )
  local required_heading_labels=(
    '## Decision'
    '## Review Scope'
    '## Hard Gates'
    '## Task Fidelity'
    '## Correctness'
    '## Integration Readiness'
    '## Evidence Links'
  )
  local i=0
  for i in "${!required_heading_regexes[@]}"; do
    if ! printf '%s\n' "$body_text" | grep -Eq "${required_heading_regexes[$i]}"; then
      echo "error: ${source_label}: missing required heading '${required_heading_labels[$i]}'" >&2
      return 1
    fi
  done

  local required_line_regexes=(
    '^[[:space:]]*-[[:space:]]*Decision:[[:space:]]*(merge|request-followup|close-pr)[[:space:]]*$'
    '^[[:space:]]*-[[:space:]]*Task lane:[[:space:]]+.+$'
    '^[[:space:]]*-[[:space:]]*Scope verdict:[[:space:]]*(pass|fail|blocked)[[:space:]]*\(evidence:[[:space:]]+.+\)$'
    '^[[:space:]]*-[[:space:]]*Correctness verdict:[[:space:]]*(pass|fail|blocked)[[:space:]]*\(evidence:[[:space:]]+.+\)$'
    '^[[:space:]]*-[[:space:]]*Integration verdict:[[:space:]]*(pass|fail|blocked)[[:space:]]*\(evidence:[[:space:]]+.+\)$'
  )
  local required_line_labels=(
    '- Decision: <merge|request-followup|close-pr>'
    '- Task lane: ...'
    '- Scope verdict: <pass|fail|blocked> (evidence: ...)'
    '- Correctness verdict: <pass|fail|blocked> (evidence: ...)'
    '- Integration verdict: <pass|fail|blocked> (evidence: ...)'
  )
  for i in "${!required_line_regexes[@]}"; do
    if ! printf '%s\n' "$body_text" | grep -Eiq "${required_line_regexes[$i]}"; then
      echo "error: ${source_label}: missing required evidence line '${required_line_labels[$i]}'" >&2
      return 1
    fi
  done

  local placeholder_regexes=(
    '<[^>]+>'
    '(^|[^[:alnum:]_])TO''DO([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])TBD([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])N/A([^[:alnum:]_]|$)'
  )
  local placeholder_labels=(
    '<...>'
    'TO''DO'
    'TBD'
    'N/A'
  )
  for i in "${!placeholder_regexes[@]}"; do
    if printf '%s\n' "$body_text" | grep -Eiq "${placeholder_regexes[$i]}"; then
      echo "error: ${source_label}: disallowed placeholder found: ${placeholder_labels[$i]}" >&2
      return 1
    fi
  done

  local declared_decision=''
  declared_decision="$(
    printf '%s\n' "$body_text" | awk '
      BEGIN { IGNORECASE=1 }
      /^[[:space:]]*-[[:space:]]*Decision:[[:space:]]*/ {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]*Decision:[[:space:]]*/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        print tolower(line)
        exit
      }
    '
  )"
  if [[ -z "$declared_decision" ]]; then
    echo "error: ${source_label}: cannot parse declared decision" >&2
    return 1
  fi
  if [[ -n "$expected_decision" && "$declared_decision" != "$expected_decision" ]]; then
    echo "error: ${source_label}: decision mismatch (expected=${expected_decision}, found=${declared_decision})" >&2
    return 1
  fi

  local evidence_marker_count=0
  evidence_marker_count="$(printf '%s\n' "$body_text" | grep -Eic 'evidence:[[:space:]]+.+')"
  if [[ "${evidence_marker_count}" -lt 6 ]]; then
    echo "error: ${source_label}: insufficient evidence anchors (need >=6 'evidence:' entries, found ${evidence_marker_count})" >&2
    return 1
  fi

  local file_ref_count=0
  file_ref_count="$(printf '%s\n' "$body_text" | grep -Eoc '([[:alnum:]_.-]+/)+[[:alnum:]_.-]+' || true)"
  if [[ "${file_ref_count}" -lt 2 ]]; then
    echo "error: ${source_label}: evidence must cite concrete file/path references (need >=2)" >&2
    return 1
  fi

  if [[ "$expected_decision" == "merge" ]]; then
    if printf '%s\n' "$body_text" | grep -Eiq '(scope|correctness|integration)[[:space:]]+verdict:[[:space:]]*(fail|blocked)'; then
      echo "error: ${source_label}: merge decision cannot include fail/blocked core verdicts" >&2
      return 1
    fi
  fi

  if [[ "$expected_decision" == "request-followup" || "$expected_decision" == "close-pr" ]]; then
    if ! printf '%s\n' "$body_text" | grep -Eiq '(scope|correctness|integration)[[:space:]]+verdict:[[:space:]]*(fail|blocked)'; then
      echo "error: ${source_label}: ${expected_decision} must include at least one fail/blocked core verdict" >&2
      return 1
    fi
  fi

  return 0
}

validate_review_evidence_input() {
  local body_text="${1:-}"
  local body_file="${2:-}"
  local expected_decision="${3:-}"
  local source_label="${4:-review-evidence}"

  local normalized_body=''
  normalized_body="$(load_body "$body_text" "$body_file")"
  validate_review_evidence_text "$normalized_body" "$expected_decision" "$source_label"
}

post_review_evidence_comment() {
  local pr_number="${1:-}"
  local evidence_text="${2:-}"
  local issue_number="${3:-}"

  [[ -n "$pr_number" ]] || die "PR number is required for review evidence comment"
  [[ -n "$evidence_text" ]] || die "review evidence comment body is required"

  local pr_comment_cmd=(gh pr comment "$pr_number")
  if [[ -n "$repo_arg" ]]; then
    pr_comment_cmd+=(-R "$repo_arg")
  fi
  pr_comment_cmd+=(--body "$evidence_text")
  run_cmd "${pr_comment_cmd[@]}" >/dev/null

  local evidence_comment_url=''
  if [[ "$dry_run" == "1" ]]; then
    evidence_comment_url="DRY-RUN-PR-COMMENT-URL"
  else
    local view_cmd=(gh pr view "$pr_number")
    if [[ -n "$repo_arg" ]]; then
      view_cmd+=(-R "$repo_arg")
    fi
    view_cmd+=(--json comments -q '.comments[-1].url')
    evidence_comment_url="$(run_cmd "${view_cmd[@]}")"
  fi

  if [[ -n "$issue_number" ]]; then
    printf '%s\n' "Main-agent review evidence for PR #${pr_number}: ${evidence_comment_url}"
  else
    printf '%s\n' "${evidence_comment_url}"
  fi
}

validate_followup_row_status() {
  local row_status="${1:-}"
  case "$row_status" in
    in-progress|blocked)
      ;;
    *)
      die "--row-status for request-followup must be one of: in-progress, blocked"
      ;;
  esac
}

validate_close_row_status() {
  local row_status="${1:-}"
  case "$row_status" in
    blocked|in-progress|done)
      ;;
    *)
      die "--row-status for close-pr must be one of: blocked, in-progress, done"
      ;;
  esac
}

build_followup_issue_note() {
  local next_owner="${1:-}"
  local row_status="${2:-}"
  local lane_action="${3:-}"
  local requested_by="${4:-}"

  [[ -n "$next_owner" ]] || die "--next-owner is required when using structured follow-up fields"
  [[ -n "$row_status" ]] || die "--row-status is required when using structured follow-up fields"
  validate_followup_row_status "$row_status"

  if [[ -z "$lane_action" ]]; then
    lane_action="continue on existing assigned lane"
  fi
  if [[ -z "$requested_by" ]]; then
    requested_by="main-agent"
  fi

  printf '%s\n' \
    "- Next owner: \`$next_owner\`" \
    "- Row status: \`$row_status\`" \
    "- Lane action: $lane_action" \
    "- Requested by: \`$requested_by\`" \
    "- Action: update PR and reply with evidence in-thread"
}

build_close_issue_comment() {
  local pr_number="${1:-}"
  local close_reason="${2:-}"
  local replacement_pr="${3:-}"
  local row_status="${4:-}"
  local next_action="${5:-}"

  [[ -n "$pr_number" ]] || die "PR number is required for structured close issue comment"
  [[ -n "$close_reason" ]] || die "--close-reason is required when using structured close outcome fields"
  [[ -n "$next_action" ]] || die "--next-action is required when using structured close outcome fields"

  if [[ -z "$replacement_pr" ]]; then
    replacement_pr="pending"
  fi
  if [[ -z "$row_status" ]]; then
    row_status="blocked"
  fi
  validate_close_row_status "$row_status"

  printf '%s\n' \
    "Main-agent closed PR #\`$pr_number\`: \`$close_reason\`" \
    "" \
    "- Lane state: retired" \
    "- Replacement lane / PR: \`$replacement_pr\`" \
    "- Row status: \`$row_status\`" \
    "- Next action: \`$next_action\`" \
    "- Note: do not resume the closed lane unless main-agent explicitly reassigns it"
}

validate_pr_body_hygiene_text() {
  local body_text="${1:-}"
  local issue_number="${2:-}"
  local source_label="${3:-pr-body-check}"

  if [[ -z "${body_text//[[:space:]]/}" ]]; then
    echo "error: ${source_label}: PR body cannot be empty" >&2
    return 1
  fi

  local required_heading_regexes=(
    '^[[:space:]]*##[[:space:]]+Summary[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Scope[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Testing[[:space:]]*$'
    '^[[:space:]]*##[[:space:]]+Issue[[:space:]]*$'
  )
  local required_heading_labels=(
    '## Summary'
    '## Scope'
    '## Testing'
    '## Issue'
  )
  local i=0
  for i in "${!required_heading_regexes[@]}"; do
    if ! printf '%s\n' "$body_text" | grep -Eq "${required_heading_regexes[$i]}"; then
      echo "error: ${source_label}: missing required heading '${required_heading_labels[$i]}'" >&2
      return 1
    fi
  done

  local placeholder_regexes=(
    '<[^>]+>'
    '(^|[^[:alnum:]_])TO''DO([^[:alnum:]_]|$)'
    '(^|[^[:alnum:]_])TBD([^[:alnum:]_]|$)'
    '#<number>'
    'not[[:space:]]+run[[:space:]]*\(reason\)'
    '<command>[[:space:]]*\(pass\)'
  )
  local placeholder_labels=(
    '<...>'
    'TO''DO'
    'TBD'
    '#<number>'
    'not run (reason)'
    '<command> (pass)'
  )
  for i in "${!placeholder_regexes[@]}"; do
    if printf '%s\n' "$body_text" | grep -Eiq "${placeholder_regexes[$i]}"; then
      echo "error: ${source_label}: disallowed placeholder found: ${placeholder_labels[$i]}" >&2
      return 1
    fi
  done

  if [[ -n "$issue_number" ]]; then
    if ! printf '%s\n' "$body_text" | grep -Eq "^[[:space:]]*-[[:space:]]*#${issue_number}([^0-9]|$)"; then
      echo "error: ${source_label}: missing required issue bullet '- #${issue_number}'" >&2
      return 1
    fi
  fi

  return 0
}

validate_pr_body_hygiene_input() {
  local body_text="${1:-}"
  local body_file="${2:-}"
  local issue_number="${3:-}"
  local source_label="${4:-pr-body-check}"

  local normalized_body=''
  normalized_body="$(load_body "$body_text" "$body_file")"
  validate_pr_body_hygiene_text "$normalized_body" "$issue_number" "$source_label"
}

ensure_pr_body_hygiene_for_close() {
  local pr_number="${1:-}"
  local issue_number="${2:-}"
  local override_body="${3:-}"
  local override_body_file="${4:-}"
  local action_label="${5:-merge}"

  [[ -n "$pr_number" ]] || die "PR number is required for PR body hygiene check"

  if [[ "$dry_run" == "1" ]]; then
    if [[ -n "$override_body" || -n "$override_body_file" ]]; then
      validate_pr_body_hygiene_input "$override_body" "$override_body_file" "$issue_number" "${action_label}-override"
    fi
    return 0
  fi

  require_cmd gh

  local view_cmd=(gh pr view "$pr_number")
  if [[ -n "$repo_arg" ]]; then
    view_cmd+=(-R "$repo_arg")
  fi
  view_cmd+=(--json body -q .body)
  local current_body=''
  current_body="$(run_cmd "${view_cmd[@]}")"

  if validate_pr_body_hygiene_input "$current_body" "" "$issue_number" "${action_label}-current"; then
    return 0
  fi

  if [[ -z "$override_body" && -z "$override_body_file" ]]; then
    die "PR #$pr_number body failed validation before ${action_label}; provide --pr-body or --pr-body-file to correct it"
  fi

  validate_pr_body_hygiene_input "$override_body" "$override_body_file" "$issue_number" "${action_label}-override"

  local edit_cmd=(gh pr edit "$pr_number")
  if [[ -n "$repo_arg" ]]; then
    edit_cmd+=(-R "$repo_arg")
  fi
  if [[ -n "$override_body" ]]; then
    edit_cmd+=(--body "$override_body")
  else
    edit_cmd+=(--body-file "$override_body_file")
  fi
  run_cmd "${edit_cmd[@]}" >/dev/null

  current_body="$(run_cmd "${view_cmd[@]}")"
  validate_pr_body_hygiene_input "$current_body" "" "$issue_number" "${action_label}-updated"
}

subcommand="${1:-}"
if [[ -z "$subcommand" ]]; then
  usage >&2
  exit 1
fi
shift || true

dry_run="0"
repo_arg=""

case "$subcommand" in
  request-followup)
    pr_number=""
    issue_number=""
    body=""
    body_file=""
    issue_note=""
    issue_note_file=""
    row_status=""
    next_owner=""
    lane_action=""
    requested_by=""
    enforce_review_evidence="0"

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --pr)
          pr_number="${2:-}"
          shift 2
          ;;
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --body)
          body="${2:-}"
          shift 2
          ;;
        --body-file)
          body_file="${2:-}"
          shift 2
          ;;
        --issue-note)
          issue_note="${2:-}"
          shift 2
          ;;
        --issue-note-file)
          issue_note_file="${2:-}"
          shift 2
          ;;
        --row-status)
          row_status="${2:-}"
          shift 2
          ;;
        --next-owner)
          next_owner="${2:-}"
          shift 2
          ;;
        --lane-action)
          lane_action="${2:-}"
          shift 2
          ;;
        --requested-by)
          requested_by="${2:-}"
          shift 2
          ;;
        --enforce-review-evidence)
          enforce_review_evidence="1"
          shift
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for request-followup: $1"
          ;;
      esac
    done

    [[ -n "$pr_number" ]] || die "--pr is required for request-followup"
    [[ -n "$issue_number" ]] || die "--issue is required for request-followup"

    review_body="$(load_body "$body" "$body_file")"
    [[ -n "$review_body" ]] || die "review body is required (--body or --body-file)"
    if [[ "$enforce_review_evidence" == "1" ]]; then
      validate_review_evidence_text "$review_body" "request-followup" "request-followup-review-evidence"
    fi
    followup_structured="0"
    if [[ -n "$row_status" || -n "$next_owner" || -n "$lane_action" || -n "$requested_by" ]]; then
      followup_structured="1"
    fi
    if [[ "$followup_structured" == "1" ]]; then
      if [[ -n "$issue_note" || -n "$issue_note_file" ]]; then
        die "use either --issue-note/--issue-note-file or structured follow-up fields, not both"
      fi
      issue_note="$(build_followup_issue_note "$next_owner" "$row_status" "$lane_action" "$requested_by")"
    else
      issue_note="$(load_body "$issue_note" "$issue_note_file")"
    fi

    require_cmd gh

    pr_comment_cmd=(gh pr comment "$pr_number")
    if [[ -n "$repo_arg" ]]; then
      pr_comment_cmd+=(-R "$repo_arg")
    fi
    pr_comment_cmd+=(--body "$review_body")

    if [[ "$dry_run" == "1" ]]; then
      run_cmd "${pr_comment_cmd[@]}"
      pr_comment_url="DRY-RUN-PR-COMMENT-URL"
      issue_sync="Main-agent requested updates in PR #${pr_number}: ${pr_comment_url}"
      if [[ -n "$issue_note" ]]; then
        issue_sync+=$'\n'
        issue_sync+="$issue_note"
      fi
      issue_cmd=(gh issue comment "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        issue_cmd+=(-R "$repo_arg")
      fi
      issue_cmd+=(--body "$issue_sync")
      run_cmd "${issue_cmd[@]}"
      echo "$pr_comment_url"
      exit 0
    fi

    run_cmd "${pr_comment_cmd[@]}"

    view_cmd=(gh pr view "$pr_number")
    if [[ -n "$repo_arg" ]]; then
      view_cmd+=(-R "$repo_arg")
    fi
    view_cmd+=(--json comments -q '.comments[-1].url')
    pr_comment_url="$(run_cmd "${view_cmd[@]}")"

    issue_sync="Main-agent requested updates in PR #${pr_number}: ${pr_comment_url}"
    if [[ -n "$issue_note" ]]; then
      issue_sync+=$'\n'
      issue_sync+="$issue_note"
    fi

    issue_cmd=(gh issue comment "$issue_number")
    if [[ -n "$repo_arg" ]]; then
      issue_cmd+=(-R "$repo_arg")
    fi
    issue_cmd+=(--body "$issue_sync")
    run_cmd "${issue_cmd[@]}"

    echo "$pr_comment_url"
    ;;

  merge)
    pr_number=""
    method="merge"
    delete_branch="0"
    pr_body=""
    pr_body_file=""
    issue_number=""
    close_issue="0"
    close_reason="completed"
    issue_comment=""
    issue_comment_file=""
    review_evidence=""
    review_evidence_file=""
    enforce_review_evidence="0"

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --pr)
          pr_number="${2:-}"
          shift 2
          ;;
        --method)
          method="${2:-}"
          shift 2
          ;;
        --delete-branch)
          delete_branch="1"
          shift
          ;;
        --pr-body)
          pr_body="${2:-}"
          shift 2
          ;;
        --pr-body-file)
          pr_body_file="${2:-}"
          shift 2
          ;;
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --close-issue)
          close_issue="1"
          shift
          ;;
        --reason)
          close_reason="${2:-}"
          shift 2
          ;;
        --issue-comment)
          issue_comment="${2:-}"
          shift 2
          ;;
        --issue-comment-file)
          issue_comment_file="${2:-}"
          shift 2
          ;;
        --review-evidence)
          review_evidence="${2:-}"
          shift 2
          ;;
        --review-evidence-file)
          review_evidence_file="${2:-}"
          shift 2
          ;;
        --enforce-review-evidence)
          enforce_review_evidence="1"
          shift
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for merge: $1"
          ;;
      esac
    done

    [[ -n "$pr_number" ]] || die "--pr is required for merge"

    if [[ "$method" != "merge" && "$method" != "squash" && "$method" != "rebase" ]]; then
      die "--method must be one of: merge, squash, rebase"
    fi

    if [[ "$close_issue" == "1" && -z "$issue_number" ]]; then
      die "--issue is required when --close-issue is set"
    fi
    if [[ -n "$pr_body" && -n "$pr_body_file" ]]; then
      die "use either --pr-body or --pr-body-file, not both"
    fi
    if [[ -n "$pr_body_file" && ! -f "$pr_body_file" ]]; then
      die "pr body file not found: $pr_body_file"
    fi

    if [[ "$close_reason" != "completed" && "$close_reason" != "not planned" ]]; then
      die "--reason must be one of: completed, not planned"
    fi
    issue_comment="$(load_body "$issue_comment" "$issue_comment_file")"
    require_cmd gh

    if [[ -n "$review_evidence" && -n "$review_evidence_file" ]]; then
      die "use either --review-evidence or --review-evidence-file, not both"
    fi
    if [[ -n "$review_evidence_file" && ! -f "$review_evidence_file" ]]; then
      die "review evidence file not found: $review_evidence_file"
    fi
    if [[ "$enforce_review_evidence" == "1" && -z "$review_evidence" && -z "$review_evidence_file" ]]; then
      die "merge requires --review-evidence or --review-evidence-file when --enforce-review-evidence is set"
    fi
    if [[ -n "$review_evidence" || -n "$review_evidence_file" ]]; then
      validate_review_evidence_input "$review_evidence" "$review_evidence_file" "merge" "merge-review-evidence"
      review_evidence="$(load_body "$review_evidence" "$review_evidence_file")"
      evidence_issue_note="$(post_review_evidence_comment "$pr_number" "$review_evidence" "$issue_number")"
      if [[ -n "$issue_number" ]]; then
        if [[ -n "$issue_comment" ]]; then
          issue_comment+=$'\n'
          issue_comment+="$evidence_issue_note"
        else
          issue_comment="$evidence_issue_note"
        fi
      fi
    fi
    ensure_pr_body_hygiene_for_close "$pr_number" "$issue_number" "$pr_body" "$pr_body_file" "merge"

    # `gh pr merge` rejects draft PRs; auto-ready them for deterministic merge flows.
    pr_is_draft="false"
    pr_state="OPEN"
    if [[ "$dry_run" != "1" ]]; then
      pr_view_cmd=(gh pr view "$pr_number")
      if [[ -n "$repo_arg" ]]; then
        pr_view_cmd+=(-R "$repo_arg")
      fi
      pr_view_cmd+=(--json "isDraft,state" -q '[.isDraft, .state] | @tsv')
      pr_meta="$(run_cmd "${pr_view_cmd[@]}")"
      IFS=$'\t' read -r pr_is_draft pr_state <<<"$pr_meta"

      if [[ "$pr_state" != "OPEN" ]]; then
        die "PR #$pr_number is not OPEN (state=$pr_state)"
      fi
    fi

    if [[ "$pr_is_draft" == "true" ]]; then
      ready_cmd=(gh pr ready "$pr_number")
      if [[ -n "$repo_arg" ]]; then
        ready_cmd+=(-R "$repo_arg")
      fi
      run_cmd "${ready_cmd[@]}"
    fi

    merge_cmd=(gh pr merge "$pr_number" "--$method")
    if [[ -n "$repo_arg" ]]; then
      merge_cmd+=(-R "$repo_arg")
    fi
    if [[ "$delete_branch" == "1" ]]; then
      merge_cmd+=(--delete-branch)
    fi
    if gh pr merge --help 2>/dev/null | grep -q -- '--yes'; then
      merge_cmd+=(--yes)
    fi

    run_cmd "${merge_cmd[@]}"

    if [[ -n "$issue_number" ]]; then
      if [[ "$close_issue" == "1" ]]; then
        close_cmd=(gh issue close "$issue_number")
        if [[ -n "$repo_arg" ]]; then
          close_cmd+=(-R "$repo_arg")
        fi
        close_cmd+=(--reason "$close_reason")
        if [[ -n "$issue_comment" ]]; then
          close_cmd+=(--comment "$issue_comment")
        fi
        run_cmd "${close_cmd[@]}"
      elif [[ -n "$issue_comment" ]]; then
        comment_cmd=(gh issue comment "$issue_number")
        if [[ -n "$repo_arg" ]]; then
          comment_cmd+=(-R "$repo_arg")
        fi
        comment_cmd+=(--body "$issue_comment")
        run_cmd "${comment_cmd[@]}"
      fi
    fi
    ;;

  close-pr)
    pr_number=""
    pr_body=""
    pr_body_file=""
    pr_comment=""
    issue_number=""
    issue_comment=""
    issue_comment_file=""
    close_reason=""
    replacement_pr=""
    row_status=""
    next_action=""
    review_evidence=""
    review_evidence_file=""
    enforce_review_evidence="0"

    while [[ $# -gt 0 ]]; do
      case "${1:-}" in
        --pr)
          pr_number="${2:-}"
          shift 2
          ;;
        --pr-body)
          pr_body="${2:-}"
          shift 2
          ;;
        --pr-body-file)
          pr_body_file="${2:-}"
          shift 2
          ;;
        --comment)
          pr_comment="${2:-}"
          shift 2
          ;;
        --issue)
          issue_number="${2:-}"
          shift 2
          ;;
        --issue-comment)
          issue_comment="${2:-}"
          shift 2
          ;;
        --issue-comment-file)
          issue_comment_file="${2:-}"
          shift 2
          ;;
        --close-reason)
          close_reason="${2:-}"
          shift 2
          ;;
        --replacement-pr)
          replacement_pr="${2:-}"
          shift 2
          ;;
        --row-status)
          row_status="${2:-}"
          shift 2
          ;;
        --next-action)
          next_action="${2:-}"
          shift 2
          ;;
        --review-evidence)
          review_evidence="${2:-}"
          shift 2
          ;;
        --review-evidence-file)
          review_evidence_file="${2:-}"
          shift 2
          ;;
        --enforce-review-evidence)
          enforce_review_evidence="1"
          shift
          ;;
        --repo)
          repo_arg="${2:-}"
          shift 2
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "unknown option for close-pr: $1"
          ;;
      esac
    done

    [[ -n "$pr_number" ]] || die "--pr is required for close-pr"
    if [[ -n "$pr_body" && -n "$pr_body_file" ]]; then
      die "use either --pr-body or --pr-body-file, not both"
    fi
    if [[ -n "$pr_body_file" && ! -f "$pr_body_file" ]]; then
      die "pr body file not found: $pr_body_file"
    fi
    close_structured="0"
    if [[ -n "$close_reason" || -n "$replacement_pr" || -n "$row_status" || -n "$next_action" ]]; then
      close_structured="1"
    fi
    if [[ "$close_structured" == "1" ]]; then
      if [[ -n "$issue_comment" || -n "$issue_comment_file" ]]; then
        die "use either --issue-comment/--issue-comment-file or structured close outcome fields, not both"
      fi
      [[ -n "$issue_number" ]] || die "--issue is required when using structured close outcome fields"
      issue_comment="$(build_close_issue_comment "$pr_number" "$close_reason" "$replacement_pr" "$row_status" "$next_action")"
    else
      issue_comment="$(load_body "$issue_comment" "$issue_comment_file")"
    fi
    require_cmd gh

    if [[ -n "$review_evidence" && -n "$review_evidence_file" ]]; then
      die "use either --review-evidence or --review-evidence-file, not both"
    fi
    if [[ -n "$review_evidence_file" && ! -f "$review_evidence_file" ]]; then
      die "review evidence file not found: $review_evidence_file"
    fi
    if [[ "$enforce_review_evidence" == "1" && -z "$review_evidence" && -z "$review_evidence_file" ]]; then
      die "close-pr requires --review-evidence or --review-evidence-file when --enforce-review-evidence is set"
    fi
    if [[ -n "$review_evidence" || -n "$review_evidence_file" ]]; then
      validate_review_evidence_input "$review_evidence" "$review_evidence_file" "close-pr" "close-pr-review-evidence"
      review_evidence="$(load_body "$review_evidence" "$review_evidence_file")"
      evidence_issue_note="$(post_review_evidence_comment "$pr_number" "$review_evidence" "$issue_number")"
      if [[ -n "$issue_number" ]]; then
        if [[ -n "$issue_comment" ]]; then
          issue_comment+=$'\n'
          issue_comment+="$evidence_issue_note"
        else
          issue_comment="$evidence_issue_note"
        fi
      fi
    fi

    ensure_pr_body_hygiene_for_close "$pr_number" "$issue_number" "$pr_body" "$pr_body_file" "close-pr"

    close_pr_cmd=(gh pr close "$pr_number")
    if [[ -n "$repo_arg" ]]; then
      close_pr_cmd+=(-R "$repo_arg")
    fi
    if [[ -n "$pr_comment" ]]; then
      close_pr_cmd+=(--comment "$pr_comment")
    fi

    run_cmd "${close_pr_cmd[@]}"

    if [[ -n "$issue_number" && -n "$issue_comment" ]]; then
      issue_cmd=(gh issue comment "$issue_number")
      if [[ -n "$repo_arg" ]]; then
        issue_cmd+=(-R "$repo_arg")
      fi
      issue_cmd+=(--body "$issue_comment")
      run_cmd "${issue_cmd[@]}"
    fi
    ;;

  -h|--help)
    usage
    ;;

  *)
    die "unknown subcommand: $subcommand"
    ;;
esac
