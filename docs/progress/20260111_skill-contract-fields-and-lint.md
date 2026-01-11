# codex-kit: Skill contract fields and lint

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-11 | 2026-01-11 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/16
- Docs: None
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Standardize every `skills/**/SKILL.md` to include a minimal `## Contract` section with 5 required headings.
- Add a lightweight lint script to enforce the presence of the 5 headings across all skills.
- Decide lint strictness and minimal smoke tests (beyond `shellcheck`), keeping the first iteration as a stability guard (`--check` only; no `--fix`/`--dry-run`).

## Acceptance Criteria

- Every `skills/**/SKILL.md` contains `## Contract` and the 5 required headings: `Prereqs`, `Inputs`, `Outputs`, `Exit codes`, `Failure modes`.
- `scripts/validate_skill_contracts.sh` exits `0` when compliant and non-zero when any file is missing required headings.
- CI runs `shellcheck` and `scripts/validate_skill_contracts.sh`; lint enforces exact heading strings + fixed ordering within `## Contract`, and a minimal smoke test set is defined (no `--fix`/`--dry-run` initially).

## Scope

- In-scope:
  - Docs-only edits to `skills/**/SKILL.md` to add the minimal `## Contract` section (no behavioral changes required).
  - Add `scripts/validate_skill_contracts.sh` (simple, deterministic, CI-friendly).
  - Wire the lint (and `shellcheck`) into GitHub Actions CI.
  - Document the contract requirement for new skills (update `skills/.system/skill-creator/SKILL.md`).
- Out-of-scope:
  - Adding rich semantics to contracts (e.g., deep schemas, examples for every field) beyond the 5 headings baseline.
  - Large refactors of existing skill scripts unrelated to contract standardization.
  - End-to-end API integration tests that depend on real external credentials/environments.

## I/O Contract

### Input

- `skills/**/SKILL.md` (authoritative skill docs)
- Required headings list: `Prereqs`, `Inputs`, `Outputs`, `Exit codes`, `Failure modes`

### Output

- Updated `skills/**/SKILL.md` files with a `## Contract` section that includes the 5 required headings
- `scripts/validate_skill_contracts.sh`
- CI workflow updates under `.github/workflows/` (names TBD)

### Intermediate Artifacts

- CI logs from `shellcheck` and `scripts/validate_skill_contracts.sh`
- Optional local report file (TBD): `out/skill-contracts/validate.log`

## Design / Decisions

### Rationale

- Keep the baseline contract format minimal (5 headings) to reduce drift and maintenance cost.
- Prefer a repo-local lint script over ad-hoc `rg` invocations to keep CI deterministic and self-documenting.

### Decisions

- Lint rule: require `## Contract` and enforce exact heading strings + fixed ordering within that section:
  - `Prereqs:` → `Inputs:` → `Outputs:` → `Exit codes:` → `Failure modes:`
- Non-applicable contract fields should be explicitly marked as `N/A` (e.g., docs-only skills or no runnable scripts).
- Lint is `--check` only in the first iteration (no auto-fix and no `--dry-run`), to stay a stable guardrail (“don’t break”).
- CI portability: implement the lint without requiring `rg` on GitHub runners (prefer `bash + python3` / `grep`).
- Minimal smoke tests (beyond `shellcheck`):
  - Positive: `scripts/validate_skill_contracts.sh` passes against the repo.
  - Negative: lint fails (non-zero) and prints actionable output when a fixture SKILL doc is missing required headings.

### Risks / Uncertainties

