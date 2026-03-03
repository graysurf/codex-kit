# CI check parity matrix (baseline)

## Scope

- Workflow sources:
  - `.github/workflows/lint.yml`
  - `.github/workflows/api-test-runner.yml`
- Local command sources:
  - `scripts/check.sh`
  - `scripts/lint.sh`
  - `scripts/test.sh`
  - `DEVELOPMENT.md`

## Matrix

| Workflow | CI step | Local command | Parity status | Notes |
| --- | --- | --- | --- | --- |
| `lint.yml` (`shell-and-contracts`) | Shell lint + syntax (bash + zsh) | `scripts/check.sh --lint` or `scripts/lint.sh --shell` | Partial | `scripts/check.sh --lint` also runs python lint; closest direct parity is `scripts/lint.sh --shell`. |
| `lint.yml` (`shell-and-contracts`) | Markdown lint | `scripts/check.sh --markdown` or `scripts/ci/markdownlint-audit.sh --strict` | Full | Same strict markdown audit entrypoint. |
| `lint.yml` (`shell-and-contracts`) | Third-party artifacts audit | `scripts/check.sh --third-party` or `scripts/ci/third-party-artifacts-audit.sh --strict` | Full | Same strict third-party audit script. |
| `lint.yml` (`shell-and-contracts`) | Env bool audit | `scripts/check.sh --env-bools` or `zsh -f scripts/audit-env-bools.zsh --check` | Full | Local and CI both call same zsh audit mode. |
| `lint.yml` (`shell-and-contracts`) | Validate skill contract sections | `scripts/check.sh --contracts` or `skills/tools/skill-management/skill-governance/scripts/validate_skill_contracts.sh` | Full | Same script and flags. |
| `lint.yml` (`shell-and-contracts`) | Validate skill directory layout | `scripts/check.sh --skills-layout` or `skills/tools/skill-management/skill-governance/scripts/audit-skill-layout.sh` | Full | Same script and flags. |
| `lint.yml` (`shell-and-contracts`) | Smoke test (negative fixture) | None | Missing | CI-only negative fixture for contract validator failure path. |
| `lint.yml` (`pytest`) | Python lint + typecheck (ruff + mypy + pyright) | `scripts/check.sh --lint` or `scripts/lint.sh --python` | Full | `scripts/lint.sh --python` is direct parity. |
| `lint.yml` (`pytest`) | Pytest | `scripts/check.sh --tests` or `scripts/test.sh` | Full | Same script entrypoint. |
| `lint.yml` (`pytest`) | Script coverage summary + artifact upload | None | Missing | CI summary/upload behavior has no local wrapper command. |
| `api-test-runner.yml` (all jobs) | Install Homebrew + nils-cli | `scripts/install-homebrew-nils-cli.sh` | Full | API workflow already uses shared bootstrap script. |
| `api-test-runner.yml` (all jobs) | Install jq | None | Missing | CI-local package setup is inline only; no common local wrapper. |
| `api-test-runner.yml` (`smoke-local-rest-graphql`) | Bootstrap public suite (`setup/`) | Manual sequence from workflow | Partial | Command exists inline in workflow; no checked-in local helper script. |
| `api-test-runner.yml` (`smoke-local-rest-graphql`) | Run suite (`api-test run --suite smoke-demo`) | Manual `api-test run` invocation | Partial | Tool available via `nils-cli`, but no canonical local shortcut in `scripts/check.sh`. |
| `api-test-runner.yml` (`cleanup-fixture-rest-graphql`) | Run cleanup fixture suite | Manual `api-test run --suite-file ...cleanup.suite.json` | Partial | Repeatable command, but no consolidated local wrapper. |
| `api-test-runner.yml` (`public-auth-rest-graphql-demo`) | Run expected-fail public auth demo | Manual `api-test run --suite public-auth-demo` | Partial | No `scripts/check.sh` mode for this suite. |
| `api-test-runner.yml` (`auth-secrets-rest-graphql`) | Secret-gated auth suite | Manual `API_TEST_AUTH_JSON=... api-test run --suite auth-secrets-demo` | Partial | Requires secret env and suite bootstrap outside `scripts/check.sh`. |
| `api-test-runner.yml` (all jobs) | Summarize results + upload artifacts | Manual `api-test summary` + local files in `out/api-test-runner/` | Partial | Summary command exists; upload semantics are CI-only. |

## Duplicate setup/check logic

1. Homebrew + `nils-cli` bootstrap is duplicated inline in `lint.yml` (two jobs) but script-backed in `api-test-runner.yml`.
2. `jq` installation is duplicated inline in every API workflow job.
3. Public suite bootstrap (`rm -rf setup` + scaffold copy) is duplicated in three API workflow jobs.
4. Local fixture server startup + health-check loop pattern appears in multiple API jobs.
5. Result summarize/upload scaffolding repeats with small path/name differences across API jobs and lint pytest artifacts.

## Missing parity points

1. `scripts/check.sh` does not currently expose API suite coverage (`smoke`, `cleanup`, `public-auth-demo`, `auth-secrets-demo`).
2. CI has a negative-fixture contract smoke test; no direct local command in `scripts/check.sh`.
3. CI artifact publication and step-summary generation are not modeled in local check wrappers.
4. Local `scripts/check.sh --plans` and `scripts/check.sh --semgrep` are not represented in current CI workflows.
5. Lint workflow still uses inline Homebrew bootstrap while API workflow uses `scripts/install-homebrew-nils-cli.sh`, creating bootstrap drift.
