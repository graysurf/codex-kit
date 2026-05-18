---
name: skill-usage
description: Record skill invocation intent, linked evidence, validation, outcome, and failures through the nils-cli skill-usage command.
---

# Skill Usage

Use this skill when a workflow needs a compact, deterministic record of a named skill invocation and its validation or failure handling.

## Contract

Prereqs:

- Keep workflow judgment in the calling skill; use this CLI only for structured evidence capture.
- Choose an explicit output directory from project policy, or use a project-scoped `agent-out project --topic skill-usage --mkdir`
  directory when the project has no evidence path.
- Required PATH usage: `skill-usage` available on `PATH` from nils-cli 0.8.5 or newer.
- Released boundary: Homebrew nils-cli 0.8.5 includes the expanded `nils-agent-workflow-primitives` binary surface with `skill-usage`.
  Verify the actual binary with `skill-usage --version`.
- Local checkout fallback: Rust/Cargo plus a validated local `nils-cli` checkout that builds `nils-agent-workflow-primitives`, used only
  when the PATH binary is absent or reports a version older than the release that includes `skill-usage`.
- Do not run multiple write commands against the same `--out` directory
  concurrently. Serialize writes for one record directory and verify after the
  final update.

Inputs:

- `init`: required `--out DIR`, `--skill TEXT`, `--intent TEXT`, and `--user-request-summary TEXT`; optional `--trigger
  user-explicit|agent-selected|project-policy|other`, repeatable `--referenced-file PATH`, repeatable `--external-source TEXT`, `--cwd
  DIR`, `--started-at TEXT`, `--validation-waiver TEXT`, `--force`, and `--format text|json`.
- `link-record`: required `--out DIR`, `--type TEXT`, and `--path PATH`; optional `--format text|json`.
- `record-failure`: required `--out DIR`, `--phase preflight|execution|validation|cleanup|delivery`, `--classification
  skill-contract|script-bug|missing-dependency|external-service|project-state|user-scope|unknown`, `--symptom TEXT`, `--diagnosis TEXT`,
  `--handling TEXT`, and `--result fixed|worked-around|blocked|accepted-risk`; optional `--command TEXT`, `--exit-code CODE`,
  repeatable `--artifact PATH`, and `--format text|json`.
- `record-validation`: required `--out DIR`, `--command TEXT`, `--status pass|fail|skipped`, and `--summary TEXT`; optional `--artifact
  PATH` and `--format text|json`.
- `record-outcome`: required `--out DIR`, `--status pass|fail|blocked|worked-around|accepted-risk|skipped`, and `--summary TEXT`;
  optional `--ended-at TEXT`, repeatable `--artifact PATH`, repeatable `--follow-up TEXT`, and `--format text|json`.
- `verify` / `show`: required `--out DIR`; optional `--format text|json`.

Outputs:

- Writes `skill-usage.record.json` under `--out DIR`.
- JSON stdout uses versioned schema values such as `cli.skill-usage.verify.v1`.
- The record schema is `skill-usage.record.v1`.
- Recorded text is redacted for secret-like tokens before persistence.

Exit codes:

- `0`: command succeeded; for `verify`, the skill usage record is complete.
- `1`: runtime failure or incomplete/invalid skill usage evidence.
- `64`: usage error.

Failure modes:

- `skill-usage` is unavailable on `PATH` and no validated local checkout invocation is being used.
- Evidence directory cannot be created or written.
- Concurrent writes target the same output directory and risk corrupting
  `skill-usage.record.json`; serialize them or split the evidence into separate
  record directories.
- `verify` finds missing required fields, missing final validation without waiver, missing failure records for non-pass outcomes, or
  secret-like values.
- Caller treats the record as policy judgment; record retention, promotion, and compression decisions remain in the workflow/runbook.

## Setup

Required released PATH boundary:

```bash
skill-usage --version
```

Use the PATH command only when it resolves to `skill-usage 0.8.5` or newer.

Local checkout fallback boundary:

```bash
cargo run --locked --manifest-path /path/to/nils-cli/Cargo.toml \
  -p nils-agent-workflow-primitives --bin skill-usage -- --version
```

Run the Cargo form from the workflow's target directory. It is only a fallback transport for a validated local checkout when the released
PATH binary is absent or older than 0.8.5. Do not mix PATH and local checkout evidence claims without stating which source was used.

## Commands

Required released PATH command:

```bash
skill-usage init --out <dir> --skill <skill> --intent <intent> --user-request-summary <summary> [--format json]
skill-usage link-record --out <dir> --type <record-type> --path <path> [--format json]
skill-usage record-failure --out <dir> --phase preflight|execution|validation|cleanup|delivery --classification skill-contract|script-bug|missing-dependency|external-service|project-state|user-scope|unknown --symptom <text> --diagnosis <text> --handling <text> --result fixed|worked-around|blocked|accepted-risk [--format json]
skill-usage record-validation --out <dir> --command <command> --status pass|fail|skipped --summary <summary> [--format json]
skill-usage record-outcome --out <dir> --status pass|fail|blocked|worked-around|accepted-risk|skipped --summary <summary> [--format json]
skill-usage verify --out <dir> [--format json]
skill-usage show --out <dir> [--format json]
skill-usage completion <bash|zsh>
```

Local checkout fallback command:

```bash
cargo run --locked --manifest-path /path/to/nils-cli/Cargo.toml \
  -p nils-agent-workflow-primitives --bin skill-usage -- <subcommand> ...
```

## Workflow

1. Create or choose a retained evidence directory only when the workflow requires a skill usage record.
2. Initialize the record near the start of the skill workflow:
   `skill-usage init --out <dir> --skill <skill> --intent <intent> --user-request-summary <summary> --format json`
3. Run write commands for that `--out` directory serially; do not parallelize
   `link-record`, `record-failure`, `record-validation`, or `record-outcome`
   against the same record.
4. Link typed child evidence records instead of copying them into this envelope:
   `skill-usage link-record --out <dir> --type review-evidence --path <path>`
5. Record validation or an explicit validation waiver, then record the final outcome.
6. Before citing the record, run:
   `skill-usage verify --out <dir> --format json`

## Guardrails

- Do not hand-edit `skill-usage.record.json` or duplicate redaction, completeness, or JSON envelope logic in skill-local scripts.
- Do not use agent-side parallelism for writes to one record directory. If
  workflow policy is not enough, route primitive-level locking or atomic updates
  to nils-cli instead of implementing a second writer here.
- Do not commit raw runtime records by default; commit only curated review, incident, audit, fixture, or compressed durable records.
- Do not use this record as a substitute for typed child evidence such as `review-evidence.json`, `test-first-evidence.json`, or
  `browser-session.json`.
- Keep promotion/compression policy in `docs/runbooks/skills/SKILL_USAGE_RECORDING_V1.md`; the CLI owns deterministic writing and
  verification only.
