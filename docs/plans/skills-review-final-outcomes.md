# Skills Review Final Outcomes

## Final Outcomes

- Repository-level docs now describe the canonical check surface (`scripts/check.sh` modes plus
  entrypoint drift guards) without legacy wrapper guidance.
- Runtime path examples for plan-issue cleanup now use the current `<owner__repo>` workspace slug convention.
- The retained skill entrypoint surface is documented and auditable through current `SKILL.md`, smoke specs, and regression checks.

| Surface | Decision | Outcome |
| --- | --- | --- |
| `scripts/check.sh --all` | keep | Canonical full local validation gate for lint, docs freshness, contracts, and tests. |
| `bash scripts/ci/stale-skill-scripts-audit.sh --check` | keep | Required drift guard when workflow/tool entrypoints are added, removed, or renamed. |
| `scripts/check.sh --entrypoint-ownership` | keep | Required ownership gate for workflow/tool entrypoint references. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh` | keep | Retained release-guide resolution entrypoint. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh` | keep | Retained release publish entrypoint. |
| `$AGENT_HOME/skills/tools/devex/desktop-notify/scripts/codex-notify.sh` | remove | Legacy wrapper removed; notifier surface remains `desktop-notify.sh` and `project-notify.sh`. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-audit.sh` | remove | Legacy release helper removed in favor of the consolidated publish entrypoint. |

## Removed Entrypoints

- `$AGENT_HOME/skills/tools/devex/desktop-notify/scripts/codex-notify.sh`
- `$AGENT_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh`
- `$AGENT_HOME/skills/automation/release-workflow/scripts/release-audit.sh`
- `$AGENT_HOME/skills/automation/release-workflow/scripts/release-find-guide.sh`
- `$AGENT_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh`
- `$AGENT_HOME/skills/automation/release-workflow/scripts/release-scaffold-entry.sh`

## Migration Mapping

| Old Entrypoint | Replacement | Notes |
| --- | --- | --- |
| `$AGENT_HOME/skills/tools/devex/desktop-notify/scripts/codex-notify.sh` | `$AGENT_HOME/skills/tools/devex/desktop-notify/scripts/project-notify.sh` | Use project-scoped title wrapper for notification publishing. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` | Audit behavior is folded into the consolidated publish command. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-audit.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` | Publish command handles changelog audit + release body verification. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-find-guide.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-resolve.sh --repo .` | Guide/template resolution is now a single public entrypoint. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` | Release note extraction now happens in the consolidated publish path. |
| `$AGENT_HOME/skills/automation/release-workflow/scripts/release-scaffold-entry.sh` | `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version <tag>` | Scaffolding and publish path are unified under one release command. |
