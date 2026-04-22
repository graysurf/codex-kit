# nils-cli agent-docs adoption decision (Sprint 3.3)

## Decision scope

- Target project: `$HOME/Project/graysurf/nils-cli`
- Decision objective:
  - whether to adopt project-level `AGENT_DOCS.toml`;
  - whether `nils-cli/AGENTS.md` requires immediate dispatcher-style modification.

## Recommendation

Recommended now:

1. Adopt project-level `AGENT_DOCS.toml` (minimum viable entry for `project-dev` pointing to `BINARY_DEPENDENCIES.md`).
2. Keep `nils-cli/AGENTS.md` unchanged for now.

Recommended later:

1. Optionally add a concise dispatcher preflight note to `nils-cli/AGENTS.md` when project-local portability becomes a priority.

Rationale:

- pilot shows project-level extension loading works and passes strict checks;
- immediate value is gained without touching repo-specific engineering policy text;
- AGENTS refactor can be separated to reduce review scope and risk.

## Evidence

Primary evidence files:

- Gap analysis:
  - `$HOME/.config/agent-kit/out/agent-docs-rollout/nils-cli-gap-analysis.md`
- Baseline snapshot:
  - `$HOME/.config/agent-kit/out/agent-docs-rollout/nils-cli-current-baseline.txt`
- Pilot change log:
  - `$HOME/.config/agent-kit/out/agent-docs-rollout/nils-cli-pilot-changes.md`
- Pilot strict resolve:
  - `$HOME/.config/agent-kit/out/agent-docs-rollout/nils-cli-pilot-project-dev.strict.txt`
- Pilot strict baseline:
  - `$HOME/.config/agent-kit/out/agent-docs-rollout/nils-cli-pilot-baseline-project.strict.txt`
- Pilot change isolation:
  - `$HOME/.config/agent-kit/out/agent-docs-rollout/nils-cli-pilot-status.txt`

Observed facts from evidence:

1. Current project baseline is already passing (`missing_required: 0`) under built-in requirements.
2. Pilot with project-level `AGENT_DOCS.toml` adds `source=extension-project` for `project-dev`.
3. Pilot strict baseline still passes with `missing_required: 0`.
4. Pilot diff remains policy-only (`AGENT_DOCS.toml`).

## Rejected alternatives

1. Full immediate rewrite of `nils-cli/AGENTS.md` into dispatcher style
   - rejected now due increased policy churn and overlap with repo-specific guidance.
2. No project-level extension adoption
   - rejected because it leaves portability dependent on home-level extension policy only.

## Next actions

### Required now

1. Open a policy-only PR in `nils-cli` adding project-level `AGENT_DOCS.toml`.
2. Include strict validation output (`resolve --context project-dev --strict`, `baseline --target project --strict`) in PR notes.

### Later

1. Decide whether to add dispatcher preflight sentence into `nils-cli/AGENTS.md`.
2. Evaluate adding project-scoped extensions for `startup`, `task-tools`, and `skill-dev` if team wants full local portability.

## Rollback

If pilot behavior is not accepted:

1. Remove project-level `AGENT_DOCS.toml` from pilot branch.
2. Re-run:
   - `agent-docs --project-path $HOME/Project/graysurf/nils-cli baseline --check --target project --strict --format text`
3. Keep existing `nils-cli/AGENTS.md` and `DEVELOPMENT.md` as sole project policy.
