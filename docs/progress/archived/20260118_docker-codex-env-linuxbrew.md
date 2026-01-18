# codex-kit: Docker Codex env (Linuxbrew)

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-18 | 2026-01-18 |

Links:

- PR: https://github.com/graysurf/codex-kit/pull/59
- Planning PR: https://github.com/graysurf/codex-kit/pull/58
- Docs: [docker/codex-env/README.md](../../../docker/codex-env/README.md)
- Glossary: [docs/templates/PROGRESS_GLOSSARY.md](../../templates/PROGRESS_GLOSSARY.md)

## Addendum

- None

## Goal

- Provide a Docker-based Codex work environment on Ubuntu Server (Linux host, headless) that mirrors the macOS setup as closely as practical (Linux container + zsh).
- Install CLI tooling via Linuxbrew from `zsh-kit` tool lists, with explicit apt fallbacks/removals when Linuxbrew lacks a package.
- Support running multiple isolated environments concurrently (separate `HOME`/`CODEX_HOME` state per environment).
- Provide a host-invoked “workspace launcher” workflow that can start a fresh container, clone a target repo, and (optionally) start a VS Code tunnel for remote development.
- Keep secrets and mutable state out of the image (inject via volumes/env at runtime).

## Acceptance Criteria

- `docker build` succeeds on Ubuntu Server (Docker Engine, headless) for the target architecture.
- In the container, `zsh -lic 'echo ok'` succeeds (no startup errors) and the required tool executables are on `PATH`.
- All required tools from `/Users/terry/.config/zsh/config/tools.list` are installed via Linuxbrew (or documented apt fallback/removal), and a smoke command verifies them.
- Optional tools from `/Users/terry/.config/zsh/config/tools.optional.list` are installed by default (or documented apt fallback/removal), with an explicit opt-out for faster builds if needed.
- Two environments can run concurrently and do not share mutable state (verify via distinct named volumes for `HOME` and `CODEX_HOME`).
- Codex CLI is runnable in-container (`codex --version`), with auth/state stored outside the image (volume or env-based).
- macOS VS Code can tunnel/attach to the container on the Ubuntu Server host (no Docker Desktop required).
- A host-side workspace launcher can start an isolated workspace from a git repo input (including `git@github.com:...`), clone the repo inside the container (no host workspace bind mount), and provide a repeatable “connect via VS Code tunnel” workflow.

## Scope

- In-scope:
  - Add Docker assets (Dockerfile + compose/run docs) to `codex-kit` for an Option A (Linuxbrew) dev environment.
  - Use `zsh-kit` tool lists as the source of truth for Linuxbrew-installed CLI tools.
  - Provide a clear fallback policy for missing Linuxbrew packages (apt replacement or explicit removal with documented deviation).
  - Provide an explicit multi-environment run workflow (multiple concurrent containers, each with isolated volumes/state).
  - Provide smoke verification commands/scripts to prove the environment matches the declared DoD.
  - Support headless Ubuntu Server hosts with macOS VS Code tunnel access to containers.
  - Add a host-invoked workspace launcher script to spawn a new isolated workspace from a git repo input (with optional VS Code tunnel startup).
- Out-of-scope:
  - Docker Desktop-specific workflows and macOS containers (target host is Ubuntu Server).
  - GUI apps, macOS-only tooling (`pbcopy`, `open`, etc.) unless explicitly shimmed or documented as unavailable.
  - Publishing images to a registry (GHCR) unless explicitly requested later.
  - Refactoring `zsh-kit` itself beyond what is required for container compatibility.

## I/O Contract

### Input

- Tool lists:
  - `/Users/terry/.config/zsh/config/tools.list`
  - `/Users/terry/.config/zsh/config/tools.optional.list`
  - `/Users/terry/.config/zsh/config/tools.macos.list` (if present)
  - `/Users/terry/.config/zsh/config/tools.optional.macos.list` (if present)
  - `/Users/terry/.config/zsh/config/tools.linux.list` (if present)
  - `/Users/terry/.config/zsh/config/tools.optional.linux.list` (if present)
  - `/Users/terry/.config/zsh/config/tools.linux.apt.list` (if present; Linux only)
  - `/Users/terry/.config/zsh/config/tools.optional.linux.apt.list` (if present; Linux only)
