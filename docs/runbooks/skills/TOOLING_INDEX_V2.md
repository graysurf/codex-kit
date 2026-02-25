# Skills Tooling Index v2

This doc lists canonical entrypoints (skill scripts, PATH-installed tooling, and scriptless command contracts).
Install `nils-cli` via `brew install nils-cli` to get `plan-tooling`, `api-*`, and `semantic-commit` on PATH.
For skill directory layout/path rules, use `docs/runbooks/skills/SKILLS_ANATOMY_V2.md` as the canonical reference.
For create/validate/remove workflows, see `skills/tools/skill-management/README.md`.

## SKILL.md format

- SKILL.md format spec:
  - `docs/runbooks/skills/SKILL_MD_FORMAT_V1.md`
- Skill directory anatomy (canonical):
  - `docs/runbooks/skills/SKILLS_ANATOMY_V2.md`

## Skill governance

- Validate SKILL.md contract format:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh`
- Audit tracked skill directory layout:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh`
- Validate runnable path rules in SKILL.md:
  - `$AGENT_HOME/skills/tools/skill-management/skill-governance/scripts/validate_skill_paths.sh`

## Skill management

- Create a new skill skeleton (validated):
  - `$AGENT_HOME/skills/tools/skill-management/create-skill/scripts/create_skill.sh`
- Remove a skill and purge references (breaking change):
  - `$AGENT_HOME/skills/tools/skill-management/remove-skill/scripts/remove_skill.sh`

## Plan tooling (Plan Format v1)

- Scaffold a new plan file:
  - `plan-tooling scaffold`
- Lint plans:
  - `plan-tooling validate`
- Parse plan → JSON:
  - `plan-tooling to-json`
- Compute dependency batches:
  - `plan-tooling batches`

## Issue workflow (main-agent + subagent PR automation)

- Main-agent issue lifecycle:
  - `$AGENT_HOME/skills/workflows/issue/issue-lifecycle/scripts/manage_issue_lifecycle.sh`
- Subagent worktree + PR execution:
  - Scriptless contract using native `git` + `gh` commands (see `skills/workflows/issue/issue-subagent-pr/SKILL.md`)
- Main-agent PR review + issue sync:
  - `$AGENT_HOME/skills/workflows/issue/issue-pr-review/scripts/manage_issue_pr_review.sh`

## Issue delivery automation (main-agent orchestration CLI)

- Live GitHub-backed orchestration (issue and plan flows):
  - `plan-issue <subcommand>`
- Local rehearsal / dry-run orchestration (same subcommands, no GitHub writes):
  - `plan-issue-local <subcommand> --dry-run`
- Key subcommands:
  - `start-plan`, `start-sprint`, `ready-sprint`, `accept-sprint`, `status-plan`, `ready-plan`, `close-plan`
