from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class ScriptRunResult:
    script: str
    argv: list[str]
    exit_code: int
    duration_ms: int
    stdout_path: str
    stderr_path: str
    status: str  # pass|fail
    note: str | None = None
    case: str | None = None


SCRIPT_RUN_RESULTS: list[ScriptRunResult] = []
SCRIPT_SMOKE_RUN_RESULTS: list[ScriptRunResult] = []


def repo_root() -> Path:
    if code_home := os.environ.get("CODEX_HOME"):
        p = Path(code_home)
        if p.is_dir():
            return p.resolve()
    root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    return Path(root).resolve()


def out_dir() -> Path:
    return repo_root() / "out" / "tests" / "script-regression"


def out_dir_smoke() -> Path:
    return repo_root() / "out" / "tests" / "script-smoke"


def default_smoke_env(repo: Path) -> dict[str, str]:
    base = os.environ.copy()
    # Keep smoke tests hermetic: ignore any host-level git config overrides.
    base.pop("GIT_CONFIG_GLOBAL", None)
    base.pop("GIT_CONFIG_SYSTEM", None)
    base["GIT_CONFIG_NOSYSTEM"] = "1"

    out_base = out_dir_smoke()
    home = out_base / "home"
    xdg_config = out_base / "xdg" / "config"
    xdg_cache = out_base / "xdg" / "cache"
    xdg_data = out_base / "xdg" / "data"
    xdg_state = out_base / "xdg" / "state"
    tmp = out_base / "tmp"

    for p in (home, xdg_config, xdg_cache, xdg_data, xdg_state, tmp):
        p.mkdir(parents=True, exist_ok=True)

    stub_bin = repo / "tests" / "stubs" / "bin"
    base["PATH"] = os.pathsep.join([str(stub_bin), base.get("PATH", "")])

    base.update(
        {
            "CODEX_HOME": str(repo),
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(xdg_config),
            "XDG_CACHE_HOME": str(xdg_cache),
            "XDG_DATA_HOME": str(xdg_data),
            "XDG_STATE_HOME": str(xdg_state),
            "TMPDIR": str(tmp),
            "NO_COLOR": "1",
            "CLICOLOR": "0",
            "CLICOLOR_FORCE": "0",
            "FORCE_COLOR": "0",
            "PY_COLORS": "0",
            "GIT_PAGER": "cat",
            "PAGER": "cat",
        }
    )

    return base


def default_env(repo: Path) -> dict[str, str]:
    base = os.environ.copy()
    # Keep regression tests hermetic: ignore any host-level git config overrides.
    base.pop("GIT_CONFIG_GLOBAL", None)
    base.pop("GIT_CONFIG_SYSTEM", None)
    base["GIT_CONFIG_NOSYSTEM"] = "1"

    out_base = out_dir()
    home = out_base / "home"
    xdg_config = out_base / "xdg" / "config"
    xdg_cache = out_base / "xdg" / "cache"
    xdg_data = out_base / "xdg" / "data"
    xdg_state = out_base / "xdg" / "state"
    tmp = out_base / "tmp"

    for p in (home, xdg_config, xdg_cache, xdg_data, xdg_state, tmp):
        p.mkdir(parents=True, exist_ok=True)

    stub_bin = repo / "tests" / "stubs" / "bin"
    base["PATH"] = os.pathsep.join([str(stub_bin), base.get("PATH", "")])

    base.update(
        {
            "CODEX_HOME": str(repo),
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(xdg_config),
            "XDG_CACHE_HOME": str(xdg_cache),
            "XDG_DATA_HOME": str(xdg_data),
            "XDG_STATE_HOME": str(xdg_state),
            "TMPDIR": str(tmp),
            "NO_COLOR": "1",
            "CLICOLOR": "0",
            "CLICOLOR_FORCE": "0",
            "FORCE_COLOR": "0",
            "PY_COLORS": "0",
            "GIT_PAGER": "cat",
            "PAGER": "cat",
        }
    )

    return base