- Shell dialect coverage: `shellcheck` does not fully cover `zsh` entrypoints; decide whether to add `zsh -n` for critical `zsh` scripts.
- False positives/negatives: ensure the lint scans only the `## Contract` section to avoid matching headings in narrative text.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [ ] Step 0: Align spec and testing approach
  - Work Items:
    - [x] Confirm the canonical minimal format (exact strings): `## Contract` + 5 headings.
    - [x] Decide lint strictness + docs-only handling: exact strings + fixed ordering within `## Contract`; use `N/A` for non-applicable fields.
    - [x] Decide `--fix`/`--dry-run`: keep lint as `--check` only (no auto-fix; no `--dry-run`) as a stability guardrail.
    - [x] Decide minimal smoke tests beyond `shellcheck`: lint positive pass + negative fixture fail with actionable output.
  - Artifacts:
    - `docs/progress/20260111_skill-contract-fields-and-lint.md` (this file)
    - Notes: decisions recorded in this progress file
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: decisions recorded in this progress file.
    - [ ] I/O contract is defined (paths, exit codes, and failure modes for lint): captured in this progress file.
    - [ ] Risks and mitigations are explicit (including CI portability): captured in this progress file.
    - [ ] Verification commands are defined: `scripts/validate_skill_contracts.sh` and `shellcheck` (details TBD).
- [ ] Step 1: Add contracts + lint script (MVP)
  - Work Items:
    - [ ] Add a `## Contract` section (with the 5 headings) to every `skills/**/SKILL.md`.
    - [ ] Implement `scripts/validate_skill_contracts.sh` (list failures deterministically; exit non-zero on any failure).
    - [ ] Add basic usage docs in `scripts/README.md` (or a new section) for the lint command.
  - Artifacts:
    - `skills/**/SKILL.md`
    - `scripts/validate_skill_contracts.sh`
    - `scripts/README.md`
  - Exit Criteria:
    - [ ] `scripts/validate_skill_contracts.sh` passes locally: `scripts/validate_skill_contracts.sh` (command contract TBD).
    - [ ] Failure output is actionable and stable (prints file + missing headings).
    - [ ] No placeholder tokens remain in edited docs; contract sections are present in all skill docs.
- [ ] Step 2: CI integration and policy docs
  - Work Items:
    - [ ] Add GitHub Actions CI job(s) to run `shellcheck` and `scripts/validate_skill_contracts.sh`.
    - [ ] Update `skills/.system/skill-creator/SKILL.md` to require the `## Contract` section for new skills.
  - Artifacts:
    - `.github/workflows/*.yml` (TBD)
    - `skills/.system/skill-creator/SKILL.md`
  - Exit Criteria:
    - [ ] CI runs on PRs and fails on missing contract headings.
    - [ ] The policy for new skills is documented in `skills/.system/skill-creator/SKILL.md`.
- [ ] Step 3: Validation and smoke tests
  - Work Items:
    - [ ] Add minimal smoke tests without secrets:
      - `shellcheck` for supported shell scripts
      - Lint positive pass and negative fixture fail for `scripts/validate_skill_contracts.sh`
    - [ ] Ensure `shellcheck` covers repo scripts (scope TBD) and passes.
  - Artifacts:
    - CI logs for `shellcheck` + lint
    - Optional local logs under `out/skill-contracts/` (TBD)
  - Exit Criteria:
    - [ ] CI shows passing results for `shellcheck` and contract lint on a representative PR.
    - [ ] Smoke tests run without secrets and provide clear failures when broken.
- [ ] Step 4: Wrap-up
  - Work Items:
    - [ ] Update `docs/progress/README.md` and set this progress file status to `DONE` when implementation merges.
  - Artifacts:
    - `docs/progress/README.md`
    - `docs/progress/archived/20260111_skill-contract-fields-and-lint.md`
  - Exit Criteria:
    - [ ] Progress file is archived and indexed (per `docs/progress/README.md` rules).
    - [ ] No temporary flags/scripts remain without documentation.

## Modules

- `skills/**/SKILL.md`: Add/maintain `## Contract` sections (5 required headings).
- `scripts/validate_skill_contracts.sh`: Lint enforcement for required contract headings.
- `.github/workflows/*.yml`: CI wiring for `shellcheck` + contract lint.
- `skills/.system/skill-creator/SKILL.md`: Document contract requirement for new skills.
