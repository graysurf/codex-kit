from __future__ import annotations

import re
from pathlib import Path

from skills._shared.python.skill_testing import assert_skill_contract


def test_automation_plan_issue_delivery_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_plan_issue_delivery_skill_enforces_main_agent_role_boundary() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Main-agent is orchestration/review-only." in text
    assert "Main-agent does not implement sprint tasks directly." in text
    assert "workflow_role=implementation" in text
    assert "workflow_role=review" in text
    assert "workflow_role=monitor" in text
    assert "subagent-owned PRs" in text
    assert "1 plan = 1 issue" in text
    assert "PR grouping controls" in text
    assert "PR Grouping Steps (Mandatory)" in text
    assert "--strategy auto --default-pr-grouping group" in text
    assert "group + deterministic" in text
    assert "PLAN_BRANCH" in text
    assert "integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`)" in text
    assert "PLAN_INTEGRATION_MENTION_PATH" in text
    assert "prefer `--squash` when allowed, fallback to `--merge`" in text
    assert "git pull --ff-only" in text
    assert "## Full Skill Flow" in text
    assert "--pr-grouping group --strategy auto" not in text


def test_plan_issue_delivery_skill_requires_close_for_done() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "Definition of done: execution is complete only when `close-plan` succeeds, the plan issue is closed" in text
    assert "integration mention gate" in text
    assert re.search(r"required local sync commands\s+succeed\.", text)
    assert "worktree cleanup" in text
    assert "A successful run must terminate at `close-plan` with:" in text
    assert "final integration PR (`PLAN_BRANCH -> DEFAULT_BRANCH`) merged" in text
    assert "If any close gate fails, treat the run as unfinished" in text


def test_plan_issue_delivery_skill_uses_binary_first_command_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "plan-issue" in text
    assert "plan-issue-local" in text
    assert "start-plan" in text
    assert "start-sprint" in text
    assert "link-pr" in text
    assert "status-plan" in text
    assert "ready-sprint" in text
    assert "accept-sprint" in text
    assert "ready-plan" in text
    assert "close-plan" in text
    assert "plan-issue ready-plan --issue <number> [--repo <owner/repo>]" in text
    assert (
        "plan-issue close-plan --issue <number> --approved-comment-url <comment-url> [--repo <owner/repo>]"
        in text
    )


def test_plan_issue_delivery_local_rehearsal_uses_metadata_first_auto_default() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "references" / "LOCAL_REHEARSAL.md").read_text(encoding="utf-8")
    assert "--strategy auto --default-pr-grouping group" in text
    assert "--pr-grouping group --strategy auto" not in text


def test_plan_issue_delivery_skill_mentions_split_prs_v2_runtime_ownership() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "split-prs" in text
    assert "grouping primitives only" in text
    assert "materializes runtime metadata" in text


def test_plan_issue_delivery_skill_defines_runtime_workspace_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "$AGENT_HOME/out/plan-issue-delivery" in text
    assert "Runtime Workspace Policy (Mandatory)" in text
    assert "Static main-agent prompt source" in text
    assert "MAIN_AGENT_INIT_SNAPSHOT_PATH" not in text
    assert "REVIEW_EVIDENCE_TEMPLATE_PATH" in text
    assert "REVIEW_EVIDENCE_PATH" in text
    assert "PLAN_SNAPSHOT_PATH" in text
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" not in text
    assert "DISPATCH_RECORD_PATH" in text
    assert "workflow_role" in text
    assert "runtime_role_fallback_reason" in text
    assert "references/RUNTIME_LAYOUT.md" in text
    assert "references/AGENT_ROLE_MAPPING.md" in text


def test_plan_issue_delivery_skill_includes_live_preflight_and_drift_remediation() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "## Live Mode Preflight" in text
    assert "plan-issue --version" in text
    assert "gh label create issue" in text
    assert "gh label create plan" in text
    assert "personal GitHub Free account" in text
    assert "## Mid-Flight Plan Changes" in text
    assert "task-sync-drift-detected" in text
    assert "Do not bypass the drift gate" in text


