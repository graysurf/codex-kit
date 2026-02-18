#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $AGENT_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh --phase <name> [options]

This is a real-GitHub E2E driver for the progress workflow:
  planning progress PR -> handoff merge -> 2 stacked implementation PRs -> close/archive

Safety guards:
  - Refuses to run when CI=true
  - Requires E2E_ALLOW_REAL_GH=1
  - Requires clean working tree

Phases:
  init       Create/push a sandbox base branch
  plan       Create a planning progress PR (docs-only)
  handoff    Merge the planning PR and patch its Progress link to the base branch
  worktrees  Create 2 worktrees from a TSV spec
  prs        Create 2 draft implementation PRs (stacked)
  close      Merge PR1, retarget PR2, run close-progress-pr on PR2
  cleanup    Remove worktrees; optionally delete sandbox branches
  all        Run init -> plan -> handoff -> worktrees -> prs -> close (no cleanup)

Options:
  --run-id <id>                 Reuse an existing run directory under out/e2e/
  --base <branch>               Source branch for sandbox base (default: main)
  --sandbox-base <branch>       Sandbox base branch name (default: test/progress-e2e-<run-id>)
  --skip-checks                 Skip gh checks gating (NOT recommended)
  --keep-sandbox                Do not delete sandbox branches in cleanup

Artifacts:
  - out/e2e/progress-pr-workflow/<run-id>/run.json

Examples:
  E2E_ALLOW_REAL_GH=1 $AGENT_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh --phase all
  E2E_ALLOW_REAL_GH=1 $AGENT_HOME/skills/workflows/pr/progress/progress-pr-workflow-e2e/scripts/progress_pr_workflow.sh --phase cleanup --run-id 20260124-120000-abc123
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="${1:-}"
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
}

require_nils_cli() {
  local name="$1"
  local path=''
  path="$(command -v "$name" 2>/dev/null || true)"
  [[ -n "$path" ]] || die "$name is required (install with: brew tap graysurf/tap && brew install nils-cli)"
  printf "%s\n" "$path"
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

phase=""
run_id=""
base_branch="main"
sandbox_base_branch=""
skip_checks="0"
keep_sandbox="0"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --phase)
      phase="${2:-}"
      shift 2
      ;;
    --run-id)
      run_id="${2:-}"
      shift 2
      ;;
    --base)
      base_branch="${2:-}"
      shift 2
      ;;
    --sandbox-base)
      sandbox_base_branch="${2:-}"
      shift 2
      ;;
    --skip-checks)
      skip_checks="1"
      shift
      ;;
    --keep-sandbox)
      keep_sandbox="1"
      shift
      ;;
    *)
      die "unknown argument: ${1}"
      ;;
  esac
done

[[ -n "$phase" ]] || die "--phase is required (use --help)"

if [[ "${CI:-}" == "true" ]]; then
  die "refusing to run in CI=true"
fi

if [[ "${E2E_ALLOW_REAL_GH:-}" != "1" ]]; then
  die "refusing to run without E2E_ALLOW_REAL_GH=1"
fi

require_cmd git
require_cmd gh
require_cmd python3

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "must run inside a git work tree"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain=v1)" ]]; then
  die "working tree is not clean; commit/stash first"
fi

if ! gh auth status >/dev/null 2>&1; then
  die "gh auth status failed"
fi

repo_url="$(gh repo view --json url -q .url 2>/dev/null || true)"
repo_full="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
if [[ -z "$repo_url" || -z "$repo_full" ]]; then
  die "failed to resolve repo metadata via gh (try running inside the intended repo)"
fi

generate_run_id() {
  local ts rand
  ts="$(date +%Y%m%d-%H%M%S)"
  rand="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(3))
PY
)"
  printf "%s-%s" "$ts" "$rand"
}

if [[ -z "$run_id" ]]; then
  run_id="$(generate_run_id)"
fi

