from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import repo_root


@pytest.mark.script_smoke
def test_fix_zsh_typeset_initializers_preserves_executable_bit(tmp_path: Path) -> None:
    fixture_root = tmp_path / "repo"
    fixture_root.mkdir(parents=True, exist_ok=True)
    (fixture_root / "commands").mkdir(parents=True, exist_ok=True)
    (fixture_root / "scripts").mkdir(parents=True, exist_ok=True)

    source_script = repo_root() / "scripts" / "fix-zsh-typeset-initializers.zsh"
    fixer = fixture_root / "scripts" / "fix-zsh-typeset-initializers.zsh"
    fixer.write_text(source_script.read_text("utf-8"), "utf-8")
    fixer.chmod(0o755)

    target = fixture_root / "commands" / "example"
    target.write_text(
        "\n".join(
            [
                "#!/usr/bin/env -S zsh -f",
                "example() {",
                "  typeset foo",
                '  foo="bar"',
                "  print -r -- \"$foo\"",
                "}",
                "example",
                "",
            ]
        ),
        "utf-8",
    )
    target.chmod(0o755)

    def run(cmd: list[str]) -> None:
        subprocess.run(cmd, cwd=str(fixture_root), check=True, text=True, capture_output=True)

    run(["git", "init"])
    run(["git", "config", "user.email", "fixture@example.com"])
    run(["git", "config", "user.name", "Fixture User"])
    run(["git", "add", "scripts/fix-zsh-typeset-initializers.zsh", "commands/example"])
    run(["git", "commit", "-m", "init"])

    completed = subprocess.run(
        ["zsh", "-f", str(fixer), "--write"],
        cwd=str(fixture_root),
        text=True,
        capture_output=True,
        timeout=20,
        check=False,
    )
    assert completed.returncode == 0, f"fixer failed: rc={completed.returncode}\nstderr={completed.stderr}"

    assert target.stat().st_mode & 0o111, f"target lost executable bit: {target}"
    assert "typeset foo=''" in target.read_text("utf-8")
