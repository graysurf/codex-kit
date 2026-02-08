# CLI Tools (Cross-Project)

This document is a cross-project reference for CLI tools commonly available in the Codex runtime and recommended usage patterns for development, testing, and documentation work.
Principle: prefer purpose-built tools that are fast, repo-aware, and emit structured output; avoid ad-hoc pipelines that are slow or fragile.

## Recommended defaults

- Repo-wide search: `rg` (optionally pipe candidates into `fzf`)
- Find files: `fd` (use `tree`/`eza` for human-readable structure listings)
- Read files: `bat`; preview Markdown: `glow`
- Review diffs: `delta` (with `git`)
- API exploration: `xh`/`httpie` + `jq`; use `curl` for minimal-dependency calls
- Structured config/data: `yq`/`jq` (avoid regex parsing for YAML/JSON)

---

## Categories

- Search: code/config/docs discovery (`rg`, `fd`, `fzf`, `tree`)
- Docs: reading files + Markdown/diffs (`bat`, `glow`, `delta`)
- VCS: version control + PR workflows (`git`, `gh`, `gitui`)
- API: HTTP/API + structured data (`xh`/`httpie`, `jq`, `yq`)
- Test: test iteration + feedback loops (`watchexec`, `ruff`)
- Toolchain: runtimes + CLI installation (`node`, `pnpm`, `pipx`, `direnv`)
- macOS Automation: UI/input-source automation (`hs`, `im-select`)
- Media: image processing (`imagemagick`, `vips`)
- Ops: logs + system triage (`lnav`, `btop`, `ncdu`)
- Defaults: recommended default picks

---

## Search and discovery (code / config / docs)

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `rg` (ripgrep) | Fast repo-wide text search | Finding symbols, TODOs, config keys, and error messages across a repository | `grep -R` / `find ... -exec grep` (slower, noisier ignore handling) |
| `fd` | Fast file/path finder | Narrowing candidate files quickly before searching contents with `rg` | `find` (verbose syntax, platform differences) |
| `fzf` | Interactive fuzzy picker | Selecting a file/command/branch/commit from a large set | Manually scrolling long `ls`/`git` output |
| `tree` | Directory structure view | Getting a quick repo layout overview; sharing structure in PRs/issues | Manually assembling structure from multiple `ls` outputs |
| `eza` | Human-friendly `ls` replacement | Inspecting directories with readable metadata | `ls -R` (too much output, low scanability) |
| `ripgrep-all` (`rga`) | Search inside PDFs/DOCX/EPUB/archives | Searching specs/attachments/exported reports that are not plain text | Opening each document manually to search |
| `ast-grep` (`sg`) | AST-based structural search/replace | Large-scale refactors (renames, API migrations) with fewer false positives | Regex-only mass replace (easy to miss and easy to break) |

---

## Reading files and authoring docs (Markdown / diffs)

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `bat` | Read files with syntax highlighting and line numbers | Inspecting code/config/docs snippets with good locality | `cat` (no line numbers/highlight; harder to reference) |
| `bat-extras` (e.g. `batgrep`, `batdiff`, `batman`) | `bat`-style UX for common utilities | Wanting consistent highlighted output for grep/diff/man flows | Mixed pagers/color setups that produce inconsistent output |
| `glow` | Render Markdown in the terminal | Reviewing/editing `README.md` or `docs/*.md` quickly | Context-switching to browser/editor previews for small changes |
| `delta` | Readable diff pager | Reviewing `git diff`/`git show`; sharing diffs in discussions | Raw diff dumps that are hard to scan |
| `repomix` | Bundle a repo into an AI/review-friendly single file | Preparing a reproducible “repo context” artifact for review/tools | Manual copy/paste of many files (easy to miss, not reproducible) |

---

## Version control and PR workflows (Git / GitHub)

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `git` | Core version control | Branching, diffs, rebases, history, bisect | Editing `.git/` by hand or doing risky GUI-only workflows |
| `gh` | GitHub CLI | Creating/reviewing PRs, checking CI, fetching PR metadata | Repetitive manual web UI steps that drift from templates |
| `gitui` | Git TUI | Safely staging partial changes and inspecting status/diffs interactively | Blind staging and accidental over-inclusion of changes |

---

