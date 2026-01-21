# codex-kit: Script regression tests (pytest)

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-13 | 2026-01-13 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/20
- Planning PR: https://github.com/graysurf/codex-kit/pull/19
- Docs: [docs/testing/script-regression.md](../../testing/script-regression.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Goal

- Add a hermetic regression test suite (`pytest`) for all repo scripts (including skill scripts and audit scripts), runnable locally and in CI.
- Ensure every script is exercised at least once in a safe mode (default: `--help`) with deterministic stubs and no network access.
- Make script behavior verifiable with reproducible evidence under `out/` (logs + summary), and document how to extend coverage.

## Acceptance Criteria

- `$CODEX_HOME/scripts/test.sh` (or `python -m pytest`) passes locally and in GitHub Actions.
- Test discovery covers 100% of tracked script entrypoints under `scripts/`, `commands/`, and `skills/**/scripts/`.
- Each discovered script has an executable test invocation (default: `--help`; or an explicit per-script spec) and runs in a hermetic sandbox:
  - `HOME` and `XDG_*` point to temp dirs under `out/tests/script-regression/`
  - `PATH` is prefixed with repo-local stubs to prevent destructive ops and outbound network calls (e.g., `gh`, `curl`)
- The test run writes a machine-readable summary to `out/tests/script-regression/summary.json` and captures per-script stdout/stderr under `out/tests/script-regression/logs/`.

## Scope

- In-scope:
  - Add a Python test harness under `tests/` using `pytest` (stdlib + pytest only).
  - Add a script discovery + execution layer that runs each script with a safe invocation and a timeout.
  - Add repo-local stubs used by the harness (e.g., `tests/stubs/bin/*`) to make execution hermetic and non-destructive.
  - Wire `pytest` into GitHub Actions so PRs and pushes run `$CODEX_HOME/scripts/test.sh`.
  - Add lightweight validations for non-code assets:
    - `prompts/*.md` YAML front matter is parseable and includes required keys (exact key set TBD).
    - `skills/**/SKILL.md` contract lint remains enforced (via `$CODEX_HOME/scripts/validate_skill_contracts.sh` and/or direct parsing).
- Out-of-scope:
  - End-to-end integration tests that require real external services, credentials, or network access.
  - Large refactors of scripts unrelated to testability (only minimal changes to support safe invocations, when needed).

## I/O Contract

### Input

- Script entrypoints (tracked files):
  - `scripts/**`
  - `commands/**`
  - `skills/**/scripts/**`
- `prompts/*.md`
- `skills/**/SKILL.md`

### Output

- `tests/**` (pytest suite + helpers + fixtures)
- Optional local runner wrapper: `$CODEX_HOME/scripts/test.sh`
- Evidence (untracked, local):
  - `out/tests/script-regression/summary.json`
  - `out/tests/script-regression/logs/**`

### Intermediate Artifacts

- Hermetic sandbox dirs (untracked, local): `out/tests/script-regression/{home,tmp,work}/`
- Stub binaries (tracked): `tests/stubs/bin/*`

## Design / Decisions

### Rationale

- `pytest` provides strong parametrization, readable failures, and portable subprocess testing with minimal dependencies.
- Auto-discovery + coverage enforcement prevents drift as new scripts are added.
- A hermetic harness (isolated `HOME` + stubbed `PATH`) keeps tests safe and reproducible.

### Risks / Uncertainties

- “Correctness” definition: for many scripts, only `--help` is safely testable without a full environment.
  - Mitigation: establish a per-script spec file for scripts needing richer assertions (inputs/outputs/fixtures) and grow over time.
- Side effects / destructive operations: some scripts may mutate git state, edit files, or call external CLIs.
  - Mitigation: run inside an isolated work dir, stub risky binaries (`gh`, `curl`, `rm`, etc.), and require timeouts.
- Cross-shell portability: some scripts are `zsh`, some are `bash`; behavior may differ between macOS and Linux.
  - Mitigation: standardize invocation via shebang (execute the file directly) and record required shell/runtime per script.

### Decisions

- Test runner: `pytest` (Python), runs locally and in GitHub Actions.
- Coverage rule: every discovered script must have an executable test invocation (default `--help`, or explicit spec).
- Scripts that require secrets/interactive input: graceful-fail is considered pass when the failure is expected and non-destructive (record expected error patterns in specs).
- Per-script spec format + location: `tests/script_specs/<script_relpath>.json`.
- `prompts/*.md` front matter: must be valid YAML and include `description` + `argument-hint` keys (additional keys allowed).
- Hermetic default environment:
  - `CODEX_HOME` set to repo root
  - `HOME` and `XDG_CONFIG_HOME` redirected under `out/tests/script-regression/`
  - `NO_COLOR=1` and non-interactive friendly env vars set
- Evidence location: all test evidence written under `out/tests/script-regression/` (never `/tmp` for persisted artifacts).

### Open Questions

- None.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Align scope and contracts
  - Work Items:
    - [x] Inventory script entrypoints to cover (inclusion rules): `scripts/**`, `skills/**/scripts/**` (tracked via `git ls-files`).
    - [x] Define the default safe invocation contract (`--help` first) and per-script JSON specs for overrides.
    - [x] Define the hermetic environment contract (`HOME`/`XDG_*` under `out/`, stubbed `PATH`, non-interactive env).
    - [x] Specify "full run" semantics for secrets/interactive scripts (graceful-fail pass + expected error patterns).
  - Artifacts:
    - `docs/progress/20260113_script-regression-tests-pytest.md` (this file)
    - Notes: decisions recorded in this progress file
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: recorded in this progress file.
    - [x] I/O contract is defined (inputs, outputs, evidence paths): recorded in this progress file.
    - [x] Risks and mitigations are explicit: recorded in this progress file.
    - [x] A minimal verification command is defined: `.venv/bin/python -m pytest` (or `$CODEX_HOME/scripts/test.sh`).
- [x] Step 1: Minimum viable harness (pytest)
  - Work Items:
    - [x] Add `pytest` dev dependency metadata: `requirements-dev.txt`.
    - [x] Implement script discovery + smoke execution (per script) with a timeout.
    - [x] Implement the hermetic sandbox + stubbed `PATH` used by the smoke tests.
    - [x] Write evidence (`summary.json` + per-script logs) under `out/tests/script-regression/`.
  - Artifacts:
    - `tests/**`
    - `tests/stubs/bin/*`
    - `out/` evidence (untracked): `out/tests/script-regression/**`
    - Docs: `docs/testing/script-regression.md`
  - Exit Criteria:
    - [x] A representative subset runs under the harness: `.venv/bin/python -m pytest -m script_regression`.
    - [x] Evidence artifacts are produced under `out/tests/script-regression/` and are readable/actionable.
    - [x] Basic usage docs exist (TL;DR + how to add a script spec): `docs/testing/script-regression.md`.
- [x] Step 2: Full coverage + audit checks
  - Work Items:
    - [x] Add per-script specs for scripts that cannot be validated via `--help` alone (example: `$CODEX_HOME/scripts/chrome-devtools-mcp.sh`).
    - [x] Ensure every discovered script is covered by the default contract or an explicit spec (no silent skips).
    - [x] Add targeted tests for "audit scripts" (contracts + progress index validation).
  - Artifacts:
    - `tests/script_specs/**` (JSON)
    - `tests/test_audit_scripts.py`
  - Exit Criteria:
    - [x] Coverage enforcement is in place: test fails if any discovered script cannot run under default/spec.
    - [x] Common failure modes are covered via negative fixtures (invalid skill contract, invalid progress PR cell).
    - [x] Prompts and skill-doc validations are included: `tests/test_prompts_front_matter.py`, `tests/test_audit_scripts.py`.
- [x] Step 3: Validation and evidence
  - Work Items:
    - [x] Run the full suite locally; verify it is hermetic (stubbed `gh`/`curl`/`wget`, isolated `HOME`/`XDG_*`).
    - [x] Record runtime and stability: ~0.5s locally (macOS, Python 3.14.2); no flakes observed.
    - [x] Document supported workflows (local run, script specs, debugging): `docs/testing/script-regression.md`.
  - Artifacts:
    - `out/tests/script-regression/summary.json`
    - `out/tests/script-regression/logs/**`
  - Exit Criteria:
    - [x] `.venv/bin/python -m pytest` executed successfully; evidence saved under `out/tests/script-regression/`.
    - [x] Known limitations are recorded (default `--help`; deeper coverage via specs): `docs/testing/script-regression.md`.
- [x] Step 4: Wrap-up (optional)
  - Work Items:
    - [x] Wire `pytest` into GitHub Actions (`.github/workflows/lint.yml`).
    - [x] Update this progress file status and archive when implementation is complete.
  - Artifacts:
    - None
  - Exit Criteria:
    - [x] Follow-up work is tracked and progress docs are consistent (status updated + index updated + archived when DONE).

## Modules

- `tests/`: pytest suite entrypoints and fixtures.
- `tests/stubs/bin/`: stub executables used to keep script execution hermetic and safe.
- `tests/script_specs/`: per-script invocation specs for scripts that need more than `--help`.
- `out/tests/script-regression/`: local, untracked evidence (summary + logs + sandbox dirs).
