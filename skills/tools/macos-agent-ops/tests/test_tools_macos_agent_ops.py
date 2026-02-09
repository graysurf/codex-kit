from __future__ import annotations

from pathlib import Path

from skills._shared.python.skill_testing import assert_entrypoints_exist, assert_skill_contract


def test_tools_macos_agent_ops_contract() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_skill_contract(skill_root)


def test_tools_macos_agent_ops_entrypoints_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    assert_entrypoints_exist(skill_root, ["scripts/macos-agent-ops.sh"])


def test_tools_macos_agent_ops_references_exist() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    expected = [
        "references/e2e-ref-01-preflight-focus.md",
        "references/e2e-ref-02-finder-routine.md",
        "references/e2e-ref-03-matrix-routine.md",
    ]
    for rel in expected:
        assert (skill_root / rel).is_file(), f"missing reference file: {rel}"


def test_tools_macos_agent_ops_docs_include_latest_cli_usage() -> None:
    skill_root = Path(__file__).resolve().parents[1]
    content = (skill_root / "SKILL.md").read_text(encoding="utf-8")
    assert "macos-agent-ops.sh input-source" in content
    assert "macos-agent-ops.sh ax-check" in content
    assert "--reopen-on-fail" in content
    assert "im-select" in content
    assert "--include-probes" in content
    assert "screen_recording" in content
    assert "wait ax-present" in content
    assert "wait ax-unique" in content
    assert "--gate-app-active" in content
    assert "--postcondition-attribute" in content
    assert "--match-strategy" in content
    assert "--selector-explain" in content
    assert "--selector-padding" in content
    assert "--if-changed" in content
    assert "--if-changed-threshold" in content
    assert "debug bundle" in content
    assert "--error-format json" in content
