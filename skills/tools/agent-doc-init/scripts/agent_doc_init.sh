#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  $AGENT_HOME/skills/tools/agent-doc-init/scripts/agent_doc_init.sh [options]

Options:
  --dry-run                          Preview actions only (default).
  --apply                            Apply changes to disk.
  --force                            Overwrite baseline docs (requires --apply).
  --target <all|home|project>        Baseline target scope (default: all).
  --project-path <path>              Explicit PROJECT_PATH for agent-docs.
  --agent-home <path>                Explicit AGENT_HOME for agent-docs.
  --project-required <context:path[:notes]>
                                     Upsert one required project extension entry.
                                     Repeatable.
  -h, --help                         Show this help.

Notes:
  - Default behavior is non-destructive dry-run.
  - Baseline scaffolding uses --missing-only unless --force is explicitly set.
  - Project docs hydration rewrites baseline templates into project-aware content.
USAGE
}

die_usage() {
  echo "error: $1" >&2
  usage >&2
  exit 2
}

die_runtime() {
  echo "error: $1" >&2
  exit 1
}

validate_context() {
  case "$1" in
    startup|task-tools|project-dev|skill-dev) return 0 ;;
    *) return 1 ;;
  esac
}

parse_project_required() {
  local raw="$1"
  local context rest path notes

  if [[ "$raw" != *:* ]]; then
    die_usage "--project-required must be <context:path[:notes]>: $raw"
  fi

  context="${raw%%:*}"
  rest="${raw#*:}"
  if [[ "$rest" == *:* ]]; then
    path="${rest%%:*}"
    notes="${rest#*:}"
  else
    path="$rest"
    notes=""
  fi

  if [[ -z "$context" || -z "$path" ]]; then
    die_usage "--project-required must include non-empty context and path: $raw"
  fi
  if ! validate_context "$context"; then
    die_usage "unsupported context in --project-required: $context"
  fi

  printf '%s\n%s\n%s\n' "$context" "$path" "$notes"
}

extract_baseline_counts() {
  python3 -c 'import json,sys; p=json.load(sys.stdin); print("{} {}".format(int(p.get("missing_required",0)), int(p.get("missing_optional",0))))'
}

run_baseline_json() {
  local target="$1"
  shift
  agent-docs baseline --check --target "$target" --format json "$@"
}

