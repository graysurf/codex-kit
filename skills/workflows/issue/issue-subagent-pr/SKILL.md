---
name: issue-subagent-pr
description:
  Subagent workflow for assigned task-lane implementation, blocker clarification handoffs, draft PR creation, and review-response updates
  linked back to the owning issue.
---

# Issue Subagent PR

Subagent owns implementation execution on an assigned task lane (`Owner / Branch / Worktree / Execution Mode / PR`) and keeps PR/issue
artifacts synchronized.

## Contract

Prereqs:

- Run inside the target git repo.
- `git` and `gh` available on `PATH`, and `gh auth status` succeeds.
- Worktree/branch ownership assigned by main-agent (or the issue Task Decomposition table when using `plan-issue` flows).

Inputs:

- Repository context:
  - issue number (`ISSUE`) and task ID (`TASK_ID`)
  - optional repository override (`owner/repo`) for `gh` commands
- Required implementation context in live mode (same priority, both required):
  - GitHub issue artifacts:
    - assigned `## Task Decomposition` row for `TASK_ID`
    - target sprint section context from issue comments (prefer `## Sprint <N> Start`)
  - Main-agent dispatch artifacts:
    - rendered task prompt artifact (`TASK_PROMPT_PATH`)
    - `PLAN_SNAPSHOT_PATH` when dispatch came from `plan-issue-delivery`
    - `SUBAGENT_INIT_SNAPSHOT_PATH` when dispatch came from `plan-issue-delivery`
    - `DISPATCH_RECORD_PATH` when dispatch came from `plan-issue-delivery`
    - plan task section context (exact snippet and/or direct link/path)
- Required implementation context in local rehearsal mode:
  - local rendered task prompt/artifacts and plan task context (no GitHub lookup for placeholder issues such as `999`)
- Base branch, PR title, and PR body markdown file path.
- Optional follow-up context for lane re-entry:
  - review comment URL + response body markdown for follow-up comments
  - clarification/unblock notes from main-agent for a previously assigned lane

Outputs:

- Dedicated task worktree checked out to the assigned branch, either by re-entering the existing lane or by creating the lane if it does not
  exist yet.
- Draft PR URL for the implementation branch, or confirmed reuse of the assigned PR for follow-up work.
- PR/body validation evidence (required sections present; placeholders removed).
- Blocker/clarification handoff packet when required context is missing/conflicting or an external blocker stops forward progress.
- Review response comments on the PR that reference the main-agent review comment URL.
- Optional issue sync comments (`gh issue comment`) that mirror task status and PR linkage.
- `plan-issue` artifact compatibility: canonical issue/PR references (`#<number>`) suitable for Task Decomposition sync.

Exit codes:

- `0`: success
- non-zero: invalid inputs, failed validation checks, repo context issues, or `git`/`gh` failures

Failure modes:

- Missing assigned execution facts (issue/task/owner/branch/worktree).
- Live mode: unable to resolve the assigned task row from issue `## Task Decomposition`.
- Live mode: unable to resolve target sprint task context from issue comments.
- Live mode: missing `TASK_PROMPT_PATH` or missing plan task section context from main-agent dispatch.
- `plan-issue-delivery` mode: missing `PLAN_SNAPSHOT_PATH` fallback artifact from dispatch.
- `plan-issue-delivery` mode: missing `SUBAGENT_INIT_SNAPSHOT_PATH` companion prompt snapshot artifact from dispatch.
- `plan-issue-delivery` mode: missing `DISPATCH_RECORD_PATH` assignment artifact from dispatch.
- Context mismatch between issue artifacts and main-agent dispatch artifacts (scope, ownership, branch/worktree, execution mode).
- `plan-issue-delivery` mode: assigned `WORKTREE` path is outside `$AGENT_HOME/out/plan-issue-delivery/...`.
- Worktree path collision or branch already bound to another worktree.
- Follow-up/re-entry drifts away from the assigned task lane by inventing a replacement `Owner`, `Branch`, `Worktree`, or `PR` without
  explicit reassignment.
- Empty PR body file or unresolved template placeholders (`TBD`, `TODO`, `<...>`, `#<number>`, template stub lines).
- Missing required PR body sections (`## Summary`, `## Scope`, `## Testing`, `## Issue`).
- `gh` auth/permission failures for PR/issue reads or writes.

