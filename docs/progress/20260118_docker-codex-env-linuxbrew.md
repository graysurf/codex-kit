# codex-kit: Docker Codex env (Linuxbrew)

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-18 | 2026-01-18 |

Links:

- PR (planning): https://github.com/graysurf/codex-kit/pull/58
- PR (implementation): https://github.com/graysurf/codex-kit/pull/59
- Docs (implementation): https://github.com/graysurf/codex-kit/blob/feat/docker-codex-env/docker/codex-env/README.md
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

- None

## Goal

- Provide a Docker-based Codex work environment that mirrors the macOS setup as closely as practical (Linux container + zsh).
- Install CLI tooling via Linuxbrew from `zsh-kit` tool lists, with explicit apt fallbacks/removals when Linuxbrew lacks a package.
- Support running multiple isolated environments concurrently (separate `HOME`/`CODEX_HOME` state per environment).
- Keep secrets and mutable state out of the image (inject via volumes/env at runtime).

## Acceptance Criteria

- `docker build` succeeds on macOS (Docker Desktop) for the primary target architecture.
- In the container, `zsh -lic 'echo ok'` succeeds (no startup errors) and the required tool executables are on `PATH`.
- All required tools from `/Users/terry/.config/zsh/config/tools.list` are installed via Linuxbrew (or documented apt fallback/removal), and a smoke command verifies them.
- Optional tools from `/Users/terry/.config/zsh/config/tools.optional.list` are installed by default (or documented apt fallback/removal), with an explicit opt-out for faster builds if needed.
- Two environments can run concurrently and do not share mutable state (verify via distinct named volumes for `HOME` and `CODEX_HOME`).
- Codex CLI is runnable in-container (`codex --version`), with auth/state stored outside the image (volume or env-based).

## Scope

- In-scope:
  - Add Docker assets (Dockerfile + compose/run docs) to `codex-kit` for an Option A (Linuxbrew) dev environment.
  - Use `zsh-kit` tool lists as the source of truth for Linuxbrew-installed CLI tools.
  - Provide a clear fallback policy for missing Linuxbrew packages (apt replacement or explicit removal with documented deviation).
  - Provide an explicit multi-environment run workflow (multiple concurrent containers, each with isolated volumes/state).
  - Provide smoke verification commands/scripts to prove the environment matches the declared DoD.
- Out-of-scope:
  - macOS containers / full macOS kernel parity (Docker Desktop runs Linux containers).
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
  - `docker/codex-env/Dockerfile`
  - `docker/codex-env/compose.yml` (or `docker-compose.yml` at repo root)
  - `docker/codex-env/README.md` (TL;DR usage + knobs)
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

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).
Note: For intentionally deferred / not-do items in Step 0–3, close-progress-pr will auto-wrap the item text with Markdown strikethrough (use `- [ ] ~~like this~~`).

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [ ] Confirm target runtime: Docker Desktop on macOS (Linux containers), primary host arch and any secondary arch requirements.
    - [ ] Decide repository layout for Docker assets (recommend `docker/codex-env/`): file paths, naming, and entrypoints.
    - [x] Confirm tool-install policy:
      - Required install set (brew) = `/Users/terry/.config/zsh/config/tools.list` (+ OS-specific required lists if present)
      - Optional install set (brew) = `/Users/terry/.config/zsh/config/tools.optional.list` (+ OS-specific optional lists if present)
      - Linux apt-only additions (optional) = `tools.linux.apt.list` / `tools.optional.linux.apt.list` (if present)
      - Default behavior: install required + optional (opt-out only).
    - [x] Decide how to source `zsh-kit` and `codex-kit` inside the container:
      - Clone during image build (self-contained, pinned revision/ref).
    - [x] Decide install fallback order (per tool): Linuxbrew > apt > release binary.
    - [ ] Decide `CODEX_HOME` strategy:
      - Path inside container (e.g. `/home/dev/.codex`)
      - One named volume per environment vs shared volume (trade-off: isolation vs reuse of auth)
    - [x] Validate and record the Linux install method for key tools that may not exist on Linuxbrew (follow the fallback order):
      - `codex`: Linuxbrew cask works on `linux/arm64` (no fallback needed).
      - `opencode`: Linuxbrew formula works on `linux/arm64`.
      - `gemini-cli`: Linuxbrew formula works on `linux/arm64` (installs `gemini`).
      - `code`/VS Code: Linuxbrew cask is macOS-only; fallback to Microsoft apt repo.
      - `psql`: Homebrew `libpq` works on `linux/arm64` (keg-only).
      - `mysql`: Homebrew `mysql-client` works on `linux/arm64` (keg-only).
      - `sqlcmd`: Homebrew `sqlcmd` works on `linux/arm64`.
    - [ ] Define security baseline for runtime:
      - non-root default user
      - `no-new-privileges`
      - `cap_drop: [ALL]`
      - read-only bind mounts where feasible (`zsh-kit` config)
    - [ ] Define the minimum smoke verification commands and expected outputs.
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - `docs/progress/README.md` entry (In progress table)
    - `docker/codex-env/README.md` (planned) describing decisions and usage
    - Implementation PR: https://github.com/graysurf/codex-kit/pull/59
  - Exit Criteria:
    - [ ] Requirements, scope, and acceptance criteria are aligned: reviewed in this progress doc.
    - [ ] Data flow and I/O contract are defined: container inputs/outputs/volumes/build args documented here.
    - [ ] Risks and mitigation plan are defined: captured above, with explicit “what to do when brew fails” policy.
    - [ ] Minimal reproducible verification commands are defined: see Step 1/3 exit criteria.