- Source repos (public):
  - `https://github.com/graysurf/zsh-kit.git`
  - `https://github.com/graysurf/codex-kit.git`
- Runtime host mounts (optional, for “live config” mode):
  - `~/.config/zsh/` (bind mount into container, ideally read-only)
  - Workspace repo(s) (bind mount)
- Runtime secrets/state injection:
  - `OPENAI_API_KEY` (env) and/or `CODEX_HOME` (named volume) for Codex auth/session files

### Output

- Docker build/runtime assets (planned paths; exact layout decided in Step 0):
  - `Dockerfile` (repo root)
  - `docker-compose.yml` (repo root)
  - `docker/codex-env/README.md` (TL;DR usage + knobs)
  - `docker/codex-env/bin/codex-workspace` (host-side launcher; name TBD)
  - Optional: `docker/codex-env/smoke.sh` (host-invoked verification)

### Intermediate Artifacts

- Verification logs and tool inventory outputs (written under `out/`):
  - `out/docker/build/` (build logs, brew/apt inventories)
  - `out/docker/verify/` (smoke results, captured versions)

## Design / Decisions

### Rationale

- Choose Linuxbrew to maximize parity with the macOS Homebrew toolchain while staying inside Linux containers.
- Use the existing `zsh-kit` tool lists as the single source of truth for what gets installed via brew.
- Keep secrets out of the image; isolate state per environment via named volumes to enable multiple concurrent, “safe” environments.

### Decisions

- Optional tools are installed by default (required + optional lists), with an explicit opt-out if build time becomes a bottleneck.
- Install priority order (per tool): Linuxbrew > OS package manager (apt) > release binary download.
- Source repos (`zsh-kit`, `codex-kit`) are cloned during image build for reproducibility (pinned to an explicit ref).
- Split `zsh-kit` tool lists by OS (macOS/Linux) and add Linux apt-only lists for tools that cannot be installed via Linuxbrew (e.g. VS Code `code`, `mitmproxy`).
- Target runtime: Ubuntu Server (Docker Engine, headless) with macOS VS Code tunnel access to containers; no Docker Desktop requirement.
- Repository layout: `Dockerfile` + `docker-compose.yml` at repo root; keep helper scripts/docs under `docker/codex-env/`.
- `HOME`/`CODEX_HOME`: per-environment named volumes (no sharing), with `HOME=/home/codex` and `CODEX_HOME=/home/codex/.codex`.
- Security baseline: no extra hardening (skip `cap_drop` and `no-new-privileges`); default read-write mounts.
- Minimum smoke verification set: `rg fd fzf gh jq codex opencode gemini psql mysql sqlcmd`.

### Tool install audit (Ubuntu 24.04)

Audit evidence (local):
- `out/docker/verify/brew-dryrun.tsv` (full `brew install -n` scan across both lists)
- `out/docker/verify/install-brew-required-and-agents.log` (installed required tools + `codex`/`opencode`/`gemini`)
- `out/docker/verify/install-apt-mitmproxy.log` (apt fallback for `mitmproxy`)

Findings:
- Linuxbrew dry-run indicates all declared tools are installable via `brew install -n`.
- `codex`: `brew install codex` works on `linux/arm64` (downloads `codex-aarch64-unknown-linux-musl.tar.gz`).
- `visual-studio-code`: `brew install visual-studio-code` fails on Linux (`macOS is required for this software`).
  - Fallback: install `code` via Microsoft apt repo (works; but pulls a large dependency set).
- `mitmproxy`: Homebrew provides a macOS-only cask (installs a Mach-O binary that cannot run on Linux).
  - Fallback: Ubuntu `apt` package `mitmproxy` works (version `8.1.1` in `24.04`).
- DB CLIs:
  - `psql`: use Homebrew `libpq` (keg-only; add `opt/libpq/bin` to `PATH`).
  - `mysql`: use Homebrew `mysql-client` (keg-only; add `opt/mysql-client/bin` to `PATH`).
  - `sqlcmd`: use Homebrew `sqlcmd` (Homebrew core; `microsoft/mssql-release/mssql-tools18` is not required and hit a `linux/arm64` install error via `msodbcsql18` during testing).