## HTTP / API testing and structured data processing

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `curl` | Low-level HTTP client | Minimal-dependency requests, downloads, simple health checks | Writing one-off scripts/programs just to make a request |
| `httpie` | Human-friendly HTTP client | Exploring APIs interactively and composing requests quickly | Long, brittle `curl` invocations with quoting issues |
| `xh` | Fast `httpie`-like client | Same workflows as `httpie`, but faster and consistent | Building a custom HTTP wrapper for convenience |
| `jq` | JSON processor | Filtering/formatting API responses; lightweight assertions | Parsing JSON with `grep`/`sed`/`awk` (fragile) |
| `yq` | YAML/JSON/XML/CSV processor | Editing CI/config files and structured data safely | Hand-editing structured documents (indentation/type mistakes) |
| `grpcurl` | gRPC CLI client | Probing methods and sending gRPC requests without writing code | Building a temporary gRPC client app |
| `websocat` | WebSocket client | Testing WS message streams; sending/receiving payloads | Writing a temporary WS program or relying on browser tooling |
| `mitmproxy` | HTTP(S) intercept/inspection | Debugging unclear client behavior by observing real traffic | Guessing based on partial server logs |
| `hey` | HTTP load generator | Quick throughput/latency smoke checks (not full benchmarking) | Drawing conclusions from a few manual requests |

---

## Test iteration and feedback loops

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `watchexec` | Re-run tasks on file changes (gitignore-aware) | Auto-running `pytest`/`pnpm test`/lint during edits | Manually re-running tests and forgetting to validate changes |
| `entr` | Minimal file watcher | Simple “file changed -> re-run step” workflows | Home-grown polling loops |
| `ruff` | Fast Python linter/formatter | Formatting and linting Python codebases quickly | Slow multi-tool lint chains with overlapping responsibilities |
| `ipython` | Enhanced Python REPL | Reproducing/debugging small logic quickly | Editing files + re-running full suites for tiny experiments |
| `hyperfine` | Benchmark invocations | Comparing alternative invocations/build steps reliably | Using a single run as a performance conclusion (high variance) |

---

## Dev toolchains and CLI installation

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `node` | Node.js runtime | Running JS/TS tools, scripts, and tests | Relying on outdated/system Node versions with drift |
| `pnpm` | Fast, reproducible package manager | Installing dependencies and running Node project scripts | `npm install` drift and slower installs |
| `pipx` | Install Python CLIs in isolated envs | Installing Python CLI tools without polluting global site-packages | `pip install --user` (global conflicts and upgrades pain) |
| `direnv` | Per-directory environment loading | Auto-loading `.envrc` per project | Manual `export` workflows and cross-project env leaks |

---

## macOS UI automation and input source

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `hs` (Hammerspoon CLI) | Scriptable macOS UI automation backend | AX-based app/window/node automation and richer UI interaction flows | AppleScript-only fallbacks for complex AX flows |
| `im-select` | Input source query/switch helper | Enforcing deterministic keyboard input source before typing automation | Clicking input menu UI manually (fragile and environment-dependent) |

---

## Image processing (conversion / resize / compression)

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `imagemagick` | General-purpose image conversion + resize | Resizing and converting common formats | Writing one-off scripts for basic transforms |
| `vips` | High-performance image processing | Batch resizing and fast pipelines | Slower tools on large batches |
| `pngquant` | PNG lossy compression | Reducing PNG size with acceptable quality | Manual PNG optimization guesses |
| `jpegoptim` | JPEG optimizer | Compressing JPGs with CLI controls | Re-encoding images in GUI editors |
| `mozjpeg` | High-quality JPEG encoder | Better visual quality at smaller sizes | Default JPEG encoders with worse quality/size |
| `webp` | WebP encoder/decoder (`cwebp`) | Converting JPG/PNG to WebP | Ad-hoc WebP conversions |

---

## Logs and system triage (as needed)

| Tool | Purpose | Use when | Avoid because this exists |
| --- | --- | --- | --- |
| `lnav` | Log navigator (TUI) | Investigating test/service logs with filtering/search | `tail -f` only (hard to filter and backtrack) |
| `tailspin` | Highlighted log viewer | Scanning noisy logs for patterns quickly | Plain output scanning with no structure/highlighting |
| `tokei` | Code statistics by language | Estimating repo size/scope and change surface area | Guessing scope without measurements |
| `btop` / `htop` | Process/resource monitors | Diagnosing slow builds/tests (CPU/mem pressure) | Tuning blindly without observing resource usage |
| `ncdu` | Disk usage analyzer | Finding large directories, caches, and unexpected growth | Manual `du` drilling through many levels |