run_project_doc_hydration() {
  local project_root="$1"
  local dry_run_mode="$2"

  python3 - "$project_root" "$dry_run_mode" <<'PY'
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def render_code_block(commands: list[str]) -> str:
    body = "\n".join(commands) if commands else "# Add project-specific commands."
    return f"```bash\n{body}\n```"


def parse_workflow_run_commands(path: Path) -> list[str]:
    commands: list[str] = []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        inline = re.match(r"^\s*run:\s*(.+?)\s*$", line)
        if inline:
            value = inline.group(1).strip()
            if value not in {"|", ">", "|-", ">-"}:
                commands.append(value)
                i += 1
                continue

            indent = len(line) - len(line.lstrip(" "))
            block_indent = indent + 2
            i += 1
            while i < len(lines):
                block_line = lines[i]
                if not block_line.strip():
                    i += 1
                    continue
                current_indent = len(block_line) - len(block_line.lstrip(" "))
                if current_indent < block_indent:
                    break
                cmd = block_line[block_indent:]
                if cmd.strip():
                    commands.append(cmd.rstrip())
                i += 1
            continue
        i += 1
    return commands


def detect_ci_context(project_root: Path) -> tuple[list[str], list[str]]:
    workflow_paths = sorted((project_root / ".github" / "workflows").glob("*.yml"))
    workflow_paths += sorted((project_root / ".github" / "workflows").glob("*.yaml"))
    workflow_rel = [str(path.relative_to(project_root)) for path in workflow_paths]

    run_commands: list[str] = []
    for workflow in workflow_paths:
        run_commands.extend(parse_workflow_run_commands(workflow))
    return workflow_rel, unique(run_commands)


def categorize_commands(
    commands: list[str],
) -> tuple[list[str], list[str], list[str]]:
    setup_keywords = ("install", "setup", "tap", "bootstrap", "dependency", "deps")
    build_keywords = ("build", "compile", "lint", "style", "format", "check", "clippy")
    test_keywords = (" test", "pytest", "unit", "integration", "cargo test", "go test", "brew test")

    setup_cmds: list[str] = []
    build_cmds: list[str] = []
    test_cmds: list[str] = []

    for cmd in commands:
        lowered = f" {cmd.lower()} "
        if any(key in lowered for key in test_keywords):
            test_cmds.append(cmd)
            continue
        if any(key in lowered for key in build_keywords):
            build_cmds.append(cmd)
            continue
        if any(key in lowered for key in setup_keywords):
            setup_cmds.append(cmd)

    return unique(setup_cmds), unique(build_cmds), unique(test_cmds)


def detect_formula_names(project_root: Path) -> list[str]:
    formula_dir = project_root / "Formula"
    if not formula_dir.is_dir():
        return []
    return sorted(path.stem for path in formula_dir.glob("*.rb") if path.is_file())


def detect_git_remote_slug(project_root: Path) -> str:
    try:
        raw = subprocess.check_output(
            ["git", "-C", str(project_root), "remote", "get-url", "origin"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""

    if raw.endswith(".git"):
        raw = raw[:-4]
    if raw.startswith("git@github.com:"):
        return raw.split(":", 1)[1]
    if "github.com/" in raw:
        return raw.split("github.com/", 1)[1]
    return ""


def ensure_project_aware_commands(
    project_root: Path,
    setup_cmds: list[str],
    build_cmds: list[str],
    test_cmds: list[str],
    formula_names: list[str],
    remote_slug: str,
) -> tuple[list[str], list[str], list[str]]:
    if not setup_cmds:
        setup_cmds = ["command -v brew >/dev/null 2>&1"]
        if remote_slug:
            setup_cmds.append(f"brew tap {remote_slug}")
        elif formula_names:
            setup_cmds.append("brew tap <owner>/<tap>")

    if not build_cmds:
        if formula_names:
            formula_path = (
                f"Formula/{formula_names[0]}.rb"
                if len(formula_names) == 1
                else "Formula/*.rb"
            )
            build_cmds = [
                f"ruby -c {formula_path}",
                f"HOMEBREW_NO_AUTO_UPDATE=1 brew style {formula_path}",
            ]
        else:
            build_cmds = ["# No explicit build commands detected in CI workflows."]

    if not test_cmds:
        if formula_names:
            formula_path = (
                f"Formula/{formula_names[0]}.rb"
                if len(formula_names) == 1
                else "Formula/*.rb"
            )
            test_cmds = [
                f"HOMEBREW_NO_AUTO_UPDATE=1 brew install --formula ./{formula_path}",
                f"HOMEBREW_NO_AUTO_UPDATE=1 brew test {formula_names[0]}",
            ]
        else:
            test_cmds = ["# No automated test commands detected in CI workflows."]

    return unique(setup_cmds), unique(build_cmds), unique(test_cmds)


def render_agents_md(project_root: Path) -> str:
    rel = project_root
    if rel.name:
        rel_name = rel.name
    else:
        rel_name = "<project>"
    return "\n".join(
        [
            "# AGENTS.md",
            "",
            f"## Startup Policy ({rel_name})",
            "",
            "Run required preflight gates before write/test/commit:",
            "",
            "```bash",
            "agent-docs resolve --context startup --strict --format checklist",
            "agent-docs resolve --context project-dev --strict --format checklist",
            "```",
            "",
            "## Runtime Intent Gates",
            "",
            "- Project implementation:",
            "  `agent-docs resolve --context project-dev --strict --format checklist`",
            "- Technical research:",
            "  `agent-docs resolve --context task-tools --strict --format checklist`",
            "- Skill authoring:",
            "  `agent-docs resolve --context skill-dev --strict --format checklist`",
            "",
            "## Failure Handling",
            "",
            "If strict resolve fails because required docs are missing, run:",
            "",
            "```bash",
            "agent-docs baseline --check --target all --strict --format text",
            "```",
            "",
            "Use `AGENT_DOCS.toml` for additional context-specific required docs.",
            "",
        ]
    )


def render_development_md(project_root: Path) -> str:
    workflows, run_commands = detect_ci_context(project_root)
    setup_cmds, build_cmds, test_cmds = categorize_commands(run_commands)
    formula_names = detect_formula_names(project_root)
    remote_slug = detect_git_remote_slug(project_root)
    setup_cmds, build_cmds, test_cmds = ensure_project_aware_commands(
        project_root,
        setup_cmds,
        build_cmds,
        test_cmds,
        formula_names,
        remote_slug,
    )

    workflow_note = ", ".join(workflows) if workflows else "none"

    return "\n".join(
        [
            "# DEVELOPMENT.md",
            "",
            "## Setup",
            "",
            "Run setup commands from repository root:",
            "",
            render_code_block(setup_cmds),
            "",
            "## Build",
            "",
            "Run validation/build commands before sharing changes:",
            "",
            render_code_block(build_cmds),
            "",
            "## Test",
            "",
            "Run checks before delivery:",
            "",
            render_code_block(test_cmds),
            "",
            "## Notes",
            "",
            f"- CI workflows inspected: {workflow_note}",
            "- Keep commands deterministic and runnable from the repository root.",
            "- Update this file when your build/test workflow changes.",
            "",
        ]
    )


def is_template_agents(text: str) -> bool:
    markers = [
        "Resolve required startup policies before task execution:",
        "Resolve project development docs before implementing changes:",
    ]
    return all(marker in text for marker in markers)


def is_template_development(text: str) -> bool:
    markers = [
        'echo "Define setup command for this repository"',
        'echo "Define build command for this repository"',
        'echo "Define test command for this repository"',
    ]
    return any(marker in text for marker in markers)


def apply_or_plan(
    path: Path,
    dry_run: bool,
    detect_template,
    render,
    *,
    template_hits: list[str],
    updated_files: list[str],
    planned_files: list[str],
) -> None:
    if not path.is_file():
        return
    raw = path.read_text(encoding="utf-8", errors="replace")
    if not detect_template(raw):
        return
    rel = str(path.relative_to(project_root))
    template_hits.append(rel)
    rendered = render()
    if dry_run:
        planned_files.append(rel)
        return
    if raw != rendered:
        path.write_text(rendered, encoding="utf-8")
        updated_files.append(rel)


project_root = Path(sys.argv[1]).resolve()
dry_run = sys.argv[2].strip().lower() == "true"

if not project_root.exists():
    print("action=skipped")
    print("changed=false")
    print("files=")
    print("template_guard=passed")
    print("template_files=")
    print("template_hits=")
    raise SystemExit(0)

template_hits: list[str] = []
updated_files: list[str] = []
planned_files: list[str] = []

agents_path = project_root / "AGENTS.md"
development_path = project_root / "DEVELOPMENT.md"

apply_or_plan(
    agents_path,
    dry_run,
    is_template_agents,
    lambda: render_agents_md(project_root),
    template_hits=template_hits,
    updated_files=updated_files,
    planned_files=planned_files,
)
apply_or_plan(
    development_path,
    dry_run,
    is_template_development,
    lambda: render_development_md(project_root),
    template_hits=template_hits,
    updated_files=updated_files,
    planned_files=planned_files,
)

remaining_template_files: list[str] = []
if agents_path.is_file():
    text = agents_path.read_text(encoding="utf-8", errors="replace")
    if is_template_agents(text):
        remaining_template_files.append(str(agents_path.relative_to(project_root)))
if development_path.is_file():
    text = development_path.read_text(encoding="utf-8", errors="replace")
    if is_template_development(text):
        remaining_template_files.append(str(development_path.relative_to(project_root)))

action = "skipped"
changed = False
if dry_run:
    if planned_files:
        action = "planned"
        changed = True
else:
    if updated_files:
        action = "applied"
        changed = True

if dry_run:
    template_guard = "pending" if template_hits else "passed"
else:
    template_guard = "failed" if remaining_template_files else "passed"

print(f"action={action}")
print(f"changed={'true' if changed else 'false'}")
print(f"files={','.join(updated_files if updated_files else planned_files)}")
print(f"template_guard={template_guard}")
print(f"template_files={','.join(remaining_template_files)}")
print(f"template_hits={','.join(template_hits)}")
PY
}

dry_run="true"
apply="false"
force="false"
target="all"
project_path=""
agent_home=""
declare -a project_required_entries=()

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --dry-run)
      dry_run="true"
      apply="false"
      shift
      ;;
    --apply)
      apply="true"
      dry_run="false"
      shift
      ;;
    --force)
      force="true"
      shift
      ;;
    --target)
      if [[ $# -lt 2 ]]; then
        die_usage "--target requires a value"
      fi
      case "${2:-}" in
        all|home|project) target="${2:-}" ;;
        *) die_usage "--target must be one of: all|home|project" ;;
      esac
      shift 2
      ;;
    --project-path)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        die_usage "--project-path requires a value"
      fi
      project_path="${2:-}"
      shift 2
      ;;
    --agent-home)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        die_usage "--agent-home requires a value"
      fi
      agent_home="${2:-}"
      shift 2
      ;;
    --project-required)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        die_usage "--project-required requires a value"
      fi
      project_required_entries+=("${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown argument: ${1:-}"
      ;;
  esac
done

if [[ "$force" == "true" && "$apply" != "true" ]]; then
  die_usage "--force requires --apply"
fi

if ! command -v agent-docs >/dev/null 2>&1; then
  die_runtime "agent-docs is required but not found on PATH"
fi
if ! command -v python3 >/dev/null 2>&1; then
  die_runtime "python3 is required but not found on PATH"
fi

effective_AGENT_HOME="${agent_home:-${AGENT_HOME:-${AGENTS_HOME:-$HOME/.agents}}}"
effective_project_path="${project_path:-${PROJECT_PATH:-$PWD}}"

declare -a common_args=()
if [[ -n "$project_path" ]]; then
  common_args+=(--project-path "$project_path")
fi
if [[ -n "$effective_AGENT_HOME" ]]; then
  common_args+=(--agent-home "$effective_AGENT_HOME")
fi

before_json="$(run_baseline_json "$target" "${common_args[@]}")"
read -r missing_before missing_optional_before <<<"$(printf '%s' "$before_json" | extract_baseline_counts)"

scaffold_action="skipped"
scaffold_missing_only="true"
if [[ "$force" == "true" ]]; then
  scaffold_missing_only="false"
fi

if (( missing_before > 0 )) || [[ "$force" == "true" ]]; then
  declare -a scaffold_args=()
  scaffold_args+=(scaffold-baseline --target "$target" --format text)
  scaffold_args+=("${common_args[@]}")
  if [[ "$force" == "true" ]]; then
    scaffold_args+=(--force)
  else
    scaffold_args+=(--missing-only)
  fi
  if [[ "$dry_run" == "true" ]]; then
    scaffold_args+=(--dry-run)
    scaffold_action="planned"
  else
    scaffold_action="applied"
  fi
  agent-docs "${scaffold_args[@]}" >/dev/null
fi

project_entries_requested="${#project_required_entries[@]}"
project_entries_applied=0
if (( project_entries_requested > 0 )); then
  for raw in "${project_required_entries[@]}"; do
    context=""
    path=""
    notes=""
    {
      IFS= read -r context
      IFS= read -r path
      IFS= read -r notes
    } < <(parse_project_required "$raw")
    if [[ "$dry_run" == "true" ]]; then
      printf 'project_entry_plan context=%s path=%s required=true when=always\n' "$context" "$path"
      continue
    fi

    declare -a add_args=()
    add_args+=(add --target project --context "$context" --scope project --path "$path" --required --when always)
    add_args+=("${common_args[@]}")
    if [[ -n "$notes" ]]; then
      add_args+=(--notes "$notes")
    fi
    agent-docs "${add_args[@]}" >/dev/null
    project_entries_applied=$((project_entries_applied + 1))
  done
fi

doc_hydration_action="skipped"
doc_hydration_changed="false"
doc_hydration_files=""
template_guard="passed"
template_files=""
template_hits=""

if [[ "$target" == "all" || "$target" == "project" ]]; then
  hydration_output="$(run_project_doc_hydration "$effective_project_path" "$dry_run")"
  while IFS='=' read -r key value; do
    case "$key" in
      action) doc_hydration_action="$value" ;;
      changed) doc_hydration_changed="$value" ;;
      files) doc_hydration_files="$value" ;;
      template_guard) template_guard="$value" ;;
      template_files) template_files="$value" ;;
      template_hits) template_hits="$value" ;;
    esac
  done <<<"$hydration_output"
