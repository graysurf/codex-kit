# codex-kit: Codex workspace launcher-wrapper migration

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-22 | 2026-01-22 |

Links:

- PR: [#63](https://github.com/graysurf/codex-kit/pull/63)
- Docs: `docs/runbooks/codex-workspace-migration.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- Define and ship a stable `codex-workspace` launcher contract (version/capabilities, JSON output, tunnel naming, secrets, `rm` semantics).
- Deduplicate lifecycle features between launcher (codex-kit) and wrapper (zsh-kit) to reduce drift and maintenance cost.
- Preserve wrapper-only Dev Containers UX while using the launcher as the canonical source of truth.

## Acceptance Criteria

- Launcher supports `--version` and advertises machine-readable capabilities.
- Launcher supports `create/up --output json` where **stdout is pure JSON** and all human logs go to stderr.
- Launcher `tunnel` derives a valid default name (sanitized, `<= 20` chars) and supports `--name`; JSON output requires `--detach` and includes `tunnel_name` + `log_path`.
- Launcher does not mount secrets by default; secrets are opt-in and require `--secrets-dir <host-path>`.
- Launcher `rm` removes container + volumes by default; `--keep-volumes` preserves volumes.
- zsh wrapper stops re-implementing launcher-owned commands (`ls`, `start/stop`, `rm`) and becomes a thin call-through.
- zsh wrapper uses launcher JSON output for `create` (no parsing of ad-hoc human output) and can enforce a minimum launcher version.

## Scope

- In-scope:
  - codex-kit launcher contract work: `--version`, capabilities, `--output json`, tunnel naming + JSON, secrets opt-in, `rm` semantics.
  - codex-kit docs: runbook and launcher docs updates to reflect the new contract.
  - zsh-kit wrapper changes: call-through for launcher-owned commands and JSON-based orchestration for create.
- Out-of-scope:
  - Wrapper-only Dev Containers extras (snapshot, private repo seeding, `/opt/*` refresh, VS Code open, rsync/reset workflows).
  - Hardening auto-download supply chain (pin to tags, signatures) beyond noting the risk.
  - Cross-shell (bash/fish) UX parity for the wrapper.

## I/O Contract

### Input

- CLI args: `codex-workspace <command> [flags]` (launcher) and `codex-workspace ...` wrapper commands that delegate to launcher.
- Host paths: `--secrets-dir <host-path>` (opt-in secrets), optional repo spec inputs (`OWNER/REPO`, `https://...`, `git@...`).
- Environment: Docker daemon access; optional auth material provided by the wrapper (e.g. GitHub token).

### Output

- Human output: stderr (launcher), host prompts/logging (wrapper).
- Machine output: stdout JSON when `--output json` is set (launcher), consumed by wrapper.
- Side effects: Docker container + named volumes; optional cloned repo into container `/work/...`; optional tunnel process + log file.

### Intermediate Artifacts

- Tunnel logs on host (path returned in launcher JSON).
- Planning and runbook docs:
  - `docs/progress/20260122_codex-workspace-launcher-wrapper-migration.md`
  - `docs/runbooks/codex-workspace-migration.md`

## Design / Decisions

### Rationale

- Keep the launcher shell-agnostic and minimal while making its contract explicit and machine-readable, so wrappers can evolve without drifting.
- Keep host-opinionated behavior in the wrapper, but force launcher-owned lifecycle operations to call-through to a single canonical implementation.

### Risks / Uncertainties

- Risk: breaking changes in launcher flags/output can strand older wrappers. Mitigation: add `--version` + capabilities and enforce minimum version in wrapper.
- Risk: tunnel naming and logging expectations differ across environments. Mitigation: enforce `<= 20` chars in launcher and return `tunnel_name` + `log_path` in JSON.
- Risk: secrets defaults can accidentally leak host paths into a “canonical” launcher contract. Mitigation: no launcher default; require explicit `--secrets-dir` opt-in.
- Risk: planning spans multiple repos (codex-kit + zsh-kit). Mitigation: keep links explicit (progress file + planning PR + implementation PRs) and validate with end-to-end smoke steps.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, use `- [ ] ~~like this~~` and include `Reason:`. Unchecked and unstruck items (e.g. `- [ ] foo`) will block close-progress-pr.

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Move migration doc to `docs/runbooks/` and ensure it reflects the approved contract decisions.
    - [ ] Create and merge a progress planning PR (docs-only) to track this work.
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - `docs/runbooks/codex-workspace-migration.md`
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned in this progress file.
    - [ ] Data flow and I/O contract are defined (CLI inputs / JSON outputs / side effects).
    - [ ] Risks and rollback notes are captured.
    - [ ] A minimal verification plan exists (smoke commands in Step 3).
- [ ] Step 1: Minimum viable launcher contract (codex-kit)
  - Work Items:
    - [ ] Add `--version` and capabilities.
    - [ ] Implement `create/up --output json` with stdout JSON / stderr logs.
    - [ ] Implement secrets opt-in (`--secrets-dir` required; no default).
    - [ ] Implement tunnel name policy + JSON output (requires `--detach`).
    - [ ] Implement `rm` default volumes removal with `--keep-volumes`.
  - Artifacts:
    - `docker/codex-env/bin/codex-workspace`
    - `docker/codex-env/README.md`
    - `docker/codex-env/WORKSPACE_QUICKSTART.md`
  - Exit Criteria:
    - [ ] At least one happy path runs end-to-end (create + optional clone): `codex-workspace create --output json OWNER/REPO`.
    - [ ] JSON output is valid and stdout-only (no interleaved logs); stderr contains any human logs.
    - [ ] Usage docs updated with new defaults and flags.
- [ ] Step 2: Wrapper integration (zsh-kit)
  - Work Items:
    - [ ] Switch wrapper `create` orchestration to consume launcher JSON output.
    - [ ] Make wrapper `ls`/`start`/`stop`/`rm` call-throughs to launcher.
    - [ ] Optionally enforce minimum launcher version/capabilities.
  - Artifacts:
    - `scripts/_features/codex-workspace/*` (zsh-kit)
  - Exit Criteria:
    - [ ] Wrapper no longer parses launcher human output; wrapper logic is driven by JSON.
    - [ ] Launcher-owned commands have no duplicate logic in wrapper (thin delegation only).
- [ ] Step 3: Validation / smoke tests
  - Work Items:
    - [ ] Run launcher smoke commands locally.
    - [ ] Run wrapper smoke commands locally.
  - Artifacts:
    - CI results for implementation PRs
    - Local command logs (copy/paste or saved logs if needed)
  - Exit Criteria:
    - [ ] Launcher: `--version`, `--help`, `create --output json`, `tunnel --detach --output json`, and `rm` behave as specified.
    - [ ] Wrapper: `create` works end-to-end using JSON output; lifecycle commands call-through.
    - [ ] Evidence recorded (PR Testing sections + any necessary logs).
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Update progress file Links with implementation PRs and mark status DONE when complete.
    - [ ] If released, record version/tag and relevant notes.
  - Artifacts:
    - `docs/progress/20260122_codex-workspace-launcher-wrapper-migration.md`
  - Exit Criteria:
    - [ ] Documentation completed and entry points updated (README / docs index links).
    - [ ] Cleanup completed (archive progress file when done).

## Modules

- codex-kit launcher: `docker/codex-env/bin/codex-workspace` (canonical lifecycle + contract)
- codex-kit docs: `docs/runbooks/codex-workspace-migration.md` + `docker/codex-env/*` docs
- zsh-kit wrapper: `~/.config/zsh/scripts/_features/codex-workspace/*` (host UX and orchestration)
