# Codex Workspace: launcher/wrapper migration

Status: Draft  
Last updated: 2026-01-21

This doc is a migration plan to reduce drift between:

- **codex-kit launcher (canonical, shell-agnostic)**: `docker/codex-env/bin/codex-workspace`
- **zsh wrapper + Dev Containers extras**: `~/.config/zsh/scripts/_features/codex-workspace/*` (not in this repo)

## Decisions (approved)

- **Entry point**: a shell-agnostic executable lives in **codex-kit**.
- **Dev Containers extras** (snapshot, private repo, VS Code open, etc.) remain in the **zsh wrapper**.
- **Secrets**: no launcher default; secrets are opt-in and require `--secrets-dir <host-path>`.
  - Recommended: `--secrets-dir ~/.config/codex_secrets --secrets-mount /home/codex/codex_secrets`
- **Compatibility**: breaking changes are acceptable.
- **Launcher selection**: prefer local codex-kit checkout; fallback to auto-download when missing.
- **Ownership clarifications**:
  - `ls` is **launcher-owned** (wrapper should call-through, not re-implement).
  - `shell/exec` is **wrapper-owned** (host UX; do not build a stable launcher surface for it).
  - `start/stop` is **launcher-owned**, with an optional **wrapper UX** that must call-through (no duplicate implementation).

## Current state (inventory)

### codex-kit launcher (`docker/codex-env/bin/codex-workspace`)

Owns the core container lifecycle:

- `up`: create workspace container (named volumes), optional repo clone into `/work`, optional `--ref` checkout
- `ls`, `start`, `stop`, `rm`, `shell`
- `tunnel`: start VS Code tunnel inside the container (`--detach` supported)
- Secrets mount flags: `--secrets-dir`, `--secrets-mount`, `--no-secrets`
- Git auth flags: `--persist-gh-token`, `--setup-git`
- Optional `--codex-profile` (requires secrets)

Notable current defaults (subject to change):

- Secrets default is zsh-kit-oriented (host: `~/.config/zsh/.../codex/secrets`, mount: `/opt/zsh-kit/.../secrets`).
- `tunnel` name is derived from container name and can exceed VS Code’s 20-char limit.
- `up` prints human output; wrappers parse `workspace:` + `path:` lines as an implicit contract.

### zsh wrapper (`~/.config/zsh/scripts/_features/codex-workspace/*`)

Acts as an orchestrator around the launcher and adds “Dev Containers” conveniences:

- `codex-workspace create ...`: selects GitHub auth mode (keyring vs env), then calls launcher `up`
- Post-create extras (typical): refresh `/opt/*` repos, snapshot `~/.config`, seed `~/.private`, clone extra repos
- Additional host-side helpers (separate files): `auth`, `exec`, `rsync`, `reset`, `rm`, `tunnel`, `ls`
- Auto-downloads the launcher when missing (from `raw.githubusercontent.com/.../codex-kit/...`)

## Target architecture

### Ownership boundaries

- **codex-kit (canonical launcher)**
  - **Minimum** (must be correct + stable): create/up, ls, start/stop, tunnel, rm
  - **Contract surface**: stable machine-readable output (JSON) + version/capabilities
  - **Defaults**: match the agreed secrets scheme
- **zsh wrapper**
  - Dev Containers extras and opinionated host orchestration:
    - auth selection and token plumbing
    - snapshot host config
    - private repo seeding + extra repo cloning
    - optional GPG import
    - optional auto-open VS Code
    - power tools: rsync, reset workflows

### Minimum codex-kit surface (what must live here)

codex-kit is the canonical, shell-agnostic entry point. To keep it small and reduce drift, the **minimum long-term supported surface** should be:

- `codex-workspace create` (alias `up`)
  - Creates the workspace container + named volumes
  - Optionally clones a repo into `/work` (and optionally checks out `--ref`)
  - Secrets are opt-in via `--secrets-dir` (launcher has no host-path default)
  - Exposes a machine-readable output mode for wrappers (JSON)