## Task Lane Continuity (Mandatory)

- Follow the shared task-lane continuity policy:
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`
- Treat assigned `Owner / Branch / Worktree / Execution Mode / PR` as one task
  lane.
- Re-enter an existing worktree/branch/PR when the lane already exists; create
  lane artifacts only when they do not exist yet or when main-agent explicitly
  reassigns the lane.
- If clarification or follow-up is needed, hand control back to main-agent
  with exact lane facts and continue on that same lane once clarified.

## Command Contract (Scriptless)

- Use native `git` for worktree and branch lifecycle.
- Use native `gh` for draft PR creation and PR/issue comments.
- Use `rg`-based checks (or equivalent) for PR body section/placeholder validation before PR open and before final review updates.

## Ordered workflow (read requirements first)

1. Determine execution mode and initialize context variables:

   - ```bash
     REPO="owner/repo"   # optional when current remote context is correct
     ISSUE=175
     SPRINT=2
     TASK_ID="S2T3"
     ```

   - Live mode: `ISSUE` is a real GitHub issue number.
   - Local rehearsal mode: `ISSUE` is placeholder (for example `999`), so use local artifacts only.

2. Collect required context artifacts before edits:
   - Live mode: collect issue artifacts with `gh`:

     - ```bash
       gh issue view "$ISSUE" -R "$REPO" --json body --jq '.body' \
       | awk -F'|' -v t="$TASK_ID" '
           /^\|/ { task=$2; gsub(/^ +| +$/, "", task); if (task==t) print $0 }'
       ```

     - ```bash
       gh api "repos/$REPO/issues/$ISSUE/comments" --paginate \
         --jq '.[] | select(.body|contains("## Sprint '"$SPRINT"' Start")) | .html_url, .body'
       ```

   - Collect main-agent artifacts in both modes:
     - `TASK_PROMPT_PATH`
     - `PLAN_SNAPSHOT_PATH` (required in `plan-issue-delivery` mode)
     - `SUBAGENT_INIT_SNAPSHOT_PATH` (required in `plan-issue-delivery` mode)
     - `DISPATCH_RECORD_PATH` (required in `plan-issue-delivery` mode)
     - plan task section snippet/link/path

3. Reconcile context and apply hard start gate:
   - Treat issue artifacts and main-agent artifacts as equal-priority sources in live mode.
   - Confirm assigned task facts align across sources: owner, branch, worktree, execution mode, task scope, and acceptance intent.
   - In `plan-issue-delivery` mode, confirm `DISPATCH_RECORD_PATH` facts match assigned task row (`Task Decomposition`) and runtime artifact
     paths.
   - In `plan-issue-delivery` mode, enforce `WORKTREE` prefix: `$AGENT_HOME/out/plan-issue-delivery/`.
   - If any required context is missing or conflicting, stop and request clarification from main-agent before implementation.
   - When pausing for clarification, return a concise blocker packet:
     - confirmed task-lane facts
     - missing/conflicting context
     - current status (`blocked` vs `in-progress`)
     - exact next unblock action needed from main-agent
4. Create or re-enter the assigned worktree/branch:

   - ```bash
     AGENT_HOME="${AGENT_HOME:?AGENT_HOME is required}"
     ISSUE=123
     TASK_ID=T1
     BASE=main
     REPO_SLUG="owner__repo"
     BRANCH="issue/${ISSUE}/${TASK_ID}-api"
     WORKTREE="$AGENT_HOME/out/plan-issue-delivery/${REPO_SLUG}/issue-${ISSUE}/worktrees/pr-isolated/${TASK_ID}"

     if [ -e "$WORKTREE/.git" ]; then
       cd "$WORKTREE"
     else
       git fetch origin --prune
       git worktree add -b "$BRANCH" "$WORKTREE" "origin/$BASE"
       cd "$WORKTREE"
     fi

     git branch --show-current
     git worktree list
     ```

5. Implement task scope and run required task-level validation:
   - Prefer validation commands from task context (`TASK_PROMPT_PATH` / sprint task section / Task Decomposition notes).
   - Keep edits inside assigned task scope; escalate before widening scope.
   - If required context is discovered missing/conflicting during implementation, stop, report the blocker packet, and wait for main-agent
     clarification instead of inventing replacement lane facts.
6. Prepare and validate PR body (required sections + placeholder checks):

   - ```bash
     BODY_FILE="$WORKTREE/.tmp/pr-${ISSUE}-${TASK_ID}.md"
     mkdir -p "$(dirname "$BODY_FILE")"
     cp /Users/terry/.config/agent-kit/skills/workflows/issue/issue-subagent-pr/references/PR_BODY_TEMPLATE.md "$BODY_FILE"
     # Edit BODY_FILE and replace all template placeholders before continuing.

     for section in "## Summary" "## Scope" "## Testing" "## Issue"; do
       rg -q "^${section}$" "$BODY_FILE" || { echo "Missing section: ${section}" >&2; exit 1; }
     done

     rg -n 'TBD|TODO|<[^>]+>|#<number>|<implemented scope>|<explicitly excluded scope>|<command> \\(pass\\)|not run \\(reason\\)' "$BODY_FILE" \
       && { echo "Placeholder content found in PR body" >&2; exit 1; } || true
     ```

7. Open draft PR with `gh pr create` (initial run only):

   - ```bash
     if [ -z "${PR_NUMBER:-}" ]; then
       gh pr create \
         --draft \
         --base "$BASE" \
         --head "$BRANCH" \
         --title "feat(issue-${ISSUE}): implement ${TASK_ID} API changes" \
         --body-file "$BODY_FILE"
     fi

     PR_NUMBER="$(gh pr view --json number --jq '.number')"
     PR_URL="$(gh pr view --json url --jq '.url')"
     echo "Opened ${PR_URL}"
     ```

   - If the assigned PR already exists, skip `gh pr create`, keep the same branch/worktree/PR lane, and continue updates on that PR.

8. Post review response comment with `gh pr comment` (when follow-up requested on the assigned PR):

   - ```bash
     REVIEW_COMMENT_URL="https://github.com/<owner>/<repo>/pull/<pr>#issuecomment-<id>"
     RESPONSE_FILE="$WORKTREE/.tmp/review-response-${PR_NUMBER}.md"
     cp /Users/terry/.config/agent-kit/skills/workflows/issue/issue-subagent-pr/references/REVIEW_RESPONSE_TEMPLATE.md "$RESPONSE_FILE"
     # Edit RESPONSE_FILE: include REVIEW_COMMENT_URL and concrete change/testing notes.

     gh pr comment "$PR_NUMBER" --body-file "$RESPONSE_FILE"
     ```

9. Optional issue sync comment with `gh issue comment` (traceability):

   - ```bash
     gh issue comment "$ISSUE" \
       --body "Task ${TASK_ID} in progress by subagent. Branch: \`${BRANCH}\`. Worktree: \`${WORKTREE}\`. PR: #${PR_NUMBER}. Review response: ${REVIEW_COMMENT_URL}"
     ```

10. Optional plan-issue artifact sync note:

- In plan-issue flows, prefer main-agent `link-pr` updates over manual markdown edits:
  - `plan-issue link-pr --issue "$ISSUE" --task "$TASK_ID" --pr "#${PR_NUMBER}" --status in-progress`
- Subagent should include exact task selector + PR number in handoff comments so main-agent can run `link-pr` deterministically.
- Keep Task Decomposition row fields (`Owner`, `Branch`, `Worktree`, `Execution Mode`, `PR`) aligned with actual execution facts so
  `plan-issue status-plan` / `ready-plan` snapshots remain consistent.

## References

- PR body template: `references/PR_BODY_TEMPLATE.md`
- Review response template: `references/REVIEW_RESPONSE_TEMPLATE.md`
- Subagent task prompt template: `references/SUBAGENT_TASK_PROMPT_TEMPLATE.md`
- Shared task-lane continuity policy (canonical):
  `skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md`

## Notes

- Subagent may pre-fill `references/SUBAGENT_TASK_PROMPT_TEMPLATE.md` from assigned execution facts to avoid owner/branch/worktree drift
  during implementation.
- Treat PR body validation as a required gate, not an optional cleanup step.
- Keep implementation details and evidence in PR comments; issue comments should summarize status and link back to PR artifacts.
- Subagent owns implementation execution; main-agent remains orchestration/review-only.
- Even for single-PR issues, implementation PR authorship/ownership stays with subagent.
- Clarification/follow-up pauses are expected control-flow, not permission to widen scope or create replacement execution facts.
