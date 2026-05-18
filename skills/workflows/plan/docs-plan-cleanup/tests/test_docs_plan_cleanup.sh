#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(cd "${script_dir}/.." && pwd)"
entrypoint="${skill_root}/scripts/docs-plan-cleanup.sh"

if [[ ! -f "${skill_root}/SKILL.md" ]]; then
  echo "error: missing SKILL.md" >&2
  exit 1
fi
if [[ ! -f "$entrypoint" ]]; then
  echo "error: missing scripts/docs-plan-cleanup.sh" >&2
  exit 1
fi

bash "$entrypoint" --help >/dev/null

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

setup_repo() {
  local repo="$1"
  mkdir -p "$repo"
  (
    cd "$repo"
    git init >/dev/null
    mkdir -p docs/plans docs/reports docs/specs docs/runbooks/heuristic-system/error-inbox

    cat > docs/plans/a-plan.md <<'EOF_INNER'
# A plan
EOF_INNER
    cat > docs/plans/b-plan.md <<'EOF_INNER'
# B plan
EOF_INNER
    cat > docs/reports/a-summary.md <<'EOF_INNER'
Plan source: docs/plans/a-plan.md
EOF_INNER
    cat > docs/reports/retained.md <<'EOF_INNER'
Retain me because another markdown file references this doc.
Source: docs/plans/a-plan.md
EOF_INNER
    cat > docs/reports/mixed.md <<'EOF_INNER'
Links:
- docs/plans/a-plan.md
- docs/plans/b-plan.md
EOF_INNER
    cat > docs/specs/a-policy.md <<'EOF_INNER'
Policy derived from docs/plans/a-plan.md
EOF_INNER
    cat > README.md <<'EOF_INNER'
Migration note: docs/plans/a-plan.md
EOF_INNER
    cat > docs/runbooks/report-consumer.md <<'EOF_INNER'
Uses docs/reports/retained.md during validation.
EOF_INNER
    cat > docs/runbooks/heuristic-system/error-inbox/a-gap.md <<'EOF_INNER'
# A gap

Observed from docs/plans/a-plan.md.
EOF_INNER
  )
}

repo_one="${tmp_root}/repo-one"
setup_repo "$repo_one"

cat > "${repo_one}/keep.txt" <<'EOF_KEEP'
# preserve this one
b-plan
EOF_KEEP

dry_run_output="$(bash "$entrypoint" --project-path "$repo_one" --keep-plans-file "${repo_one}/keep.txt")"
echo "$dry_run_output" | grep -Fq "=== docs-plan-cleanup-report:v1 ==="
echo "$dry_run_output" | grep -Fq "[plan_md_to_clean]"
echo "$dry_run_output" | grep -Fq "count: 1"
echo "$dry_run_output" | grep -Fq -- "- docs/plans/a-plan.md"
echo "$dry_run_output" | grep -Fq "[plan_related_md_to_clean]"
echo "$dry_run_output" | grep -Fq -- "- docs/reports/a-summary.md"
echo "$dry_run_output" | grep -Fq "[plan_related_md_kept_referenced_elsewhere]"
echo "$dry_run_output" | grep -Fq -- "- docs/reports/retained.md"
echo "$dry_run_output" | grep -Fq "referenced_by: docs/runbooks/report-consumer.md"
echo "$dry_run_output" | grep -Fq "[plan_related_md_to_rehome]"
echo "$dry_run_output" | grep -Fq -- "- docs/specs/a-policy.md"
echo "$dry_run_output" | grep -Fq "[plan_related_md_manual_review]"
echo "$dry_run_output" | grep -Fq -- "- docs/reports/mixed.md"
echo "$dry_run_output" | grep -Fq -- "- docs/runbooks/heuristic-system/error-inbox/a-gap.md"
echo "$dry_run_output" | grep -Fq "[non_docs_md_referencing_removed_plan]"
echo "$dry_run_output" | grep -Fq -- "- README.md"
echo "$dry_run_output" | grep -Fq "project_path_source: --project-path"
echo "$dry_run_output" | grep -Fq "[execution]"
echo "$dry_run_output" | grep -Fq "status: skipped (dry-run)"

bash "$entrypoint" --project-path "$repo_one" --keep-plan b-plan --execute >/dev/null
[[ ! -f "${repo_one}/docs/plans/a-plan.md" ]]
[[ -f "${repo_one}/docs/plans/b-plan.md" ]]
[[ ! -f "${repo_one}/docs/reports/a-summary.md" ]]
[[ -f "${repo_one}/docs/reports/retained.md" ]]
[[ -f "${repo_one}/docs/reports/mixed.md" ]]
[[ -f "${repo_one}/docs/specs/a-policy.md" ]]
[[ -f "${repo_one}/docs/runbooks/heuristic-system/error-inbox/a-gap.md" ]]
[[ -f "${repo_one}/docs/runbooks/report-consumer.md" ]]