- [ ] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [ ] Add `docker/codex-env/Dockerfile` (Ubuntu base + apt bootstrap).
    - [ ] Create a non-root user (e.g. `dev`) and ensure the default shell is `zsh`.
    - [ ] Install Linuxbrew (non-root) and ensure brew is on `PATH` for login shells.
    - [ ] Install required + optional CLI tools from `tools.list` and `tools.optional.list` by default.
      - Preferred: reuse `zsh-kit` installer logic (clone `zsh-kit`, run its installer in a non-interactive mode).
      - Ensure Docker build does not hang on confirmation prompts (add a non-interactive path if needed).
    - [ ] Add minimal runtime wiring:
      - `WORKDIR` default (e.g. `/work`)
      - container starts into `zsh -l` (or a small entrypoint that execs it)
    - [ ] Add `docker/codex-env/compose.yml` with:
      - bind mount workspace(s)
      - named volume(s) for `HOME` and `CODEX_HOME`
      - security hardening defaults (`cap_drop`, `no-new-privileges`)
    - [ ] Install Codex CLI in the container (exact mechanism TBD in Step 0) and validate it starts.
    - [ ] Create a minimal `docker/codex-env/README.md` with TL;DR commands.
  - Artifacts:
    - `docker/codex-env/Dockerfile`
    - `docker/codex-env/compose.yml`
    - `docker/codex-env/README.md`
  - Exit Criteria:
    - [ ] Image builds: `docker build -f docker/codex-env/Dockerfile -t codex-env:linuxbrew .`
    - [ ] Interactive shell works: `docker run --rm -it codex-env:linuxbrew zsh -l`
    - [ ] Tools on PATH (example smoke): `zsh -lic 'rg --version && fd --version && fzf --version && gh --version && jq --version'`
    - [ ] `codex --version` works in-container (auth may still be TBD if using per-env volumes).
    - [ ] Docs include the exact build/run commands and required mounts.
- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Add explicit opt-out for optional tools (default is required + optional):
      - Build arg `INSTALL_OPTIONAL_TOOLS=0` (or equivalent) OR separate minimal Docker target/tag.
      - Optional: split `tools.optional.list` into “default” vs “heavy/debug-only” groups at install time (if build time becomes a bottleneck).
    - [ ] Define/implement a fallback policy for missing Linuxbrew formulas:
      - Maintain an explicit `apt` fallback list, OR
      - Maintain an explicit “removed on Linux” list with documented deviations.
    - [ ] Add compatibility shims when required (only when proven necessary by smoke tests):
      - Example: provide `gdate`/`gseq` aliases or symlinks if scripts assume macOS GNU coreutils naming.
    - [ ] Add a “local bind-mount mode” for `zsh-kit` and/or `codex-kit` (read-only mounts) for fast iteration.
    - [ ] Improve build speed via BuildKit caching for brew downloads/builds (optional, but recommended).
  - Artifacts:
    - `docker/codex-env/README.md` updates (document knobs, fallback policy, and known deltas vs macOS)
    - `docker/codex-env/apt-fallback.txt` (or equivalent mapping file)
    - Optional: `docker/codex-env/shims/` (only if needed)
  - Exit Criteria:
    - [ ] Optional opt-out path works and is documented (commands + expected results).
    - [ ] Missing-formula handling is explicit and reproducible (no “mystery failures” during build).
    - [ ] Multi-env workflow is documented and proven with two concurrent compose projects.
- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Add a host-invoked smoke script (or documented one-liners) to validate the container toolchain.
    - [ ] Validate `codex-kit` checks inside the container (at minimum lint):
      - `scripts/check.sh --lint`
    - [ ] Record evidence outputs under `out/docker/verify/` (tool versions, smoke logs).
    - [ ] Validate security posture:
      - default user is non-root
      - compose includes `cap_drop: [ALL]` and `no-new-privileges`
      - mounts are least-privilege (read-only where possible)
  - Artifacts:
    - `out/docker/verify/<timestamp>/smoke.log`
    - `out/docker/verify/<timestamp>/versions.txt`
    - `out/docker/verify/<timestamp>/check-lint.log`
  - Exit Criteria:
    - [ ] Smoke and lint commands executed with results recorded under `out/docker/verify/`.
    - [ ] Two concurrent environments verified:
      - `docker compose -f docker/codex-env/compose.yml -p env-a up`
      - `docker compose -f docker/codex-env/compose.yml -p env-b up`
      - state isolation validated via distinct volumes.
    - [ ] Evidence exists and is linked from docs (file paths under `out/`).
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Update `README.md` entrypoints (link to Docker environment docs).
    - [ ] Optional: add a small `CHANGELOG.md` entry (if this is treated as a user-facing feature).
    - [ ] Mark progress file status to `DONE` when implementation PR(s) are complete.
  - Artifacts:
    - `README.md` link(s)
    - Optional: `CHANGELOG.md` entry
  - Exit Criteria:
    - [ ] Documentation completed and entry points updated (README / docs index links).
    - [ ] Cleanup completed (close issues, remove temporary flags/files, set status to DONE).

## Modules

- `docker/codex-env`: Dockerfile + compose + runtime docs for the Codex dev environment.
- `out/docker`: build/verify artifacts (logs, version snapshots, smoke outputs).