def test_plan_issue_delivery_skill_uses_shared_task_lane_policy() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in text


def test_plan_issue_delivery_skill_uses_shared_review_rubric() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md" in text
    assert "reviews each sprint PR against the shared review rubric" in text
    assert "ready-sprint` is a pre-merge review gate" in text
    assert "--enforce-review-evidence" in text
    assert "REVIEW_EVIDENCE_TEMPLATE_PATH" in text


def test_plan_issue_delivery_skill_uses_shared_post_review_outcomes() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md" in text
    assert "After each review decision" in text
    assert "--row-status" in text
    assert "--next-owner" in text
    assert "--close-reason" in text
    assert "REVIEW_EVIDENCE_PATH" in text


def test_plan_issue_delivery_prompts_align_runtime_and_dispatch_bundle() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    repo_root = skill_root.parents[2]

    subagent_prompt = (repo_root / "prompts" / "plan-issue-delivery-subagent-init.md").read_text(encoding="utf-8")
    main_agent_prompt = (repo_root / "prompts" / "plan-issue-delivery-main-agent-init.md").read_text(encoding="utf-8")
    role_mapping = (skill_root / "references" / "AGENT_ROLE_MAPPING.md").read_text(encoding="utf-8")

    assert "PLAN_SNAPSHOT_PATH" in subagent_prompt
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" not in subagent_prompt
    assert "DISPATCH_RECORD_PATH" in subagent_prompt
    assert "$AGENT_HOME/out/plan-issue-delivery" in subagent_prompt
    assert "PLAN_BRANCH" in subagent_prompt
    assert "workflow_role" in subagent_prompt
    assert "runtime_role" in subagent_prompt

    assert "PLAN_SNAPSHOT_PATH" in main_agent_prompt
    assert "MAIN_AGENT_INIT_SNAPSHOT_PATH" not in main_agent_prompt
    assert "REVIEW_EVIDENCE_TEMPLATE_PATH" in main_agent_prompt
    assert "REVIEW_EVIDENCE_PATH" in main_agent_prompt
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" not in main_agent_prompt
    assert "DISPATCH_RECORD_PATH" in main_agent_prompt
    assert "PLAN_BRANCH" in main_agent_prompt
    assert "workflow_role" in main_agent_prompt
    assert "runtime_role" in main_agent_prompt
    assert "runtime_role_fallback_reason" in main_agent_prompt
    assert "PLAN_BRANCH_REF_PATH" in main_agent_prompt
    assert "PLAN_INTEGRATION_PR_PATH" in main_agent_prompt
    assert "PLAN_INTEGRATION_MENTION_PATH" in main_agent_prompt
    assert "prefer `gh pr merge --squash`" in main_agent_prompt
    assert "fallback to" in main_agent_prompt
    assert "`gh pr merge --merge`" in main_agent_prompt
    assert "sync local `PLAN_BRANCH`" in main_agent_prompt
    assert "git pull --ff-only" in main_agent_prompt
    assert "$AGENT_HOME/prompts/plan-issue-delivery-main-agent-init.md" in main_agent_prompt
    assert "$AGENT_HOME/prompts/plan-issue-delivery-subagent-init.md" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/issue-pr-review/references/REVIEW_EVIDENCE_TEMPLATE.md" in main_agent_prompt
    assert "$AGENT_HOME/out/plan-issue-delivery" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in subagent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/TASK_LANE_CONTINUITY.md" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/MAIN_AGENT_REVIEW_RUBRIC.md" in main_agent_prompt
    assert "$AGENT_HOME/skills/workflows/issue/_shared/references/POST_REVIEW_OUTCOMES.md" in main_agent_prompt
    assert "--next-owner" in main_agent_prompt
    assert "--close-reason" in main_agent_prompt
    assert "--enforce-review-evidence" in main_agent_prompt
    assert "implementation -> plan_issue_worker" in role_mapping
    assert "review -> plan_issue_reviewer" in role_mapping
    assert "monitor -> plan_issue_monitor" in role_mapping