### Risks / Uncertainties

- Linuxbrew availability/compatibility on `linux/arm64` (bottles missing → slow source builds or failures).
  - Mitigation: maintain explicit apt fallbacks/removals and (optionally) support `linux/amd64` builds as a secondary path.
- CLI name differences vs macOS (e.g., `coreutils` “g*” prefixed commands on macOS vs Linux defaults).
  - Mitigation: add compatibility shims where needed, or document command-name deltas explicitly.
- Codex CLI and agent tooling availability on Linux (some are macOS casks) and update cadence.
  - Mitigation: follow the install priority order (brew > apt > release binary), record exact chosen sources/versions, and document upgrade steps.
- Volume layout and mounting strategy (clone-in-image vs bind-mount local repos) affects reproducibility vs convenience.
  - Mitigation: support two run modes (self-contained image defaults + optional bind mounts for local iteration).
- Read-only bind mounts of `zsh-kit` can break plugin cloning/auto-update (plugins live under `ZDOTDIR` by default).
  - Mitigation: prefer clone-in-image; or mount only `config/` read-only; or override `ZSH_PLUGINS_DIR` to a writable volume/path.
- No hardening baseline increases risk if the host is shared or untrusted.
  - Mitigation: run on trusted Ubuntu servers only; revisit hardening if threat model changes.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, close-progress-pr will auto-wrap the item text with Markdown strikethrough (use `- [ ] ~~like this~~`).

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm target runtime: Ubuntu Server (Docker Engine, headless) with macOS VS Code tunnel access; support native Linux hosts (amd64/arm64).
    - [x] Decide repository layout for Docker assets: repo-root `Dockerfile` + `docker-compose.yml`; keep helper scripts/docs under `docker/codex-env/`.
    - [x] Confirm tool-install policy:
      - Required install set (brew) = `/Users/terry/.config/zsh/config/tools.list` (+ OS-specific required lists if present)
      - Optional install set (brew) = `/Users/terry/.config/zsh/config/tools.optional.list` (+ OS-specific optional lists if present)
      - Linux apt-only additions (optional) = `tools.linux.apt.list` / `tools.optional.linux.apt.list` (if present)
      - Default behavior: install required + optional (opt-out only).
    - [x] Decide how to source `zsh-kit` and `codex-kit` inside the container:
      - Clone during image build (self-contained, pinned revision/ref).
    - [x] Decide install fallback order (per tool): Linuxbrew > apt > release binary.
    - [x] Decide `CODEX_HOME` strategy:
      - `HOME=/home/codex`
      - `CODEX_HOME=/home/codex/.codex`
      - One named volume per environment for `HOME` + `CODEX_HOME` (no sharing).
    - [x] Validate and record the Linux install method for key tools that may not exist on Linuxbrew (follow the fallback order):
      - `codex`: Linuxbrew cask works on `linux/arm64` (no fallback needed).
      - `opencode`: Linuxbrew formula works on `linux/arm64`.
      - `gemini-cli`: Linuxbrew formula works on `linux/arm64` (installs `gemini`).
      - `code`/VS Code: Linuxbrew cask is macOS-only; fallback to Microsoft apt repo.
      - `psql`: Homebrew `libpq` works on `linux/arm64` (keg-only).
      - `mysql`: Homebrew `mysql-client` works on `linux/arm64` (keg-only).
      - `sqlcmd`: Homebrew `sqlcmd` works on `linux/arm64`.
    - [x] Define security baseline for runtime:
      - No extra hardening (skip `cap_drop` and `no-new-privileges`).
      - Read-write mounts by default.
    - [x] Define the minimum smoke verification commands and expected outputs:
      - `rg fd fzf gh jq codex opencode gemini psql mysql sqlcmd` present; `--version`/`--help` works.
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - `docs/progress/README.md` entry (In progress table)
    - `docker/codex-env/README.md` (planned) describing decisions and usage
    - Implementation PR: https://github.com/graysurf/codex-kit/pull/59
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: reviewed in this progress doc.
    - [x] Data flow and I/O contract are defined: container inputs/outputs/volumes/build args documented here.
    - [x] Risks and mitigation plan are defined: captured above, with explicit “what to do when brew fails” policy.
    - [x] Minimal reproducible verification commands are defined: see Step 1/3 exit criteria.
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Add `Dockerfile` at repo root (Ubuntu base + apt bootstrap).
    - [x] Use `codex` user by default (passwordless sudo); root still available when needed.
    - [x] Install Linuxbrew and ensure brew is on `PATH` for login shells.
    - [x] Install required + optional CLI tools from `tools.list` and `tools.optional.list` by default.
      - Preferred: reuse `zsh-kit` installer logic (clone `zsh-kit`, run its installer in a non-interactive mode).
      - Ensure Docker build does not hang on confirmation prompts (add a non-interactive path if needed).
    - [x] Add minimal runtime wiring:
      - `WORKDIR` default (e.g. `/work`)
      - container starts into `zsh -l` (or a small entrypoint that execs it)
    - [x] Add `docker-compose.yml` with:
      - bind mount workspace(s)
      - named volume(s) for `HOME` and `CODEX_HOME`
      - no extra hardening flags (per Step 0 decision)
    - [x] Install Codex CLI in the container (exact mechanism TBD in Step 0) and validate it starts.
    - [x] Create a minimal `docker/codex-env/README.md` with TL;DR commands.
  - Artifacts:
    - `Dockerfile`
    - `docker-compose.yml`
    - `docker/codex-env/README.md`
  - Exit Criteria:
    - [x] Image builds: `docker build -f Dockerfile -t codex-env:linuxbrew .`
    - [x] Interactive shell works: `docker run --rm -it codex-env:linuxbrew zsh -l`
      - Evidence: `out/docker/verify/20260118_084317/interactive.log`
    - [x] Tools on PATH (example smoke): `zsh -lic 'rg --version && fd --version && fzf --version && gh --version && jq --version && codex --version && opencode --version && gemini --version && psql --version && mysql --version && sqlcmd --help'`
      - Evidence: `out/docker/verify/20260118_084317/smoke.log`
    - [x] `codex --version` works in-container (auth may still be TBD if using per-env volumes).
      - Evidence: `out/docker/verify/20260118_084317/versions.txt`
    - [x] Docs include the exact build/run commands and required mounts.
