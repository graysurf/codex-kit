# CI bootstrap consolidation design

## Goal

Define one bootstrap pattern for Homebrew + `nils-cli` installation across CI workflows so setup behavior, retries, and PATH export remain
consistent.

## Current state summary

- `.github/workflows/lint.yml` uses duplicated inline shell blocks for Homebrew + `nils-cli`.
- `.github/workflows/api-test-runner.yml` already calls `scripts/install-homebrew-nils-cli.sh`.
- `scripts/install-homebrew-nils-cli.sh` already contains retry logic, brew-path resolution, PATH export, and idempotent `nils-cli` handling.

## Canonical bootstrap

- Canonical bootstrap entrypoint: `scripts/install-homebrew-nils-cli.sh`.
- Required usage rule: every workflow job needing `nils-cli` invokes the script directly instead of inline install logic.
- Script contract to preserve:
  - Installs Homebrew only when missing.
  - Resolves brew binary from known macOS/Linux locations.
  - Exports brew `bin`/`sbin` into process `PATH` and `$GITHUB_PATH`.
  - Uses retry wrappers for brew install/tap/install operations.
  - Exits successfully when `nils-cli` is already installed.

## Fallback

- Fallback tier 1: rerun `scripts/install-homebrew-nils-cli.sh` once in the same job (transient network/package index failures).
- Fallback tier 2: if script behavior needs emergency divergence, copy the current script logic verbatim into a temporary workflow step with a
  tracked follow-up task to remove it after script fix.
- Fallback tier 3: fail fast with explicit error output when brew cannot be resolved after install attempts; do not proceed with partial tool
  setup.

## Migration order

1. Lock baseline inventory (`ci-parity-matrix.md`) so parity deltas are measurable.
2. Keep `scripts/install-homebrew-nils-cli.sh` as the single supported bootstrap implementation (all fixes land there first).
3. Migrate `lint.yml` `shell-and-contracts` job from inline bootstrap to `scripts/install-homebrew-nils-cli.sh`.
4. Migrate `lint.yml` `pytest` job from inline bootstrap to `scripts/install-homebrew-nils-cli.sh`.
5. Verify both workflows still pass with identical bootstrap behavior on Ubuntu and macOS.
6. Add CI guardrails to detect reintroduction of inline Homebrew + `nils-cli` install snippets in workflow YAML.
7. After guardrails are active, remove any temporary fallback inline blocks created during migration.

## Non-goals for Sprint 1

- No functional workflow behavior changes beyond documenting target pattern and rollout order.
- No expansion into unrelated dependency installation (`jq`, ImageMagick, etc.) until bootstrap unification is complete.