def test_plan_issue_delivery_runtime_adapter_docs_and_templates_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    codex_doc = (skill_root / "references" / "CODEX_ADAPTER.md").read_text(encoding="utf-8")
    claude_doc = (skill_root / "references" / "CLAUDE_CODE_ADAPTER.md").read_text(encoding="utf-8")
    opencode_doc = (skill_root / "references" / "OPENCODE_ADAPTER.md").read_text(encoding="utf-8")
    role_mapping = (skill_root / "references" / "AGENT_ROLE_MAPPING.md").read_text(encoding="utf-8")

    assert "~/.codex/config.toml" in codex_doc
    assert "plan_issue_worker" in codex_doc
    assert "No runtime adapter is the repo default" in codex_doc

    assert ".claude/agents/" in claude_doc
    assert "plan-issue-orchestrator" in claude_doc
    assert "plan-issue-implementation" in claude_doc

    assert "opencode.json" in opencode_doc
    assert ".opencode/agents/" in opencode_doc
    assert "permission.task" in opencode_doc

    assert "Codex" in role_mapping
    assert "Claude Code" in role_mapping
    assert "OpenCode" in role_mapping
    assert "No runtime adapter is the repo default." in role_mapping

    codex_config = skill_root / "assets" / "runtime-adapters" / "codex" / "home" / ".codex" / "config.toml"
    codex_worker = skill_root / "assets" / "runtime-adapters" / "codex" / "home" / ".codex" / "agents" / "plan-issue-worker.toml"
    claude_template = skill_root / "assets" / "runtime-adapters" / "claude-code" / "project" / ".claude" / "agents" / "plan-issue-orchestrator.md"
    claude_impl = skill_root / "assets" / "runtime-adapters" / "claude-code" / "project" / ".claude" / "agents" / "plan-issue-implementation.md"
    opencode_config = skill_root / "assets" / "runtime-adapters" / "opencode" / "project" / "opencode.json"
    opencode_prompt = skill_root / "assets" / "runtime-adapters" / "opencode" / "project" / ".opencode" / "prompts" / "plan-issue-orchestrator.txt"

    assert codex_config.exists()
    assert codex_worker.exists()
    assert claude_template.exists()
    assert "Required Dispatch Bundle" in claude_template.read_text(encoding="utf-8")
    assert "create-plan-issue-sprint-pr/scripts/create-plan-issue-sprint-pr.sh" in claude_impl.read_text(encoding="utf-8")
    assert opencode_config.exists()
    assert opencode_prompt.exists()


def test_plan_issue_delivery_runtime_layout_tracks_plan_issue_0_8_artifacts() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "references" / "RUNTIME_LAYOUT.md").read_text(encoding="utf-8")
    assert "plan-issue-delivery-main-agent-init.md" in text
    assert "does not emit main/subagent init snapshot files" in text
    assert "MAIN_AGENT_INIT_SNAPSHOT_PATH" not in text
    assert "SUBAGENT_INIT_SNAPSHOT_PATH" not in text
    assert "REVIEW_EVIDENCE_TEMPLATE_PATH" in text
    assert "REVIEW_EVIDENCE_PATH" in text
    assert "PLAN_BRANCH_REF_PATH" in text
    assert "PLAN_INTEGRATION_PR_PATH" in text
    assert "PLAN_INTEGRATION_MENTION_PATH" in text
    assert "workflow_role" in text
    assert "runtime_role_fallback_reason" in text
    assert "syncs local `PLAN_BRANCH`" in text
    assert "syncs local `DEFAULT_BRANCH`" in text


def test_plan_issue_delivery_skill_excludes_deleted_wrapper_scripts() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert ("plan-issue-delivery" + ".sh") not in text
    assert ("manage_issue_delivery_loop" + ".sh") not in text
    assert ("manage_issue_subagent_pr" + ".sh") not in text