out_dir="${repo_root}/out/e2e/progress-pr-workflow/${run_id}"
mkdir -p "$out_dir"
run_json="${out_dir}/run.json"

json_upsert() {
  local key="${1:-}"
  local value="${2:-}"
  python3 - "$run_json" "$key" "$value" <<'PY'
import json
import sys
from pathlib import Path

path, key, value = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
data = {}
if path.exists():
  try:
    data = json.loads(path.read_text("utf-8"))
  except Exception:
    data = {}

data[key] = value
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", "utf-8")
PY
}

json_get() {
  local key="${1:-}"
  python3 - "$run_json" "$key" <<'PY'
import json
import sys
from pathlib import Path

path, key = Path(sys.argv[1]), sys.argv[2]
data = json.loads(path.read_text("utf-8"))
value = data.get(key)
if value is None:
  raise SystemExit(1)
print(value)
PY
}

json_upsert "run_id" "$run_id"
json_upsert "repo_full" "$repo_full"
json_upsert "repo_url" "$repo_url"
json_upsert "base_branch" "$base_branch"
json_upsert "phase" "$phase"

if [[ -z "$sandbox_base_branch" ]]; then
  sandbox_base_branch="test/progress-e2e-${run_id}"
fi
json_upsert "sandbox_base_branch" "$sandbox_base_branch"

AGENT_HOME="${AGENT_HOME:-${AGENTS_HOME:-$repo_root}}"
AGENTS_HOME="${AGENTS_HOME:-$AGENT_HOME}"
export AGENT_HOME AGENTS_HOME
handoff_script=""
close_script=""
create_progress_file_script=""
create_worktrees_script=""

resolve_tools() {
  local root="${1:-}"
  handoff_script="${root%/}/skills/workflows/pr/progress/handoff-progress-pr/scripts/handoff_progress_pr.sh"
  close_script="${root%/}/skills/workflows/pr/progress/close-progress-pr/scripts/close_progress_pr.sh"
  create_progress_file_script="${root%/}/skills/workflows/pr/progress/progress-tooling/scripts/create_progress_file.sh"
  create_worktrees_script="${root%/}/skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh"
}

resolve_tools "$AGENT_HOME"
if [[ ! -f "$handoff_script" || ! -f "$close_script" || ! -f "$create_progress_file_script" || ! -f "$create_worktrees_script" ]]; then
  # AGENT_HOME is often a global Codex config dir; fall back to the current repo root unless
  # the caller intentionally pointed AGENT_HOME at a agent-kit checkout that contains these scripts.
  resolve_tools "$repo_root"
  AGENT_HOME="$repo_root"
  AGENTS_HOME="$repo_root"
fi

for p in "$handoff_script" "$close_script" "$create_progress_file_script" "$create_worktrees_script"; do
  [[ -f "$p" ]] || die "required helper script not found: $p"
done

SEMANTIC_COMMIT="$(require_nils_cli semantic-commit)"
GIT_SCOPE="$(require_nils_cli git-scope)"

run_commit_helper() {
  "$SEMANTIC_COMMIT" commit "$@"
}

run_phase_init() {
  echo "==> init: sandbox base branch: ${sandbox_base_branch} (from ${base_branch})" >&2

  git fetch origin "$base_branch" >/dev/null 2>&1 || true
  if ! git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
    die "cannot find origin/${base_branch}; fetch it first"
  fi

  git switch -c "$sandbox_base_branch" "origin/${base_branch}"
  git push -u origin "$sandbox_base_branch"

  json_upsert "sandbox_base_branch_created" "true"
}

