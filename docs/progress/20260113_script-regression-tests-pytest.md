# codex-kit: Script regression tests (pytest)

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2026-01-13 | 2026-01-13 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/20
- Planning PR: https://github.com/graysurf/codex-kit/pull/19
- Docs: TBD
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../templates/PROGRESS_GLOSSARY.md)

## Goal

- Add a hermetic, local-only regression test suite (`pytest`) for all repo scripts (including skill scripts and audit scripts).
- Ensure every script is exercised at least once in a safe mode (default: `--help`) with deterministic stubs and no network access.
- Make script behavior verifiable with reproducible evidence under `out/` (logs + summary), and document how to extend coverage.

## Acceptance Criteria

- `python3 -m pytest` passes locally (no GitHub Actions required for this workstream).
- Test discovery covers 100% of tracked script entrypoints under `scripts/`, `scripts/commands/`, and `skills/**/scripts/`.
- Each discovered script has an executable test invocation (default: `--help`; or an explicit per-script spec) and runs in a hermetic sandbox:
  - `HOME` and `XDG_*` point to temp dirs under `out/tests/script-regression/`
  - `PATH` is prefixed with repo-local stubs to prevent destructive ops and outbound network calls (e.g., `gh`, `curl`)
- The test run writes a machine-readable summary to `out/tests/script-regression/summary.json` and captures per-script stdout/stderr under `out/tests/script-regression/logs/`.

## Scope

- In-scope:
  - Add a Python test harness under `tests/` using `pytest` (stdlib + pytest only).
  - Add a script discovery + execution layer that runs each script with a safe invocation and a timeout.
  - Add repo-local stubs used by the harness (e.g., `tests/stubs/bin/*`) to make execution hermetic and non-destructive.
  - Add lightweight validations for non-code assets:
    - `prompts/*.md` YAML front matter is parseable and includes required keys (exact key set TBD).
    - `skills/**/SKILL.md` contract lint remains enforced (via `scripts/validate_skill_contracts.sh` and/or direct parsing).
- Out-of-scope:
  - Wiring `pytest` into GitHub Actions (explicitly local-only for now).
  - End-to-end integration tests that require real external services, credentials, or network access.
  - Large refactors of scripts unrelated to testability (only minimal changes to support safe invocations, when needed).

## I/O Contract

### Input

- Script entrypoints (tracked files):
  - `scripts/**`
  - `scripts/commands/**`
  - `skills/**/scripts/**`
- `prompts/*.md`
- `skills/**/SKILL.md`

### Output

- `tests/**` (pytest suite + helpers + fixtures)
- Optional local runner wrapper: `scripts/test.sh` (name TBD)
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

- Test runner: `pytest` (Python), local-only (no CI wiring in this workstream).
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

- [ ] Step 0: Align scope and contracts
  - Work Items:
    - [ ] Inventory all script entrypoints to cover (and decide inclusion rules): `scripts/**`, `scripts/commands/**`, `skills/**/scripts/**`.
    - [ ] Define the default safe invocation contract (`--help` first) and the per-script spec format for overrides.
    - [ ] Define the hermetic environment contract (env vars, stubbed commands, working directory layout under `out/`).
    - [ ] Specify "full run" semantics for secrets/interactive scripts (graceful-fail pass + expected error patterns).
  - Artifacts:
    - `docs/progress/20260113_script-regression-tests-pytest.md` (this file)
    - Notes: decisions recorded in this progress file
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned: recorded in this progress file.
    - [ ] I/O contract is defined (inputs, outputs, evidence paths): recorded in this progress file.
    - [ ] Risks and mitigations are explicit: recorded in this progress file.
    - [ ] A minimal verification command is defined: `python3 -m pytest`.
- [ ] Step 1: Minimum viable harness (pytest)
  - Work Items:
    - [ ] Add `pytest` dev dependency metadata (`requirements-dev.txt` or equivalent; approach TBD).
    - [ ] Implement script discovery and a smoke test that executes each script with a safe invocation and timeout.
    - [ ] Implement the hermetic sandbox + stubbed `PATH` used by the smoke tests.
    - [ ] Add the first evidence writer (`summary.json` + per-script logs) under `out/tests/script-regression/`.
  - Artifacts:
    - `tests/**`
    - `tests/stubs/bin/*`
    - `out/` evidence (untracked): `out/tests/script-regression/**`
    - Docs (TBD): `docs/testing/script-regression.md` (or similar)
  - Exit Criteria:
    - [ ] A representative subset of scripts runs under the harness: `python3 -m pytest -k script_regression`.
    - [ ] Evidence artifacts are produced under `out/tests/script-regression/` and are readable/actionable.
    - [ ] Basic usage docs exist (TL;DR + how to add a script spec): TBD.
- [ ] Step 2: Full coverage + script specs
  - Work Items:
    - [ ] Add per-script specs for scripts that cannot be validated via `--help` alone (inputs/expected outputs/stubs).
    - [ ] Ensure every discovered script is covered by either the default contract or an explicit spec (no silent skips).
    - [ ] Add targeted fixtures for “audit scripts” to assert important behavior (TBD list).
  - Artifacts:
    - `tests/script_specs/**` (format TBD)
    - `tests/fixtures/**`
  - Exit Criteria:
    - [ ] Coverage enforcement is in place: test fails if any discovered script has no runnable invocation/spec.
    - [ ] Common failure modes are covered (missing env vars, missing tools, invalid args): fixtures + assertions.
    - [ ] Prompts and skill-doc validations are included (or explicitly deferred with reasons).
- [ ] Step 3: Validation and evidence
  - Work Items:
    - [ ] Run the full suite locally; verify it is hermetic (no external network, no writes outside `out/` + temp dirs).
    - [ ] Record runtime + any flaky scripts; refine timeouts/stubs/specs as needed.
    - [ ] Document the supported workflows (local run, adding new script specs, debugging failures).
  - Artifacts:
    - `out/tests/script-regression/summary.json`
    - `out/tests/script-regression/logs/**`
  - Exit Criteria:
    - [ ] `python3 -m pytest` executed successfully; evidence saved under `out/tests/script-regression/`.
    - [ ] Any known limitations are recorded with follow-up tasks (script-specific gaps + remediation path).
- [ ] Step 4: Wrap-up (optional)
  - Work Items:
    - [ ] Decide whether to add a follow-up PR to wire tests into CI (out-of-scope for this workstream).
    - [ ] Update this progress file status and archive when implementation is complete.
  - Artifacts:
    - None
  - Exit Criteria:
    - [ ] Follow-up work is tracked and progress docs are consistent (status updated + index updated + archived when DONE).

## Modules

- `tests/`: pytest suite entrypoints and fixtures.
- `tests/stubs/bin/`: stub executables used to keep script execution hermetic and safe.
- `tests/script_specs/`: per-script invocation specs for scripts that need more than `--help`.
- `out/tests/script-regression/`: local, untracked evidence (summary + logs + sandbox dirs).