def _coerce_str_env(env: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, value in env.items():
        if value is None:
            continue
        out[str(key)] = str(value)
    return out


def load_script_specs(spec_root: Path) -> dict[str, dict[str, Any]]:
    specs: dict[str, dict[str, Any]] = {}
    if not spec_root.exists():
        return specs

    for spec_path in sorted(spec_root.rglob("*.json")):
        rel = spec_path.relative_to(spec_root)
        script_rel = rel.with_suffix("")  # drop ".json"
        raw = json.loads(spec_path.read_text("utf-8"))
        if not isinstance(raw, dict):
            raise TypeError(f"spec must be a JSON object: {spec_path}")
        specs[script_rel.as_posix()] = raw

    return specs


def discover_scripts() -> list[str]:
    repo = repo_root()
    tracked = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
    scripts: list[str] = []
    for p in tracked:
        if p.endswith(".md"):
            continue
        if not (repo / p).is_file():
            continue
        if p.startswith("scripts/") or (p.startswith("skills/") and "/scripts/" in p):
            scripts.append(p)
        if p.startswith("commands/"):
            scripts.append(p)
    return sorted(set(scripts))


def write_summary_json(results: list[ScriptRunResult], out_base: Path | None = None) -> Path:
    out_base = out_base or out_dir()
    out_base.mkdir(parents=True, exist_ok=True)
    summary_path = out_base / "summary.json"

    payload = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "repo_root": str(repo_root()),
        "python": sys.version.splitlines()[0],
        "results": [
            {
                "script": r.script,
                "case": r.case,
                "argv": r.argv,
                "exit_code": r.exit_code,
                "duration_ms": r.duration_ms,
                "stdout_path": r.stdout_path,
                "stderr_path": r.stderr_path,
                "status": r.status,
                "note": r.note,
            }
            for r in results
        ],
    }

    summary_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", "utf-8")
    return summary_path


def pytest_sessionfinish(session, exitstatus):  # type: ignore[no-untyped-def]
    summary_path = write_summary_json(SCRIPT_RUN_RESULTS, out_dir())
    smoke_summary_path = write_summary_json(SCRIPT_SMOKE_RUN_RESULTS, out_dir_smoke())

    coverage_md_path = write_script_coverage_reports(
        SCRIPT_RUN_RESULTS,
        SCRIPT_SMOKE_RUN_RESULTS,
        repo_root(),
    )
    if hasattr(session.config, "stash"):
        session.config.stash["script_regression_summary_path"] = str(summary_path)
        session.config.stash["script_smoke_summary_path"] = str(smoke_summary_path)
        session.config.stash["script_coverage_md_path"] = str(coverage_md_path)


def script_coverage_out_dir() -> Path:
    return repo_root() / "out" / "tests" / "script-coverage"


def script_group(script: str) -> str:
    if script.startswith("commands/"):
        return "commands"
    if script.startswith("scripts/"):
        return "scripts"
    if script.startswith("skills/") and "/scripts/" in script:
        return script.split("/scripts/", 1)[0]
    if script.startswith("skills/"):
        return "skills"
    return script.split("/", 1)[0] if "/" in script else script


def _count_intersection(a: set[str], b: set[str]) -> int:
    return len(a.intersection(b))