run_phase_plan() {
  echo "==> plan: create planning progress PR" >&2

  local yyyymmdd today_iso planning_branch title slug progress_file progress_url pr_body pr_url pr_number
  yyyymmdd="$(date +%Y%m%d)"
  today_iso="$(date +%Y-%m-%d)"
  title="E2E progress workflow ${run_id}"
  slug="e2e-progress-workflow-${run_id}"
  planning_branch="docs/progress/${yyyymmdd}-e2e-${run_id}"

  # Prefer a local sandbox base branch; push does not update refs/remotes/* automatically.
  if ! git show-ref --verify --quiet "refs/heads/${sandbox_base_branch}"; then
    set +e
    git fetch origin "$sandbox_base_branch:${sandbox_base_branch}" >/dev/null 2>&1
    set -e
  fi
  if ! git show-ref --verify --quiet "refs/heads/${sandbox_base_branch}"; then
    die "sandbox base branch not found locally: ${sandbox_base_branch} (run --phase init first)"
  fi

  git switch -c "$planning_branch" "$sandbox_base_branch"

  progress_file="$("$create_progress_file_script" --title "$title" --slug "$slug" --date "$yyyymmdd" --status "DRAFT")"
  json_upsert "progress_file" "$progress_file"

  # Replace any remaining [[...]] tokens to make the file commit-ready for E2E.
  python3 - "$progress_file" <<'PY'
from __future__ import annotations

import re
import sys

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()
text = re.sub(r"\[\[.*?\]\]", "TBD", text)

lines = text.splitlines()

def find_heading(name: str) -> int | None:
  for i, line in enumerate(lines):
    if line.strip() == name:
      return i
  return None

steps_idx = find_heading("## Steps (Checklist)")
if steps_idx is not None:
  # Mark all checkboxes in Step 0–3 as complete so close-progress-pr can succeed
  # without requiring Reason: lines for deferred items.
  current_step: int | None = None
  step_re = re.compile(r"^\s*-\s*\[[ xX]\]\s*(?:~~\s*)?Step\s+(?P<num>\d+):")
  checkbox_re = re.compile(r"^(?P<indent>\s*)-\s*\[(?P<mark>[ xX])\]\s+(?P<rest>.+)$")
  for i in range(steps_idx + 1, len(lines)):
    if lines[i].startswith("## "):
      break
    m_step = step_re.match(lines[i])
    if m_step:
      try:
        current_step = int(m_step.group("num"))
      except ValueError:
        current_step = None

    m = checkbox_re.match(lines[i])
    if not m:
      continue
    if current_step is None or current_step >= 4:
      continue
    lines[i] = f"{m.group('indent')}- [x] {m.group('rest')}"

text = "\n".join(lines).rstrip() + "\n"
open(path, "w", encoding="utf-8").write(text)
PY

  git add "$progress_file"
  if [[ -f "docs/progress/README.md" ]]; then
    git add "docs/progress/README.md"
  fi

  run_commit_helper --message "docs(progress): add e2e plan ${run_id}"
  git push -u origin "$planning_branch"

  progress_url="${repo_url}/blob/${planning_branch}/${progress_file}"
  pr_body="${out_dir}/planning-pr-body.md"
  cat >"$pr_body" <<EOF
## Summary
- E2E sandbox planning PR for validating progress workflow.

## Progress
- [${progress_file}](${progress_url})

## Implementation PRs
- PR1: TBD
- PR2: TBD (stacked)
EOF

  pr_url="$(gh pr create --draft --base "$sandbox_base_branch" --head "$planning_branch" --title "docs(progress): e2e workflow ${run_id}" --body-file "$pr_body")"
  pr_number="$(gh pr view "$pr_url" --json number -q .number)"

  # Patch progress file Links -> PR to the planning PR URL (so close-progress-pr can back-link later).
  python3 - "$progress_file" "$pr_url" <<'PY'
import sys

path, pr_url = sys.argv[1], sys.argv[2]
lines = open(path, "r", encoding="utf-8").read().splitlines()
out = []
patched = False
for line in lines:
  if line.startswith("- PR:"):
    out.append(f"- PR: {pr_url}")
    patched = True
  else:
    out.append(line)
if not patched:
  raise SystemExit(f"error: cannot find '- PR:' line in {path}")
open(path, "w", encoding="utf-8").write("\n".join(out).rstrip() + "\n")
PY

  if [[ -f "docs/progress/README.md" ]]; then
    python3 - "docs/progress/README.md" "$progress_file" "$pr_number" "$pr_url" <<'PY'
import sys

path, progress_file, pr_number, pr_url = sys.argv[1:]
filename = progress_file.split("/")[-1]
with open(path, "r", encoding="utf-8") as f:
  lines = f.read().splitlines()

updated = False
for i, line in enumerate(lines):
  if filename in line and "| TBD |" in line:
    lines[i] = line.replace("| TBD |", f"| [#{pr_number}]({pr_url}) |")
    updated = True
    break

if updated:
  with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines).rstrip() + "\n")