def test_plan_issue_delivery_e2e_sprint1_fixture_artifact_labels_and_pr_markers() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    fixture_path = repo_root / "tests" / "fixtures" / "issue" / "plan_issue_delivery_e2e_sprint1.md"
    text = fixture_path.read_text(encoding="utf-8")

    expected_task_decomposition_header = "| Task ID | Summary | Owner | Branch | Worktree | PR | Status |"
    assert "## Task Decomposition" in text, (
        f"Sprint 1 fixture must include '## Task Decomposition': {fixture_path}"
    )
    assert expected_task_decomposition_header in text, (
        "Sprint 1 fixture is missing required artifact labels in the Task Decomposition table header; "
        f"expected exact header: {expected_task_decomposition_header}"
    )

    row_pattern = re.compile(
        r"^\| (?P<task_id>S1T\d+) \| (?P<summary>[^|]+) \| (?P<owner>[^|]+) \| "
        r"(?P<branch>[^|]+) \| (?P<worktree>[^|]+) \| (?P<pr>[^|]+) \| (?P<status>[^|]+) \|$"
    )
    rows = [match.groupdict() for line in text.splitlines() if (match := row_pattern.match(line.strip()))]
    assert rows, (
        "Sprint 1 fixture has no S1T* Task Decomposition rows; expected rows with canonical PR markers like '#101'."
    )

    for row in rows:
        pr_token = row["pr"].strip()
        assert re.fullmatch(r"#\d+", pr_token), (
            f"Sprint 1 fixture PR marker for {row['task_id']} must use canonical '#<number>' format, "
            f"found '{pr_token}'."
        )


def test_plan_issue_delivery_e2e_sprint2_invariants() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    fixture_path = repo_root / "tests" / "fixtures" / "issue" / "plan_issue_delivery_e2e_sprint2.md"
    assert fixture_path.exists(), "Sprint 2 fixture is required for normalized PR/done-state regression checks."

    text = fixture_path.read_text(encoding="utf-8")
    assert "## Task Decomposition" in text, "Sprint 2 fixture must define a Task Decomposition section."
    assert "#201" in text, "Sprint 2 fixture must keep canonical PR marker #201."
    assert "#202" in text, "Sprint 2 fixture must keep canonical PR marker #202."
    assert "pr-shared" in text, "Sprint 2 fixture must explicitly encode pr-shared lane behavior."

    rows = [line for line in text.splitlines() if line.startswith("| S2T")]
    assert rows, "Sprint 2 fixture must include task rows for Sprint 2 decomposition."
    for row in rows:
        assert "| done |" in row, f"Sprint 2 row must retain done-state marker: {row}"

    grouped_rows = [row for row in rows if row.startswith("| S2T2 ") or row.startswith("| S2T3 ")]
    assert grouped_rows, "Sprint 2 fixture must include grouped lane rows for S2T2/S2T3."
    for row in grouped_rows:
        assert "| #201 |" in row, f"Grouped Sprint 2 lane rows must keep canonical shared PR #201: {row}"

    assert "https://github.com/" not in text, "Sprint 2 fixture should not drift to URL-only PR references."


# -- Sprint 3 references (Task 3.3 + Task 3.4) ----------------------------


SPRINT_PR_TEMPLATE_REL = "skills/automation/plan-issue-delivery/references/SPRINT_PR_TEMPLATE.md"
CLOSE_PLAN_FINAL_MILE_REL = "skills/automation/plan-issue-delivery/references/CLOSE_PLAN_FINAL_MILE.md"
VALIDATOR_REL = "skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh"


def test_sprint_pr_template_reference_exists_and_documents_required_schema() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    template = repo_root / SPRINT_PR_TEMPLATE_REL
    assert template.is_file(), (
        f"Task 3.3: canonical sprint PR template must live at {SPRINT_PR_TEMPLATE_REL}; "
        f"missing at {template}"
    )

    text = template.read_text(encoding="utf-8")
    # Schema sections (the four-heading shape)
    assert "## Summary" in text
    assert "## Scope" in text
    assert "## Testing" in text
    assert "## Issue" in text
    # Issue bullet shape
    assert "- #<ISSUE_NUMBER>" in text
    # Cross-reference to feature template (so authors know which one to use)
    assert "skills/create-feature-pr/references/PR_TEMPLATE.md" in text
    # Sprint 4 follow-up TODO trail
    assert "claude-kit Sprint 4 Task 4.2" in text


