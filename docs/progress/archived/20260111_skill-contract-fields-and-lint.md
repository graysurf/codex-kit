# codex-kit: Skill contract fields and lint

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-11 | 2026-01-11 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/17
- Planning PR: https://github.com/graysurf/codex-kit/pull/16
- Docs: None
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Goal

- Standardize every `skills/**/SKILL.md` to include a minimal `## Contract` section with 5 required headings.
- Add a lightweight lint script to enforce the presence of the 5 headings across all skills.
- Decide lint strictness and minimal smoke tests (beyond `shellcheck`), keeping the first iteration as a stability guard (`--check` only; no `--fix`/`--dry-run`).

## Acceptance Criteria

- Every `skills/**/SKILL.md` contains `## Contract` and the 5 required headings: `Prereqs`, `Inputs`, `Outputs`, `Exit codes`, `Failure modes`.
- `$CODEX_HOME/scripts/validate_skill_contracts.sh` exits `0` when compliant and non-zero when any file is missing required headings.
- CI runs `shellcheck` and `$CODEX_HOME/scripts/validate_skill_contracts.sh`; lint enforces exact heading strings + fixed ordering within `## Contract`, and a minimal smoke test set is defined (no `--fix`/`--dry-run` initially).

## Scope

- In-scope:
  - Docs-only edits to `skills/**/SKILL.md` to add the minimal `## Contract` section (no behavioral changes required).
  - Add `$CODEX_HOME/scripts/validate_skill_contracts.sh` (simple, deterministic, CI-friendly).
  - Wire the lint (and `shellcheck`) into GitHub Actions CI.
  - Document the contract requirement for new skills (README + CI lint).
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
- `$CODEX_HOME/scripts/validate_skill_contracts.sh`
- CI workflow updates under `.github/workflows/lint.yml`

### Intermediate Artifacts

- CI logs from `shellcheck` and `$CODEX_HOME/scripts/validate_skill_contracts.sh`
- Optional local report file: None (not implemented in MVP)

### Lint script contract (`$CODEX_HOME/scripts/validate_skill_contracts.sh`)

- Success: exit `0`; no output.
- Failure: non-zero; prints `error: <path>: ...` to stderr (missing headings / out-of-order / invalid args / file not found).

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
- Shellcheck severity: start with `shellcheck -S error` to avoid blocking on existing warnings/info.
- Minimal smoke tests (beyond `shellcheck`):
  - Positive: `$CODEX_HOME/scripts/validate_skill_contracts.sh` passes against the repo.
  - Negative: lint fails (non-zero) and prints actionable output when a fixture SKILL doc is missing required headings.

### Risks / Uncertainties

- Shell dialect coverage: `shellcheck` does not fully cover `zsh` entrypoints; decide whether to add `zsh -n` for critical `zsh` scripts.
- False positives/negatives: ensure the lint scans only the `## Contract` section to avoid matching headings in narrative text.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Align spec and testing approach
  - Work Items:
    - [x] Confirm the canonical minimal format (exact strings): `## Contract` + 5 headings.
    - [x] Decide lint strictness + docs-only handling: exact strings + fixed ordering within `## Contract`; use `N/A` for non-applicable fields.
    - [x] Decide `--fix`/`--dry-run`: keep lint as `--check` only (no auto-fix; no `--dry-run`) as a stability guardrail.
    - [x] Decide minimal smoke tests beyond `shellcheck`: lint positive pass + negative fixture fail with actionable output.
  - Artifacts:
    - `docs/progress/archived/20260111_skill-contract-fields-and-lint.md` (this file)
    - Notes: decisions recorded in this progress file
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: decisions recorded in this progress file.
    - [x] I/O contract is defined (paths, exit codes, and failure modes for lint): captured in this progress file.
    - [x] Risks and mitigations are explicit (including CI portability): captured in this progress file.
    - [x] Verification commands are defined:
      - `$CODEX_HOME/scripts/validate_skill_contracts.sh`
      - `shellcheck -S error` (CI runs against tracked bash shebang scripts)
- [x] Step 1: Add contracts + lint script (MVP)
  - Work Items:
    - [x] Add a `## Contract` section (with the 5 headings) to every `skills/**/SKILL.md`.
    - [x] Implement `$CODEX_HOME/scripts/validate_skill_contracts.sh` (list failures deterministically; exit non-zero on any failure).
    - [x] Add basic usage docs in `scripts/README.md` for the lint command.
  - Artifacts:
    - `skills/**/SKILL.md`
    - `$CODEX_HOME/scripts/validate_skill_contracts.sh`
    - `scripts/README.md`
  - Exit Criteria:
    - [x] `$CODEX_HOME/scripts/validate_skill_contracts.sh` passes locally: `$CODEX_HOME/scripts/validate_skill_contracts.sh`
    - [x] Failure output is actionable and stable (prints file + missing headings).
    - [x] No placeholder tokens remain in edited docs; contract sections are present in all skill docs.
- [x] Step 2: CI integration and policy docs
  - Work Items:
    - [x] Add GitHub Actions CI job(s) to run `shellcheck` and `$CODEX_HOME/scripts/validate_skill_contracts.sh`.
    - [x] Update `README.md` to document the `## Contract` requirement for new skills.
  - Artifacts:
    - `.github/workflows/lint.yml`
    - `README.md`
  - Exit Criteria:
    - [x] CI runs on PRs and fails on missing contract headings.
    - [x] The policy for new skills is documented in `README.md`.
- [x] Step 3: Validation and smoke tests
  - Work Items:
    - [x] Add minimal smoke tests without secrets:
      - `shellcheck` for supported shell scripts
      - Lint positive pass and negative fixture fail for `$CODEX_HOME/scripts/validate_skill_contracts.sh`
    - [x] Ensure `shellcheck` covers repo scripts and passes (tracked `.sh` with bash shebang; excludes `shell_snapshots/`).
  - Artifacts:
    - CI logs for `shellcheck` + lint
    - Optional local logs under `out/skill-contracts/`: None (not implemented in MVP)
  - Exit Criteria:
    - [x] CI shows passing results for `shellcheck` and contract lint on a representative PR.
    - [x] Smoke tests run without secrets and provide clear failures when broken.
- [x] Step 4: Wrap-up
  - Work Items:
    - [x] Update `docs/progress/README.md` and set this progress file status to `DONE` when implementation merges.
  - Artifacts:
    - `docs/progress/README.md`
    - `docs/progress/archived/20260111_skill-contract-fields-and-lint.md`
  - Exit Criteria:
    - [x] Progress file is archived and indexed (per `docs/progress/README.md` rules).
    - [x] No temporary flags/scripts remain without documentation.

## Modules

- `skills/**/SKILL.md`: Add/maintain `## Contract` sections (5 required headings).
- `$CODEX_HOME/scripts/validate_skill_contracts.sh`: Lint enforcement for required contract headings.
- `.github/workflows/*.yml`: CI wiring for `shellcheck` + contract lint.
- `README.md`: Document contract requirement for new skills.