fi

if [[ "$apply" == "true" && "$template_guard" == "failed" ]]; then
  if [[ -n "$template_files" ]]; then
    die_runtime "template-only docs remain after hydration: $template_files"
  fi
  die_runtime "template-only docs remain after hydration"
fi

after_json="$(run_baseline_json "$target" "${common_args[@]}")"
read -r missing_after missing_optional_after <<<"$(printf '%s' "$after_json" | extract_baseline_counts)"

changed="false"
if [[ "$apply" == "true" ]]; then
  if [[ "$scaffold_action" == "applied" || "$project_entries_applied" -gt 0 || "$doc_hydration_changed" == "true" ]]; then
    changed="true"
  fi
fi

mode="dry-run"
if [[ "$apply" == "true" ]]; then
  mode="apply"
fi

printf 'agent_doc_init mode=%s target=%s force=%s\n' "$mode" "$target" "$force"
printf 'agent_doc_init AGENT_HOME=%s\n' "$effective_AGENT_HOME"
printf 'agent_doc_init project_path=%s\n' "$effective_project_path"
printf 'baseline_before missing_required=%s missing_optional=%s\n' "$missing_before" "$missing_optional_before"
printf 'scaffold_action=%s missing_only=%s\n' "$scaffold_action" "$scaffold_missing_only"
printf 'project_entries requested=%s applied=%s\n' "$project_entries_requested" "$project_entries_applied"
printf 'doc_hydration action=%s changed=%s files=%s template_guard=%s template_hits=%s template_files=%s\n' \
  "$doc_hydration_action" "$doc_hydration_changed" "$doc_hydration_files" "$template_guard" "$template_hits" "$template_files"
printf 'baseline_after missing_required=%s missing_optional=%s\n' "$missing_after" "$missing_optional_after"
printf 'result changed=%s dry_run=%s apply=%s force=%s\n' "$changed" "$dry_run" "$apply" "$force"
