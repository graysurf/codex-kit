#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate-third-party-artifacts.sh --write
  scripts/generate-third-party-artifacts.sh --check

Generates deterministic third-party compliance artifacts:
  - THIRD_PARTY_LICENSES.md
  - THIRD_PARTY_NOTICES.md

Options:
  --write     Regenerate and write both artifacts to the repository root.
  --check     Regenerate into a temp directory and fail if tracked artifacts differ.
  -h, --help  Show this help.
USAGE
}

mode=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --write)
      if [[ -n "$mode" ]]; then
        echo "error: choose exactly one mode (--write or --check)" >&2
        exit 2
      fi
      mode="write"
      shift
      ;;
    --check)
      if [[ -n "$mode" ]]; then
        echo "error: choose exactly one mode (--write or --check)" >&2
        exit 2
      fi
      mode="check"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${1:-}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$mode" ]]; then
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

licenses_output_file="$repo_root/THIRD_PARTY_LICENSES.md"
notices_output_file="$repo_root/THIRD_PARTY_NOTICES.md"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/third-party-artifacts.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

generated_licenses_file="$tmp_root/THIRD_PARTY_LICENSES.md"
generated_notices_file="$tmp_root/THIRD_PARTY_NOTICES.md"

python3 - "$repo_root" "$generated_licenses_file" "$generated_notices_file" <<'PY'
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
licenses_out = Path(sys.argv[2])
notices_out = Path(sys.argv[3])


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_requirements(path: Path) -> list[str]:
    specs: list[str] = []
    for raw in path.read_text("utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            specs.append(line)
    return specs


def parse_requirement_name(spec: str) -> str:
    match = re.match(r"^([A-Za-z0-9_.-]+)", spec)
    if not match:
        raise SystemExit(f"invalid requirement spec: {spec}")
    return match.group(1).lower().replace("_", "-")


def version_policy_from_requirement(spec: str) -> str:
    if "==" in spec:
        version = spec.split("==", 1)[1].strip()
        return f"pinned ({version})"
    return f"floating ({spec})"


def version_policy_from_npm(spec: str) -> str:
    _, version = spec.rsplit("@", 1)
    if version == "latest":
        return "floating (@latest)"
    return f"pinned ({version})"


def extract_once(path: Path, pattern: str, label: str) -> str:
    text = path.read_text("utf-8")
    match = re.search(pattern, text)
    if not match:
        raise SystemExit(f"failed to extract {label} from {path}")
    return match.group(1)


def upstream_label(url: str) -> str:
    parts = [part for part in url.rstrip("/").split("/") if part]
    if len(parts) >= 2:
        return f"{parts[-2]}/{parts[-1]}"
    return url


requirements_path = repo_root / "requirements-dev.txt"
rumdl_config = repo_root / ".rumdl.toml"
markdown_script = repo_root / "scripts" / "ci" / "markdownlint-audit.sh"
playwright_script = repo_root / "skills" / "tools" / "browser" / "playwright" / "scripts" / "playwright_cli.sh"
agent_browser_script = repo_root / "skills" / "tools" / "browser" / "agent-browser" / "scripts" / "agent-browser.sh"
chrome_devtools_script = repo_root / "scripts" / "chrome-devtools-mcp.sh"
lint_script = repo_root / "scripts" / "lint.sh"
install_script = repo_root / "scripts" / "install-homebrew-nils-cli.sh"
workflow_lint = repo_root / ".github" / "workflows" / "lint.yml"
dockerfile = repo_root / "Dockerfile"

required_inputs = [
    requirements_path,
    rumdl_config,
    markdown_script,
    playwright_script,
    agent_browser_script,
    chrome_devtools_script,
    lint_script,
    install_script,
    workflow_lint,
    dockerfile,
]
for required in required_inputs:
    if not required.is_file():
        raise SystemExit(f"missing required input file: {required}")

python_meta = {
    "pytest": {
        "component": "pytest",
        "ecosystem": "PyPI",
        "license": "MIT",
        "upstream": "https://github.com/pytest-dev/pytest",
    },
    "semgrep": {
        "component": "semgrep",
        "ecosystem": "PyPI",
        "license": "LGPL-2.1-or-later",
        "upstream": "https://github.com/semgrep/semgrep",
    },
    "mypy": {
        "component": "mypy",
        "ecosystem": "PyPI",
        "license": "MIT",
        "upstream": "https://github.com/python/mypy",
    },
    "ruff": {
        "component": "ruff",
        "ecosystem": "PyPI",
        "license": "MIT",
        "upstream": "https://github.com/astral-sh/ruff",
    },
    "pyright": {
        "component": "pyright (Python wrapper)",
        "ecosystem": "PyPI",
        "license": "MIT",
        "upstream": "https://github.com/RobertCraigie/pyright-python",
    },
}

npm_meta = {
    "@playwright/cli": {
        "component": "@playwright/cli",
        "ecosystem": "npm via npx --package",
        "license": "Apache-2.0",
        "upstream": "https://github.com/microsoft/playwright-cli",
    },
    "agent-browser": {
        "component": "agent-browser",
        "ecosystem": "npm via npx --package",
        "license": "Apache-2.0",
        "upstream": "https://github.com/vercel-labs/agent-browser",
    },
    "chrome-devtools-mcp": {
        "component": "chrome-devtools-mcp",
        "ecosystem": "npm via npx",
        "license": "Unknown (check npm package metadata)",
        "upstream": "https://github.com/ChromeDevTools/chrome-devtools-mcp",
    },
    "rumdl": {
        "component": "rumdl",
        "ecosystem": "npm via npx",
        "license": "MIT",
        "upstream": "https://github.com/rvben/rumdl",
    },
}

rows: list[dict[str, str]] = []

requirement_specs = parse_requirements(requirements_path)
for requirement_spec in requirement_specs:
    requirement_name = parse_requirement_name(requirement_spec)
    metadata = python_meta.get(requirement_name)
    if metadata is None:
        raise SystemExit(
            "unmapped Python requirement in requirements-dev.txt: "
            f"{requirement_spec} (name={requirement_name})"
        )

    rows.append(
        {
            "component": metadata["component"],
            "ecosystem": metadata["ecosystem"],
            "declared_spec": requirement_spec,
            "version_policy": version_policy_from_requirement(requirement_spec),
            "license": metadata["license"],
            "upstream": metadata["upstream"],
            "source": "requirements-dev.txt",
        }
    )

playwright_spec = extract_once(
    playwright_script,
    r"--package\s+(@playwright/cli@[^\s\)\"]+)",
    "@playwright/cli spec",
)
agent_browser_spec = extract_once(
    agent_browser_script,
    r"--package\s+(agent-browser@[^\s\)\"]+)",
    "agent-browser spec",
)
chrome_devtools_spec = extract_once(
    chrome_devtools_script,
    r"cmd=\(npx -y (chrome-devtools-mcp@[^\s\)]+)\)",
    "chrome-devtools-mcp spec",
)
rumdl_spec = extract_once(
    markdown_script,
    r"npx --yes (rumdl@[0-9A-Za-z._-]+)\s+check",
    "rumdl spec",
)

npm_specs = [
    ("@playwright/cli", playwright_spec, "skills/tools/browser/playwright/scripts/playwright_cli.sh"),
    ("agent-browser", agent_browser_spec, "skills/tools/browser/agent-browser/scripts/agent-browser.sh"),
    ("chrome-devtools-mcp", chrome_devtools_spec, "scripts/chrome-devtools-mcp.sh"),
    ("rumdl", rumdl_spec, "scripts/ci/markdownlint-audit.sh"),
]

for package_name, package_spec, source in npm_specs:
    metadata = npm_meta[package_name]
    rows.append(
        {
            "component": metadata["component"],
            "ecosystem": metadata["ecosystem"],
            "declared_spec": package_spec,
            "version_policy": version_policy_from_npm(package_spec),
            "license": metadata["license"],
            "upstream": metadata["upstream"],
            "source": source,
        }
    )

rows.append(
    {
        "component": "shellcheck",
        "ecosystem": "Homebrew / apt",
        "declared_spec": "brew install shellcheck / apt-get install -y shellcheck",
        "version_policy": "floating (package-manager resolved)",
        "license": "GPL-3.0-or-later",
        "upstream": "https://github.com/koalaman/shellcheck",
        "source": "scripts/lint.sh, .github/workflows/lint.yml",
    }
)

rows.append(
    {
        "component": "nils-cli",
        "ecosystem": "Homebrew formula",
        "declared_spec": "brew install nils-cli",
        "version_policy": "floating (formula latest)",
        "license": "MIT OR Apache-2.0",
        "upstream": "https://github.com/graysurf/nils-cli",
        "source": "scripts/install-homebrew-nils-cli.sh, .github/workflows/lint.yml, Dockerfile",
    }
)

source_paths = [
    "requirements-dev.txt",
    ".rumdl.toml",
    "scripts/ci/markdownlint-audit.sh",
    "skills/tools/browser/playwright/scripts/playwright_cli.sh",
    "skills/tools/browser/agent-browser/scripts/agent-browser.sh",
    "scripts/chrome-devtools-mcp.sh",
    "scripts/lint.sh",
    ".github/workflows/lint.yml",
    "scripts/install-homebrew-nils-cli.sh",
    "Dockerfile",
]

licenses_lines: list[str] = [
    "# THIRD_PARTY_LICENSES",
    "",
    "This file is generated by `scripts/generate-third-party-artifacts.sh`.",
    "",
    "## Scope",
    "",
    "This file lists third-party components directly referenced by this repository for local development and runtime tooling.",
    "",
    "Included:",
    "",
    "- Python dependencies declared in `requirements-dev.txt`.",
    "- npm packages invoked via `npx` from repository scripts.",
    "- Required tooling explicitly installed by repo checks/CI (`shellcheck`, `nils-cli`).",
    "",
    "Not included:",
    "",
    "- Full transitive dependency trees of package managers.",
    "- Baseline host tools not installed by this repository (for example `git`, `zsh`, `node`).",
    "",
    "## Version Policy",
    "",
    "- `pinned`: spec resolves to a fixed version in repo-owned declarations.",
    "- `floating`: spec intentionally tracks non-fixed versions (for example `>=` ranges, `@latest`, formula latest).",
    "",
    "## Third-Party Components",
    "",
    "| Component | Ecosystem | Declared spec in repo | Version policy | License | Upstream |",
    "| --- | --- | --- | --- | --- | --- |",
]

for row in rows:
    licenses_lines.append(
        "| "
        f"`{row['component']}` | "
        f"{row['ecosystem']} | "
        f"`{row['declared_spec']}` | "
        f"{row['version_policy']} | "
        f"`{row['license']}` | "
        f"[{upstream_label(row['upstream'])}]({row['upstream']}) |"
    )

licenses_lines.extend(
    [
        "",
        "## Declaration Sources",
        "",
    ]
)
for source_path in source_paths:
    licenses_lines.append(f"- `{source_path}`")

licenses_lines.extend(
    [
        "",
        "## Deterministic Input Fingerprints",
        "",
    ]
)
for input_path in source_paths:
    abs_path = repo_root / input_path
    licenses_lines.append(f"- `{input_path}` SHA256: `{sha256(abs_path)}`")

licenses_lines.append("")

notices_lines: list[str] = [
    "# THIRD_PARTY_NOTICES",
    "",
    "This file is generated by `scripts/generate-third-party-artifacts.sh`.",
    "",
    "## Notice Handling Policy",
    "",
    "This repository does not vendor third-party packages directly.",
    "Third-party notice obligations are tracked by linking each component to its upstream project.",
    "",
    "## Component Notice References",
    "",
    "| Component | Notice handling | Upstream reference |",
    "| --- | --- | --- |",
]

notice_handling = (
    "Use upstream license/notice files from the linked project. "
    "No separate vendored NOTICE file is distributed in this repository."
)
for row in rows:
    notices_lines.append(
        "| "
        f"`{row['component']}` | "
        f"{notice_handling} | "
        f"[{upstream_label(row['upstream'])}]({row['upstream']}) |"
    )

notices_lines.extend(
    [
        "",
        "## Deterministic Input Fingerprints",
        "",
    ]
)
for input_path in source_paths:
    abs_path = repo_root / input_path
    notices_lines.append(f"- `{input_path}` SHA256: `{sha256(abs_path)}`")

notices_lines.append("")

licenses_out.write_text("\n".join(licenses_lines), "utf-8")
notices_out.write_text("\n".join(notices_lines), "utf-8")
PY

if [[ "$mode" == "write" ]]; then
  cp "$generated_licenses_file" "$licenses_output_file"
  cp "$generated_notices_file" "$notices_output_file"

  echo "PASS [write] updated THIRD_PARTY_LICENSES.md"
  echo "PASS [write] updated THIRD_PARTY_NOTICES.md"
  echo "PASS [write] third-party artifacts generated"
  exit 0
fi

missing=0
if [[ ! -f "$licenses_output_file" ]]; then
  echo "FAIL [check] missing output artifact: $licenses_output_file (run --write first)" >&2
  missing=1
fi
if [[ ! -f "$notices_output_file" ]]; then
  echo "FAIL [check] missing output artifact: $notices_output_file (run --write first)" >&2
  missing=1
fi
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

drift=0
if ! cmp -s "$licenses_output_file" "$generated_licenses_file"; then
  echo "FAIL [check] $licenses_output_file is stale" >&2
  drift=1
fi
if ! cmp -s "$notices_output_file" "$generated_notices_file"; then
  echo "FAIL [check] $notices_output_file is stale" >&2
  drift=1
fi

if [[ "$drift" -ne 0 ]]; then
  echo "Run: bash scripts/generate-third-party-artifacts.sh --write" >&2
  exit 1
fi

echo "PASS [check] third-party artifacts are up to date"