- `codex-workspace ls`
  - Lists workspace containers with stable semantics/filters (wrapper should call-through)
- `codex-workspace start` / `codex-workspace stop`
  - Canonical start/stop implementation (wrapper may expose a UX alias but must call-through)
- `codex-workspace tunnel`
  - Sanitizes/limits tunnel names (<= 20 chars)
  - Supports `--detach` and logs to a stable path
- `codex-workspace rm`
  - Removes container + workspace volumes by default (`--keep-volumes` keeps volumes)
- `codex-workspace --version` (and/or `capabilities`)
  - Lets wrappers require a minimum launcher

### zsh wrapper surface (what should NOT live in codex-kit)

Keep host-opinionated and Dev Containers-specific behavior in the wrapper:

- `auth` (github/codex/gpg) orchestration and keyring/env selection
- attach UX: `shell` / `exec` (wrapper-owned; may rely on wrapper-only container auto-pick)
- post-create extras: snapshot host `~/.config`, seed `~/.private`, clone extra repos, refresh `/opt/*`
- `rsync`, `reset` (power tools)
- UX sugar: auto-pick container, prompts, aliases, completion, auto-open VS Code

### Contract goals (to prevent future drift)

Wrappers should not parse ad-hoc human output. The launcher should expose:

- A **version** or **capability** signal (e.g. `--version` or `--supports <feature>`).
- A **machine-readable output mode** for create/up (e.g. `--output json`), including:
  - `container`, `repo_dir`, `repo` (if any), `image`, `created_at`, `secrets_mount`, `git_auth_mode`
- A consistent tunnel naming behavior (sanitize + <= 20 chars) with override support.

## Feature map (what moves / what stays)

| Status | Feature | Today | Target owner | Notes |
| --- | --- | --- | --- | --- |
| [ ] | Parse repo spec (OWNER/REPO, git@, https) | Both | Launcher | Wrapper should stop re-implementing or validate via contract/tests |
| [ ] | Create container + volumes | Launcher | Launcher | Canonical |
| [ ] | Clone repo into `/work` | Launcher | Launcher | Canonical |
| [ ] | Secrets mount contract (`--secrets-dir` required) | Both | Launcher | Launcher has no default; wrapper passes explicit `--secrets-dir` + `--secrets-mount` |
| [ ] | Git auth setup (`--persist-gh-token`, `--setup-git`) | Launcher | Launcher | Wrapper selects token source |
| [ ] | Codex profile apply (`codex-use`) | Both | Launcher | Wrapper only passes `--codex-profile` |
| [ ] | List workspaces (`ls`) | Both | Launcher | Wrapper should call-through (no re-implementation) |
| [ ] | Start/stop workspace | Launcher | Launcher | Wrapper may add UX, but must call-through to launcher |
| [ ] | VS Code tunnel | Both | Launcher | Wrapper should call launcher once parity is reached |
| [ ] | Remove workspace + volumes | Launcher | Launcher | Canonical implementation; wrapper must call-through (no duplicate logic) |
| [ ] | Attach to workspace (`shell`/`exec`) | Both | Wrapper | Wrapper-owned UX (launcher should not promise a stable attach surface) |
| [ ] | Rsync host ↔ container | Wrapper | Wrapper | Keep out of launcher |
| [ ] | Reset repo(s) inside container | Wrapper | Wrapper | Keep out of launcher |
| [ ] | Host config snapshot (`~/.config` copy) | Wrapper | Wrapper | Keep out of launcher |
| [ ] | Refresh `/opt/codex-kit` + `/opt/zsh-kit` | Wrapper | Wrapper | Keep out of launcher |
| [ ] | Private repo seeding (`~/.private`) | Wrapper | Wrapper | Keep out of launcher |
| [ ] | Extra repos cloning | Wrapper | Wrapper | Keep out of launcher |
| [ ] | GPG import | Wrapper | Wrapper | Keep out of launcher |