PY
  fi

  git add "$progress_file"
  if [[ -f "docs/progress/README.md" ]]; then
    git add "docs/progress/README.md"
  fi

  run_commit_helper --message "docs(progress): link planning pr ${run_id}"
  git push

  json_upsert "planning_pr_url" "$pr_url"
  json_upsert "planning_pr_number" "$pr_number"
}

run_phase_handoff() {
  echo "==> handoff: merge planning PR and patch Progress link" >&2

  local planning_pr_number progress_file
  planning_pr_number="$(json_get "planning_pr_number" 2>/dev/null || true)"
  progress_file="$(json_get "progress_file" 2>/dev/null || true)"
  [[ -n "$planning_pr_number" ]] || die "missing planning_pr_number in run.json (run --phase plan first)"
  [[ -n "$progress_file" ]] || die "missing progress_file in run.json (run --phase plan first)"

  if [[ "$skip_checks" != "1" ]]; then
    gh pr checks "$planning_pr_number"
  fi

  handoff_args=(--pr "$planning_pr_number" --progress-file "$progress_file" --no-cleanup)
  if [[ "$skip_checks" == "1" ]]; then
    handoff_args+=(--skip-checks)
  fi
  bash "$handoff_script" "${handoff_args[@]}"
  json_upsert "handoff_complete" "true"
}

run_phase_worktrees() {
  echo "==> worktrees: create 2 worktrees from TSV" >&2

  local worktrees_root spec pr1_branch pr2_branch pr1_wt pr2_wt
  worktrees_root="${repo_root}/../.worktrees/$(basename "$repo_root")/e2e-${run_id}"
  mkdir -p "$worktrees_root"

  pr1_branch="feat/e2e-${run_id}-pr1"
  pr2_branch="feat/e2e-${run_id}-pr2"
  pr1_wt="feat__e2e-${run_id}-pr1"
  pr2_wt="feat__e2e-${run_id}-pr2"

  spec="${out_dir}/pr-splits.tsv"
  printf "# branch\tstart_point\tworktree_name\tgh_base\n" >"$spec"
  printf "%s\t%s\t%s\t%s\n" "$pr1_branch" "$sandbox_base_branch" "$pr1_wt" "$sandbox_base_branch" >>"$spec"
  printf "%s\t%s\t%s\t%s\n" "$pr2_branch" "$pr1_branch" "$pr2_wt" "$pr1_branch" >>"$spec"

  bash "$create_worktrees_script" --spec "$spec" --worktrees-root "$worktrees_root"

  json_upsert "worktrees_root" "$worktrees_root"
  json_upsert "pr1_branch" "$pr1_branch"
  json_upsert "pr2_branch" "$pr2_branch"
  json_upsert "pr1_worktree" "$pr1_wt"
  json_upsert "pr2_worktree" "$pr2_wt"
  json_upsert "pr_splits_spec" "$spec"
}

  scaffold_commit_in_worktree() {
  local worktree_path="${1:-}"
  local message="${2:-}"
  local run_id_local="${3:-}"
  [[ -n "$worktree_path" ]] || return 1

  mkdir -p "${worktree_path}/docs/e2e-fixtures/${run_id_local}"
  printf "%s\n" "E2E fixture ${message}" >"${worktree_path}/docs/e2e-fixtures/${run_id_local}/${message// /-}.md"

  (
    cd "$worktree_path"
    git add "docs/e2e-fixtures/${run_id_local}/"
    run_commit_helper --message "test(e2e): ${message}"
    git push -u origin HEAD
  )
}