repo_two="${tmp_root}/repo-two"
setup_repo "$repo_two"

bash "$entrypoint" --project-path "$repo_two" --keep-plan b-plan --execute --delete-important >/dev/null
[[ ! -f "${repo_two}/docs/specs/a-policy.md" ]]
[[ -f "${repo_two}/docs/reports/retained.md" ]]
[[ -f "${repo_two}/docs/runbooks/heuristic-system/error-inbox/a-gap.md" ]]

repo_three="${tmp_root}/repo-three"
setup_repo "$repo_three"

project_path_output="$(PROJECT_PATH="$repo_three" bash "$entrypoint" --keep-plan b-plan --execute)"
echo "$project_path_output" | grep -Fq "project_path_source: PROJECT_PATH"
[[ ! -f "${repo_three}/docs/plans/a-plan.md" ]]
[[ -f "${repo_three}/docs/plans/b-plan.md" ]]

repo_four="${tmp_root}/repo-four"
setup_repo "$repo_four"

PROJECT_PATH="/path/does/not/exist" bash "$entrypoint" --project-path "$repo_four" --keep-plan b-plan --execute >/dev/null
[[ ! -f "${repo_four}/docs/plans/a-plan.md" ]]
[[ -f "${repo_four}/docs/plans/b-plan.md" ]]

repo_five="${tmp_root}/repo-five"
setup_repo "$repo_five"
cat > "${repo_five}/docs/plans/a-review-source.md" <<'EOF_INNER'
# A review source
EOF_INNER

source_keep_output="$(bash "$entrypoint" --project-path "$repo_five" --keep-plan a-review-source)"
echo "$source_keep_output" | grep -Fq -- "- docs/plans/a-review-source.md"

bash "$entrypoint" --project-path "$repo_five" --keep-plan a-review-source --execute >/dev/null
[[ -f "${repo_five}/docs/plans/a-review-source.md" ]]
[[ ! -f "${repo_five}/docs/plans/a-plan.md" ]]
[[ ! -f "${repo_five}/docs/plans/b-plan.md" ]]

repo_six="${tmp_root}/repo-six"
mkdir -p "$repo_six"
(
  cd "$repo_six"
  git init >/dev/null
  mkdir -p docs/plans/keep docs/plans/stale
  cat > docs/plans/keep/keep-plan.md <<'EOF_INNER'
# Keep plan
EOF_INNER
  cat > docs/plans/keep/keep-discussion-source.md <<'EOF_INNER'
# Keep discussion source
EOF_INNER
  cat > docs/plans/keep/keep-review-source.md <<'EOF_INNER'
# Keep review source
EOF_INNER
  cat > docs/plans/keep/keep-execution-state.md <<'EOF_INNER'
# Keep execution state
EOF_INNER
  cat > docs/plans/stale/stale-plan.md <<'EOF_INNER'
# Stale plan
EOF_INNER
  cat > docs/plans/stale/stale-discussion-source.md <<'EOF_INNER'
# Stale discussion source
EOF_INNER
  cat > docs/plans/stale/stale-review-source.md <<'EOF_INNER'
# Stale review source
EOF_INNER
  cat > docs/plans/stale/stale-execution-state.md <<'EOF_INNER'
# Stale execution state
EOF_INNER
)

nested_output="$(bash "$entrypoint" --project-path "$repo_six" --keep-plan keep)"
echo "$nested_output" | grep -Fq "plan_md_to_keep: 4"
echo "$nested_output" | grep -Fq "plan_md_to_clean: 4"
echo "$nested_output" | grep -Fq -- "- docs/plans/keep/keep-plan.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/keep/keep-discussion-source.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/keep/keep-review-source.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/keep/keep-execution-state.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/stale/stale-plan.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/stale/stale-discussion-source.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/stale/stale-review-source.md"
echo "$nested_output" | grep -Fq -- "- docs/plans/stale/stale-execution-state.md"

bash "$entrypoint" --project-path "$repo_six" --keep-plan keep --execute --delete-empty-dirs >/dev/null
[[ -f "${repo_six}/docs/plans/keep/keep-plan.md" ]]
[[ -f "${repo_six}/docs/plans/keep/keep-discussion-source.md" ]]
[[ -f "${repo_six}/docs/plans/keep/keep-review-source.md" ]]
[[ -f "${repo_six}/docs/plans/keep/keep-execution-state.md" ]]
[[ ! -e "${repo_six}/docs/plans/stale" ]]

echo "ok: docs-plan-cleanup tests passed"