def write_script_coverage_reports(
    regression_results: list[ScriptRunResult],
    smoke_results: list[ScriptRunResult],
    repo: Path,
) -> Path:
    discovered = discover_scripts()
    discovered_set = set(discovered)

    regression_ran = {r.script for r in regression_results}
    smoke_ran = {r.script for r in smoke_results}
    any_ran = regression_ran | smoke_ran

    missing_any = sorted(discovered_set - any_ran)
    missing_regression = sorted(discovered_set - regression_ran)
    missing_smoke = sorted(discovered_set - smoke_ran)

    regression_failed = sorted({r.script for r in regression_results if r.status != "pass"})
    smoke_failed = sorted({r.script for r in smoke_results if r.status != "pass"})

    specs = load_script_specs(repo / "tests" / "script_specs")
    smoke_defined = {script for script, spec in specs.items() if spec.get("smoke")}

    smoke_defined_in_repo = smoke_defined & discovered_set
    smoke_defined_orphan = sorted(smoke_defined - discovered_set)

    missing_smoke_spec = sorted(discovered_set - smoke_defined_in_repo)
    missing_smoke_spec_set = set(missing_smoke_spec)
    missing_smoke_set = set(missing_smoke)
    missing_smoke_spec_without_smoke_runs = sorted(missing_smoke_spec_set & missing_smoke_set)
    missing_smoke_spec_with_smoke_runs = sorted(missing_smoke_spec_set - set(missing_smoke_spec_without_smoke_runs))

    discovered_skills = {s for s in discovered_set if s.startswith("skills/") and "/scripts/" in s}
    discovered_repo_scripts = {s for s in discovered_set if s.startswith("scripts/")}

    out_base = script_coverage_out_dir()
    out_base.mkdir(parents=True, exist_ok=True)
    json_path = out_base / "summary.json"
    md_path = out_base / "summary.md"

    groups: dict[str, list[str]] = {}
    for script in discovered:
        groups.setdefault(script_group(script), []).append(script)

    group_rows: list[dict[str, object]] = []
    for group, scripts in sorted(groups.items(), key=lambda x: (x[0])):
        scripts_set = set(scripts)
        group_rows.append(
            {
                "group": group,
                "scripts_total": len(scripts),
                "regression_ran": _count_intersection(scripts_set, regression_ran),
                "smoke_ran": _count_intersection(scripts_set, smoke_ran),
                "any_ran": _count_intersection(scripts_set, any_ran),
                "smoke_defined": _count_intersection(scripts_set, smoke_defined_in_repo),
            }
        )

    payload = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "repo_root": str(repo.resolve()),
        "python": sys.version.splitlines()[0],
        "totals": {
            "discovered_scripts": len(discovered),
            "discovered_skill_scripts": len(discovered_skills),
            "discovered_repo_scripts": len(discovered_repo_scripts),
            "script_specs": len(specs),
            "smoke_specs": len(smoke_defined),
            "smoke_specs_in_repo": len(smoke_defined_in_repo),
        },
        "coverage": {
            "regression_ran": len(regression_ran),
            "smoke_ran": len(smoke_ran),
            "any_ran": len(any_ran),
            "missing_any": missing_any,
            "missing_regression": missing_regression,
            "missing_smoke": missing_smoke,
            "regression_failed": regression_failed,
            "smoke_failed": smoke_failed,
        },
        "smoke_spec_gaps": {
            "missing_smoke_spec_for_discovered": missing_smoke_spec,
            "missing_smoke_spec_without_smoke_runs": missing_smoke_spec_without_smoke_runs,
            "missing_smoke_spec_with_smoke_runs": missing_smoke_spec_with_smoke_runs,
            "orphan_smoke_specs": smoke_defined_orphan,
        },
        "breakdown": {
            "skills": {
                "scripts_total": len(discovered_skills),
                "smoke_specs": _count_intersection(discovered_skills, smoke_defined_in_repo),
                "smoke_ran": _count_intersection(discovered_skills, smoke_ran),
                "any_ran": _count_intersection(discovered_skills, any_ran),
            },
            "repo_scripts": {
                "scripts_total": len(discovered_repo_scripts),
                "smoke_specs": _count_intersection(discovered_repo_scripts, smoke_defined_in_repo),
                "smoke_ran": _count_intersection(discovered_repo_scripts, smoke_ran),
                "any_ran": _count_intersection(discovered_repo_scripts, any_ran),
            },
        },
        "groups": group_rows,
    }

    json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", "utf-8")

    def pct(n: int, d: int) -> str:
        if d <= 0:
            return "0%"
        return f"{(n / d) * 100:.1f}%"

    lines: list[str] = []
    lines.append("# Script coverage (functional)")
    lines.append("")
    lines.append(f"- Generated: `{payload['generated_at']}`")
    lines.append(f"- Discovered scripts: `{len(discovered)}`")
    lines.append(f"- Ran (any): `{len(any_ran)}` ({pct(len(any_ran), len(discovered))})")
    lines.append(f"  - Regression ran: `{len(regression_ran)}` ({pct(len(regression_ran), len(discovered))})")
    lines.append(f"  - Smoke ran: `{len(smoke_ran)}` ({pct(len(smoke_ran), len(discovered))})")
    lines.append(f"- Smoke specs (in repo): `{len(smoke_defined_in_repo)}` ({pct(len(smoke_defined_in_repo), len(discovered))})")
    if smoke_defined_orphan:
        lines.append(f"- Orphan smoke specs: `{len(smoke_defined_orphan)}`")
    lines.append("")
    lines.append("## Breakdown")
    lines.append("")
    lines.append(
        f"- Skills scripts: `{len(discovered_skills)}`; smoke specs: `{_count_intersection(discovered_skills, smoke_defined_in_repo)}`; "
        f"smoke ran: `{_count_intersection(discovered_skills, smoke_ran)}`"
    )
    lines.append(
        f"- Repo scripts: `{len(discovered_repo_scripts)}`; smoke specs: `{_count_intersection(discovered_repo_scripts, smoke_defined_in_repo)}`; "
        f"smoke ran: `{_count_intersection(discovered_repo_scripts, smoke_ran)}`"
    )
    lines.append("")
    lines.append("## Groups")
    lines.append("")
    lines.append("| Group | Scripts | Smoke spec | Smoke ran | Regression ran | Any ran |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
    for row in group_rows:
        lines.append(
            f"| `{row['group']}` | {row['scripts_total']} | {row['smoke_defined']} | {row['smoke_ran']} | {row['regression_ran']} | {row['any_ran']} |"
        )

    if missing_smoke:
        limit = 50
        lines.append("")
        lines.append("## Missing smoke runs")
        lines.append("")
        lines.append(f"_Scripts not executed via smoke tests in this pytest run (count: {len(missing_smoke)})._")
        for script in missing_smoke[:limit]:
            lines.append(f"- `{script}`")
        if len(missing_smoke) > limit:
            lines.append(f"- _... and {len(missing_smoke) - limit} more (see `summary.json`)._")

    if missing_any:
        limit = 50
        lines.append("")
        lines.append("## Missing (not executed)")
        lines.append("")
        for script in missing_any[:limit]:
            lines.append(f"- `{script}`")
        if len(missing_any) > limit:
            lines.append(f"- _... and {len(missing_any) - limit} more (see `summary.json`)._")

    if regression_failed or smoke_failed:
        lines.append("")
        lines.append("## Failures")
        lines.append("")
        if regression_failed:
            lines.append("- Regression failures:")
            for script in regression_failed:
                lines.append(f"  - `{script}`")
        if smoke_failed:
            lines.append("- Smoke failures:")
            for script in smoke_failed:
                lines.append(f"  - `{script}`")

    if missing_smoke_spec:
        limit = 50
        lines.append("")
        lines.append("## Missing smoke specs")
        lines.append("")

        if missing_smoke_spec_without_smoke_runs:
            lines.append(
                f"_Scripts without a `smoke` section AND without smoke execution in this run (count: {len(missing_smoke_spec_without_smoke_runs)})._"
            )
            for script in missing_smoke_spec_without_smoke_runs[:limit]:
                lines.append(f"- `{script}`")
            if len(missing_smoke_spec_without_smoke_runs) > limit:
                lines.append(
                    f"- _... and {len(missing_smoke_spec_without_smoke_runs) - limit} more (see `summary.json`)._"
                )
        if missing_smoke_spec_with_smoke_runs:
            lines.append("")
            lines.append(
                f"_Scripts without a `smoke` section but already exercised by fixture smoke tests (count: {len(missing_smoke_spec_with_smoke_runs)})._"
            )
            for script in missing_smoke_spec_with_smoke_runs[:limit]:
                lines.append(f"- `{script}`")
            if len(missing_smoke_spec_with_smoke_runs) > limit:
                lines.append(
                    f"- _... and {len(missing_smoke_spec_with_smoke_runs) - limit} more (see `summary.json`)._"
                )

    if smoke_defined_orphan:
        lines.append("")
        lines.append("## Orphan smoke specs")
        lines.append("")
        for script in smoke_defined_orphan:
            lines.append(f"- `{script}`")

    md_path.write_text("\n".join(lines).rstrip() + "\n", "utf-8")
    return md_path