- [ ] Step 2: Expansion / integration
  - Reason: Remaining validation items are tracked in Step 3; optional submodules/caching work is deferred.
  - Work Items:
    - [x] Add explicit opt-out for optional tools (default is required + optional):
      - Build arg `INSTALL_OPTIONAL_TOOLS=0` (or equivalent) OR separate minimal Docker target/tag.
      - Optional: split `tools.optional.list` into “default” vs “heavy/debug-only” groups at install time (if build time becomes a bottleneck).
    - [x] Define/implement a fallback policy for missing Linuxbrew formulas:
      - Maintain an explicit `apt` fallback list, OR
      - Maintain an explicit “removed on Linux” list with documented deviations.
    - [x] Add compatibility shims when required (only when proven necessary by smoke tests):
      - Example: provide `gdate`/`gseq` aliases or symlinks if scripts assume macOS GNU coreutils naming.
      - Decision: Document-only (no shims). See `docker/codex-env/README.md`.
    - [x] Add a “local bind-mount mode” for `zsh-kit` and/or `codex-kit` (read-only mounts) for fast iteration.
    - [x] Provide runtime secrets injection docs and compose overrides for GitHub/Codex auth.
      - Codex profiles use `codex-use` with secrets mounted under `/opt/zsh-kit/scripts/_features/codex/secrets`.
    - [x] Add a host-side “workspace launcher” (Option A) to quickly start an isolated workspace container from a repo input.
      - CLI / UX (interface + output):
        - [x] Decide final command name and location:
          - `docker/codex-env/bin/codex-workspace`
        - [x] Define the minimum supported command set:
          - `up <repo>`: create/start workspace + clone repo (idempotent).
          - `tunnel <name>`: start or attach to `code tunnel` for the workspace.
          - `shell <name>`: open an interactive shell in the workspace.
          - `ls`: list workspaces (containers) created by this tool.
          - `stop <name>` / `start <name>`: lifecycle control.
          - `rm <name>`: remove workspace container (and optionally volumes).
        - [x] Define flags and environment variables (document defaults):
          - `--name <workspace>` (default: derived from repo + timestamp)
          - `--image <image>` / `CODEX_ENV_IMAGE` (default: `graysurf/codex-env:linuxbrew`)
          - `--no-pull` (skip `docker pull` when image missing locally)
          - `--ref <git-ref>` (optional)
          - `--dir <path>` (optional; default: `/work/<owner>/<repo>`)
          - `--secrets-dir <path>` / `CODEX_SECRET_DIR_HOST` (optional host secrets dir mount)
          - `--no-secrets` (skip secrets mount)
          - `--codex-profile <profile>` (optional; run `codex-use <profile>` inside container)
          - `--tunnel` / `--tunnel-detach` (optional; start tunnel after `up`)
        - [x] Ensure all outputs are “copy/paste friendly”:
          - Print next-step commands: `docker exec -it <name> zsh -l`, `docker logs -f <name>`, `code tunnel ...`.
          - Never echo token values; redact env var values in logs.
      - Image / container orchestration:
        - [x] Implement “ensure image exists”:
          - If `docker image inspect "${CODEX_ENV_IMAGE}"` fails → run `docker pull "${CODEX_ENV_IMAGE}"`.
          - Allow skip via `--no-pull` for offline hosts.
        - [x] Start container in detached mode with a long-running command (so later `docker exec` works consistently).
        - [x] Apply discoverability labels so `ls` can be accurate (example):
          - `--label codex-kit.workspace=1`
          - `--label codex-kit.repo=<normalized>`
          - `--label codex-kit.created-at=<iso8601>`
        - [x] Set container `--workdir /work` and ensure `/work` exists and is writable.
          - Also set image baseline: `Dockerfile` ensures `/work` is owned by `codex` to avoid permissions issues for fresh named volumes.
        - [x] Ensure workspace state isolation:
          - One named volume per workspace for `/work`.
          - One named volume per workspace for `/home/codex`.
          - One named volume per workspace for `/home/codex/.codex`.
        - [x] Make naming deterministic and collision-safe:
          - Normalise repo name (`OWNER_REPO`), add timestamp suffix by default.
          - Reject invalid Docker names; provide a safe fallback.
      - Repo cloning behavior (no host bind mount):
        - [x] Accept and normalize repo inputs:
          - `git@github.com:OWNER/REPO.git`
          - `ssh://git@github.com/OWNER/REPO.git`
          - `https://github.com/OWNER/REPO.git`
          - `OWNER/REPO`
          - (Optional) enterprise GitHub host via `GITHUB_HOST` (for `OWNER/REPO` form) or full URL input.
        - [x] Prefer HTTPS clone with token-based auth:
          - Use `git clone https://...` with `GIT_ASKPASS` + `GH_TOKEN`/`GITHUB_TOKEN` (avoids embedding tokens into `.git/config` remote URLs).
        - [x] Idempotency:
          - If repo directory exists (has `.git`) → skip clone.
        - [ ] Optional: support submodules (`git submodule update --init --recursive`) behind a flag.
          - Reason: Defer until a concrete repo requires submodules.
        - [x] Verify clone result by printing `git remote -v` (no token embedded).
      - GitHub auth injection at runtime:
        - [x] Support `GH_TOKEN`/`GITHUB_TOKEN` injection without persisting into image layers:
          - Pass tokens via `docker exec -e GH_TOKEN -e GITHUB_TOKEN` during clone (avoid storing in container metadata when possible).
        - [x] Provide a fallback path for SSH cloning when token is unavailable (optional):
          - Document using `docker/codex-env/docker-compose.ssh.yml` (ssh-agent forwarding + known_hosts).
      - Codex auth integration (profile-based; no direct `auth.json` mount):
        - [x] If `--codex-profile` is provided:
          - Mount secrets dir (must be `:rw`).
          - Run `zsh -lc 'codex-use <profile>'` inside the workspace container.
          - Verify `codex --version` and `codex auth status` (or equivalent) works.
        - [x] Document the manual path (no automation):
          - `docker exec -it <name> zsh -lc 'codex-use <profile>'`
      - VS Code tunnel workflow:
        - [x] Implement `tunnel` subcommand:
          - Start `code tunnel --accept-server-license-terms --name <workspace>` in the container.
          - Support “foreground attach” (tail logs) vs “background” mode.
        - [x] Handle first-run interactive login expectations:
          - Print clear instructions for device-code login prompts.
          - Ensure tunnel auth state persists in the workspace `HOME` volume.
        - [x] Provide a “status” check:
          - Detect if `code tunnel` is already running (process check) and show what to do next.
      - Documentation:
        - [x] Add a dedicated section to `docker/codex-env/README.md`:
          - “Quick start a workspace from a repo”
          - “How to connect from macOS VS Code”
          - “How to inject GH token and Codex profiles”
          - “How to list/stop/remove workspaces”
        - [ ] Document limitations (e.g., host path differences on macOS vs Ubuntu Server).
          - Reason: Defer until we validate on Ubuntu Server host (vs OrbStack local).
      - Operational notes:
        - [x] Add a cleanup guide to prevent disk bloat:
          - list volumes/images created by the tool
          - safe remove commands (container-only vs container+volumes)
        - [x] Add a safety note about secrets (do not commit tokens; prefer env/secret mounts).
    - [ ] Improve build speed via BuildKit caching for brew downloads/builds (optional, but recommended).
      - Reason: Defer until baseline build times are captured.
  - Artifacts:
    - `docker/codex-env/README.md` updates (document knobs, fallback policy, and known deltas vs macOS)
    - `docker/codex-env/WORKSPACE_QUICKSTART.md` (Dev Containers + Remote Tunnels quick start)
    - `docker/codex-env/bin/codex-workspace` (workspace launcher)
    - `docker/codex-env/apt-fallback.txt` (or equivalent mapping file)
    - `docker/codex-env/docker-compose.local.yml` (optional local bind-mount override)
    - `docker/codex-env/docker-compose.secrets.yml` (optional secrets override)
    - `docker/codex-env/docker-compose.ssh.yml` (optional SSH override)
    - Optional: `docker/codex-env/shims/` (only if needed)
  - Exit Criteria:
    - [ ] Optional opt-out path works and is documented (commands + expected results).
      - Reason: Documented; waiting on `INSTALL_OPTIONAL_TOOLS=0` build confirmation.
    - [ ] Missing-formula handling is explicit and reproducible (no “mystery failures” during build).
      - Reason: Documented fallback policy; awaiting verification on a fresh build.
    - [x] Multi-env workflow is documented and proven with two concurrent compose projects.
      - Evidence: `out/docker/verify/20260118_084317/multi-env.log`
    - [x] Workspace launcher is implemented and documented:
      - `docker/codex-env/bin/codex-workspace --help` works (macOS validated; Ubuntu Server pending).
      - `codex-workspace up git@github.com:graysurf/codex-kit.git` creates a new workspace container and clones repo into `/work` (no host bind mount).
        - Evidence: `out/docker/verify/20260118_101201_workspace/workspace-launcher.log`
      - `codex-workspace tunnel <name> --detach` starts a VS Code tunnel for that workspace (first-run login flow documented).
        - Evidence: `out/docker/verify/20260118_101244_workspace_tunnel_wait/workspace-tunnel.log`