def test_sprint_pr_template_named_in_canonical_skill_references() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "references/SPRINT_PR_TEMPLATE.md" in text, (
        "Task 3.3: canonical SKILL.md must list the new sprint PR template "
        "under ## References so the implementation lane finds it."
    )


def test_sprint_pr_template_named_by_pr_body_validator_error_message() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    validator_text = (repo_root / VALIDATOR_REL).read_text(encoding="utf-8")
    # The PR-body hygiene validator must NAME the schema and the template
    # path so the operator knows which template to switch to (vs.
    # claude-kit's create-feature-pr template, which uses
    # Summary/Changes/Testing/Risk/Notes).
    assert "schema_label='sprint-pr (Summary / Scope / Testing / Issue)'" in validator_text
    assert (
        "skills/automation/plan-issue-delivery/references/SPRINT_PR_TEMPLATE.md"
        in validator_text
    )


def test_sprint_pr_template_named_in_subagent_init_prompt() -> None:
    """Implementation lanes need the template path in their init bundle so
    the PR they open passes the validator on the first attempt.
    """
    repo_root = Path(__file__).resolve().parents[4]
    text = (repo_root / "prompts" / "plan-issue-delivery-subagent-init.md").read_text(encoding="utf-8")
    assert (
        "$AGENT_HOME/skills/automation/plan-issue-delivery/references/SPRINT_PR_TEMPLATE.md"
        in text
    )


def test_close_plan_final_mile_reference_exists_and_lists_five_artifacts() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    ref = repo_root / CLOSE_PLAN_FINAL_MILE_REL
    assert ref.is_file(), (
        f"Task 3.4: close-plan final-mile reference must live at "
        f"{CLOSE_PLAN_FINAL_MILE_REL}; missing at {ref}"
    )

    text = ref.read_text(encoding="utf-8")
    # Numbered checklist for the five close-plan artifacts in production order
    for marker in (
        "1. **`plan-conformance-review.md`**",
        "2. **`plan-integration-pr.md`**",
        "3. **`plan-integration-ci.md`**",
        "4. **Mention comment posted on the plan issue.**",
        "5. **`plan-integration-mention.url`**",
    ):
        assert marker in text, f"Task 3.4: missing checklist marker {marker!r}"
    # Cross-references to canonical runtime path constants
    for var in (
        "PLAN_CONFORMANCE_REVIEW_PATH",
        "PLAN_INTEGRATION_PR_PATH",
        "PLAN_INTEGRATION_CI_PATH",
        "PLAN_INTEGRATION_MENTION_PATH",
    ):
        assert var in text, f"Task 3.4: missing path-constant reference {var!r}"
    # Final-call snippet for plan-issue close-plan
    assert "plan-issue close-plan" in text
    # Sprint 4 follow-up trail (helper subcommand is out of scope here)
    assert "claude-kit Sprint 4 Task 4.2" in text


def test_close_plan_final_mile_linked_from_main_agent_init_prompt() -> None:
    repo_root = Path(__file__).resolve().parents[4]
    text = (repo_root / "prompts" / "plan-issue-delivery-main-agent-init.md").read_text(encoding="utf-8")
    assert (
        "$AGENT_HOME/skills/automation/plan-issue-delivery/references/CLOSE_PLAN_FINAL_MILE.md"
        in text
    ), "Task 3.4: main-agent init prompt must link to CLOSE_PLAN_FINAL_MILE.md near the close-plan section."
    # The link should appear in the close-plan-related instructions, not at random.
    assert "close-plan final-mile checklist" in text


def test_close_plan_final_mile_linked_in_canonical_skill_references() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    text = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "references/CLOSE_PLAN_FINAL_MILE.md" in text