create_impl_pr() {
  local worktree_path="${1:-}"
  local base="${2:-}"
  local title="${3:-}"
  local body_path="${4:-}"

  (
    cd "$worktree_path"
    head_branch="$(git rev-parse --abbrev-ref HEAD)"
    gh pr create --draft --base "$base" --head "$head_branch" --title "$title" --body-file "$body_path"
  )
}

run_phase_prs() {
  echo "==> prs: create 2 draft implementation PRs (stacked)" >&2

  local progress_file planning_pr_number planning_pr_url worktrees_root pr1_wt pr2_wt pr1_path pr2_path pr1_url pr2_url pr1_num pr2_num progress_base_url pr1_body pr2_body
  progress_file="$(json_get "progress_file" 2>/dev/null || true)"
  planning_pr_number="$(json_get "planning_pr_number" 2>/dev/null || true)"
  planning_pr_url="$(json_get "planning_pr_url" 2>/dev/null || true)"
  worktrees_root="$(json_get "worktrees_root" 2>/dev/null || true)"
  pr1_wt="$(json_get "pr1_worktree" 2>/dev/null || true)"
  pr2_wt="$(json_get "pr2_worktree" 2>/dev/null || true)"

  [[ -n "$progress_file" ]] || die "missing progress_file in run.json (run earlier phases)"
  [[ -n "$planning_pr_number" ]] || die "missing planning_pr_number in run.json (run earlier phases)"
  [[ -n "$worktrees_root" ]] || die "missing worktrees_root in run.json (run --phase worktrees first)"

  pr1_path="${worktrees_root}/${pr1_wt}"
  pr2_path="${worktrees_root}/${pr2_wt}"

  progress_base_url="${repo_url}/blob/${sandbox_base_branch}/${progress_file}"

  scaffold_commit_in_worktree "$pr1_path" "e2e pr1 scaffold ${run_id}" "$run_id"
  scaffold_commit_in_worktree "$pr2_path" "e2e pr2 scaffold ${run_id}" "$run_id"

  pr1_body="${out_dir}/impl-pr1-body.md"
  cat >"$pr1_body" <<EOF
## Summary
- E2E PR1 scaffold.

## Progress
- [${progress_file}](${progress_base_url})

## Planning PR
- #${planning_pr_number}
EOF

  pr2_body="${out_dir}/impl-pr2-body.md"
  cat >"$pr2_body" <<EOF
## Summary
- E2E PR2 scaffold (stacked on PR1).

## Progress
- [${progress_file}](${progress_base_url})

## Planning PR
- #${planning_pr_number}
EOF

  pr1_url="$(create_impl_pr "$pr1_path" "$sandbox_base_branch" "test(e2e): pr1 scaffold ${run_id}" "$pr1_body")"
  pr1_num="$(gh pr view "$pr1_url" --json number -q .number)"

  pr2_url="$(create_impl_pr "$pr2_path" "$(json_get "pr1_branch")" "test(e2e): pr2 scaffold ${run_id}" "$pr2_body")"
  pr2_num="$(gh pr view "$pr2_url" --json number -q .number)"

  json_upsert "pr1_url" "$pr1_url"
  json_upsert "pr1_number" "$pr1_num"
  json_upsert "pr2_url" "$pr2_url"
  json_upsert "pr2_number" "$pr2_num"
  json_upsert "planning_pr_url" "$planning_pr_url"
}