Status legend:
- `[ ]` TODO
- `[-]` DOING
- `[x]` DONE

## TODO (implementation checklist)

### codex-kit: launcher changes

- [ ] Add `--version` (and/or a small `capabilities` output) so wrappers can require a minimum launcher.
- [ ] Add `up/create --output json` (or similar) and define a stable JSON schema (stop wrappers parsing human output).
- [ ] Add `create` as an alias of `up` (keep `up` for backwards compatibility).
- [ ] Make repo spec parsing a single-source-of-truth (`OWNER/REPO`, `git@...`, `https://...`) and document supported forms.
- [ ] Remove launcher secrets host-path defaults; require explicit `--secrets-dir` for any secrets mount.
  - [ ] Keep `--secrets-mount` default at `/home/codex/codex_secrets` and allow override
  - [ ] When secrets are mounted, set `CODEX_SECRET_DIR=<mount>` inside the container
- [ ] Validate `--codex-profile` behavior under the new secrets defaults (and keep failure modes clear).
- [ ] Confirm/adjust git auth behavior (`--persist-gh-token`, `--setup-git`) and document expectations for wrappers.
- [ ] Ensure `ls` is canonical and stable (filter by label first; fallback prefix scan only when needed).
- [ ] Ensure `start` / `stop` semantics are canonical and stable (wrapper must call-through).
- [ ] Align `tunnel` behavior with wrapper:
  - [ ] accept `--name <tunnel_name>` (sanitized)
  - [ ] enforce `<= 20` chars (VS Code requirement)
  - [ ] improve default name derivation (strip prefix + timestamp, add hash when truncating)
- [ ] Implement and document `rm` semantics: default removes volumes; `--keep-volumes` keeps volumes (optionally keep `--volumes` as an alias).
- [ ] Update docs in this repo:
  - [ ] `docker/codex-env/README.md` (defaults, examples, migration note)
  - [ ] `docker/codex-env/WORKSPACE_QUICKSTART.md`

### zsh wrapper: orchestration and dedupe

- [ ] Prefer **local codex-kit checkout** as the default launcher path; auto-download only when missing.
- [ ] Stop parsing human output; switch to launcher `--output json` once available.
- [ ] Make wrapper `ls`/`start`/`stop`/`rm` thin call-throughs to launcher (no duplicate implementation).
- [ ] Replace wrapper tunnel implementation with `"$launcher" tunnel ...` once parity is reached.
- [ ] Add/adjust completion and aliases if command names change (e.g. `create` vs `up`).

### Validation (manual / smoke)

- [ ] `codex-workspace --help` shows `create` and `--output`.
- [ ] `codex-workspace create OWNER/REPO` creates container + clones repo in `/work/<owner>/<repo>`.
- [ ] `codex-workspace create --no-clone --name ws-foo` creates container without cloning.
- [ ] Secrets mount works when provided: `--secrets-dir ...` results in `CODEX_SECRET_DIR=/home/codex/codex_secrets` inside container.
- [ ] `codex-workspace tunnel ws-foo` uses a valid <=20 name; `--name` override works.
- [ ] zsh wrapper `codex-workspace create` still works end-to-end with the updated launcher.

## Rollout plan

1. Land launcher contract changes (alias/version/json output/tunnel/secrets defaults).
2. Update zsh wrapper to require the new launcher (min version) and use JSON output.
3. Update docs and announce secrets no longer auto-mount (breaking; wrapper must pass `--secrets-dir`).
4. Optionally deprecate wrapper re-implementations of lifecycle commands (ls/rm/tunnel) after parity.

## Risks / notes

- Auto-download from `main` is a supply-chain risk; consider pinning to a tag/release later.
- Changing secrets defaults is breaking; provide clear error messages and migration notes.
- Tunnel naming must remain within VS Code constraints; enforce in the launcher to avoid surprises.
