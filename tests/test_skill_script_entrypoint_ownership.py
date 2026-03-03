from __future__ import annotations

from pathlib import Path

import pytest

from skills._shared.python.skill_testing.assertions import assert_skill_script_entrypoint_ownership

# Keep exclusions explicit and minimal. Empty by default; add entries only with review.
APPROVED_UNOWNED_SKILL_SCRIPTS: tuple[str, ...] = (
    "skills/.system/skill-creator/scripts/generate_openai_yaml.py",
    "skills/.system/skill-creator/scripts/init_skill.py",
    "skills/.system/skill-creator/scripts/quick_validate.py",
    "skills/.system/skill-installer/scripts/github_utils.py",
    "skills/.system/skill-installer/scripts/install-skill-from-github.py",
    "skills/.system/skill-installer/scripts/list-skills.py",
)


@pytest.mark.script_regression
def test_skill_script_entrypoint_ownership_parity() -> None:
    repo = Path(__file__).resolve().parents[1]
    assert_skill_script_entrypoint_ownership(
        repo,
        approved_exclusions=APPROVED_UNOWNED_SKILL_SCRIPTS,
    )