run_phase_close() {
  echo "==> close: merge PR1, retarget PR2, close progress on PR2" >&2

  local pr1_number pr2_number pr1_branch worktrees_root pr2_worktree pr2_path
  pr1_number="$(json_get "pr1_number" 2>/dev/null || true)"
  pr2_number="$(json_get "pr2_number" 2>/dev/null || true)"
  pr1_branch="$(json_get "pr1_branch" 2>/dev/null || true)"
  worktrees_root="$(json_get "worktrees_root" 2>/dev/null || true)"
  pr2_worktree="$(json_get "pr2_worktree" 2>/dev/null || true)"

  [[ -n "$pr1_number" ]] || die "missing pr1_number in run.json (run --phase prs first)"
  [[ -n "$pr2_number" ]] || die "missing pr2_number in run.json (run --phase prs first)"
  [[ -n "$pr1_branch" ]] || die "missing pr1_branch in run.json"
  [[ -n "$worktrees_root" ]] || die "missing worktrees_root in run.json"
  [[ -n "$pr2_worktree" ]] || die "missing pr2_worktree in run.json"

  pr2_path="${worktrees_root}/${pr2_worktree}"
  [[ -d "$pr2_path" ]] || die "pr2 worktree path not found: $pr2_path"

  pr1_state="$(gh pr view "$pr1_number" --json state -q .state 2>/dev/null || true)"
  if [[ "$pr1_state" == "OPEN" ]]; then
    if [[ "$skip_checks" != "1" ]]; then
      gh pr checks "$pr1_number"
    fi
    gh pr ready "$pr1_number" >/dev/null 2>&1 || true
    merge_args=("$pr1_number" --merge)
    if gh pr merge --help 2>/dev/null | grep -q -- "--yes"; then
      merge_args+=(--yes)
    fi
    gh pr merge "${merge_args[@]}" >/dev/null
  fi

  # Retarget PR2 to the sandbox base branch now that PR1 is merged.
  gh pr edit "$pr2_number" -B "$sandbox_base_branch"

  # Use the canonical closer on the final PR (PR2).
  (
    cd "$pr2_path"
    bash "$close_script" --pr "$pr2_number"
  )

  json_upsert "close_complete" "true"
}

run_phase_cleanup() {
  echo "==> cleanup: remove worktrees and prune" >&2

  local worktrees_root pr1_wt pr2_wt
  worktrees_root="$(json_get "worktrees_root" 2>/dev/null || true)"
  pr1_wt="$(json_get "pr1_worktree" 2>/dev/null || true)"
  pr2_wt="$(json_get "pr2_worktree" 2>/dev/null || true)"

  if [[ -n "$worktrees_root" ]]; then
    if [[ -n "$pr1_wt" && -d "${worktrees_root}/${pr1_wt}" ]]; then
      git worktree remove "${worktrees_root}/${pr1_wt}" || true
    fi
    if [[ -n "$pr2_wt" && -d "${worktrees_root}/${pr2_wt}" ]]; then
      git worktree remove "${worktrees_root}/${pr2_wt}" || true
    fi
    git worktree prune || true
  fi

  if [[ "$keep_sandbox" == "1" ]]; then
    echo "keeping sandbox branches (keep_sandbox=1)" >&2
    exit 0
  fi

  # Best-effort remote cleanup.
  set +e
  git push origin --delete "$sandbox_base_branch" >/dev/null 2>&1
  set -e
  json_upsert "cleanup_complete" "true"
}

case "$phase" in
  init) run_phase_init ;;
  plan) run_phase_plan ;;
  handoff) run_phase_handoff ;;
  worktrees) run_phase_worktrees ;;
  prs) run_phase_prs ;;
  close) run_phase_close ;;
  cleanup) run_phase_cleanup ;;
  all)
    run_phase_init
    run_phase_plan
    run_phase_handoff
    run_phase_worktrees
    run_phase_prs
    run_phase_close
    ;;
  *)
    die "unknown phase: $phase"
    ;;
esac

echo "run_id: ${run_id}" >&2
echo "artifacts: ${out_dir}" >&2