- [x] Step 3: Validation / testing
  - Work Items:
    - [ ] ~~Add a host-invoked smoke script (or documented one-liners) to validate the container toolchain.~~
      - Reason: Not needed for current usage; smoke one-liners + evidence already exist.
    - [x] Validate `codex-kit` checks inside the container (at minimum lint):
      - `scripts/check.sh --lint`
      - Evidence: `out/docker/verify/20260118_121526_check_lint/check-lint.log`
    - [x] Record evidence outputs under `out/docker/verify/` (tool versions, smoke logs).
      - Evidence: `out/docker/verify/20260118_084317/smoke.log`
      - Evidence: `out/docker/verify/20260118_084317/versions.txt`
    - [x] Validate runtime posture matches decisions (no extra hardening; read-write mounts by default).
      - Evidence: `docker-compose.yml`
    - [x] Validate the workspace launcher flow end-to-end on a clean host:
      - [x] Pull-only path (no local build): `docker pull graysurf/codex-env:linuxbrew`.
        - Evidence: `out/docker/verify/20260118_120610_pull_only/pull.log`
      - [x] Create workspace from SSH-style input: `codex-workspace up git@github.com:graysurf/codex-kit.git`.
        - Evidence: `out/docker/verify/20260118_101201_workspace/workspace-launcher.log`
      - [x] Confirm repo is in-container only:
        - Host has no new workspace folder created.
        - In container: repo exists under `/work/...` on a named volume.
        - Evidence: `out/docker/verify/20260118_101201_workspace/workspace-launcher.log`
      - [x] Start VS Code tunnel: `codex-workspace tunnel <name> --detach`.
        - Evidence: `out/docker/verify/20260118_101244_workspace_tunnel_wait/workspace-tunnel.log`
      - [x] Attach from macOS VS Code to the tunnel.
        - Evidence: `out/docker/verify/20260118_120500_vscode_tunnel_attach/tunnel-attach.md`
      - [ ] ~~Validate GH token behavior:~~
        - ~~With `GH_TOKEN` set → clone succeeds.~~
        - ~~Without token → fails with actionable error (or SSH fallback works if implemented).~~
        - Reason: Not needed for current usage; requires a private repo or controlled permission test.
      - [x] Validate concurrent workspaces:
        - Two different repos or two instances of same repo can run concurrently with isolated `HOME`/`CODEX_HOME` and `/work`.
        - Evidence: `out/docker/verify/20260118_120341_workspace_concurrency/concurrent-workspaces.log`
      - [x] Record evidence under `out/docker/verify/` and link it here.
        - Evidence: `out/docker/verify/20260118_101201_workspace/workspace-launcher.log`
        - Evidence: `out/docker/verify/20260118_101244_workspace_tunnel_wait/workspace-tunnel.log`
        - Evidence: `out/docker/verify/20260118_120500_vscode_tunnel_attach/tunnel-attach.md`
        - Evidence: `out/docker/verify/20260118_120610_pull_only/pull.log`
        - Evidence: `out/docker/verify/20260118_120341_workspace_concurrency/concurrent-workspaces.log`
  - Artifacts:
    - `out/docker/verify/<timestamp>/smoke.log`
    - `out/docker/verify/<timestamp>/versions.txt`
    - `out/docker/verify/<timestamp>/check-lint.log`
    - `out/docker/verify/<timestamp>/workspace-launcher.log`
  - Exit Criteria:
    - [x] Smoke and lint commands executed with results recorded under `out/docker/verify/`.
      - Evidence: `out/docker/verify/20260118_084317/smoke.log`
      - Evidence: `out/docker/verify/20260118_121526_check_lint/check-lint.log`
    - [x] Two concurrent environments verified:
      - `docker compose -f docker-compose.yml -p env-a up`
      - `docker compose -f docker-compose.yml -p env-b up`
      - state isolation validated via distinct volumes.
      - Evidence: `out/docker/verify/20260118_084317/multi-env.log`
    - [x] Evidence exists and is linked from docs (file paths under `out/`).
    - [x] Workspace launcher evidence exists and is linked from this progress doc (file paths under `out/`).
- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Update `README.md` entrypoints (link to Docker environment docs).
    - [x] Optional: add a small `CHANGELOG.md` entry (if this is treated as a user-facing feature).
    - [x] Set Status to `DONE`, archive progress file, and update index (close-progress-pr).
  - Artifacts:
    - `README.md` link(s)
    - Optional: `CHANGELOG.md` entry
    - Archived progress file under `docs/progress/archived/`
  - Exit Criteria:
    - [x] Documentation completed and entry points updated (README / docs index links).
    - [x] Cleanup completed (set Status to `DONE`; move to `archived/`; update index; patch PR Progress link).

## Modules

- `Dockerfile` + `docker-compose.yml`: root-level build/run assets for the Codex dev environment.
- `docker/codex-env`: helper scripts and runtime docs.
- `out/docker`: build/verify artifacts (logs, version snapshots, smoke outputs).
