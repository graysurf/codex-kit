from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from .conftest import SCRIPT_SMOKE_RUN_RESULTS, repo_root
from .test_script_smoke import run_smoke_script


SCRIPT_CREATE_WORKTREES = (
    "skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/create_worktrees_from_tsv.sh"
)
SCRIPT_CLEANUP_WORKTREES = (
    "skills/workflows/pr/progress/worktree-stacked-feature-pr/scripts/cleanup_worktrees.sh"
)


def git(cmd: list[str], *, cwd: Path) -> None:
    subprocess.run(["git", *cmd], cwd=str(cwd), check=True, text=True, capture_output=True)


def git_output(cmd: list[str], *, cwd: Path) -> str:
    completed = subprocess.run(["git", *cmd], cwd=str(cwd), check=True, text=True, capture_output=True)
    return completed.stdout


def init_fixture_repo(tmp_path: Path, *, default_branch: str = "main") -> tuple[Path, Path]:
    work_tree = tmp_path / "repo"
    origin = tmp_path / "origin.git"
    work_tree.mkdir(parents=True, exist_ok=True)
    origin.mkdir(parents=True, exist_ok=True)

    git(["init"], cwd=work_tree)
    git(["config", "user.email", "fixture@example.com"], cwd=work_tree)
    git(["config", "user.name", "Fixture User"], cwd=work_tree)

    git(["checkout", "-b", default_branch], cwd=work_tree)

    (work_tree / "README.md").write_text("fixture\n", "utf-8")
    git(["add", "README.md"], cwd=work_tree)
    git(["commit", "-m", "init"], cwd=work_tree)

    git(["init", "--bare"], cwd=origin)
    git(["remote", "add", "origin", str(origin)], cwd=work_tree)
    git(["push", "-u", "origin", default_branch], cwd=work_tree)

    return (work_tree, origin)


def fixture_spec_path(repo: Path, name: str) -> Path:
    return repo / "tests" / "fixtures" / "worktree-specs" / name


def parse_worktree_names(spec_path: Path) -> list[str]:
    names: list[str] = []
    for raw in spec_path.read_text("utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 3:
            names.append(parts[2])
    return names


@pytest.mark.script_smoke
def test_script_smoke_create_worktrees_from_tsv_success(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    spec_path = fixture_spec_path(repo, "valid.tsv")

    spec = {"args": ["--spec", str(spec_path)], "timeout_sec": 20}
    result = run_smoke_script(
        SCRIPT_CREATE_WORKTREES,
        "worktree-create-success",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    worktrees_root = work_tree.parent / ".worktrees" / work_tree.name
    names = parse_worktree_names(spec_path)
    for name in names:
        path = worktrees_root / name
        assert path.exists(), f"missing worktree path: {path}"
        assert (path / ".git").exists(), f"missing .git for worktree: {path}"

    listing = git_output(["worktree", "list", "--porcelain"], cwd=work_tree)
    for name in names:
        path = worktrees_root / name
        assert str(path) in listing


@pytest.mark.script_smoke
def test_script_smoke_create_worktrees_from_tsv_dry_run(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    spec_path = fixture_spec_path(repo, "valid.tsv")

    spec = {"args": ["--spec", str(spec_path), "--dry-run"], "timeout_sec": 20}
    result = run_smoke_script(
        SCRIPT_CREATE_WORKTREES,
        "worktree-create-dry-run",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    worktrees_root = work_tree.parent / ".worktrees" / work_tree.name
    names = parse_worktree_names(spec_path)
    for name in names:
        assert not (worktrees_root / name).exists(), "dry-run should not create worktree paths"


@pytest.mark.script_smoke
def test_script_smoke_create_worktrees_from_tsv_worktrees_root_override(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    spec_path = fixture_spec_path(repo, "valid.tsv")

    spec = {"args": ["--spec", str(spec_path), "--worktrees-root", "custom-worktrees"], "timeout_sec": 20}
    result = run_smoke_script(
        SCRIPT_CREATE_WORKTREES,
        "worktree-create-root-override",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    worktrees_root = work_tree / "custom-worktrees"
    names = parse_worktree_names(spec_path)
    for name in names:
        path = worktrees_root / name
        assert path.exists(), f"missing worktree path under override root: {path}"


@pytest.mark.script_smoke
def test_script_smoke_create_worktrees_from_tsv_invalid_spec(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    spec_path = fixture_spec_path(repo, "invalid.tsv")

    spec = {
        "args": ["--spec", str(spec_path)],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"invalid spec line"},
    }
    result = run_smoke_script(
        SCRIPT_CREATE_WORKTREES,
        "worktree-create-invalid",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    worktrees_root = work_tree.parent / ".worktrees" / work_tree.name
    assert worktrees_root.exists(), "worktrees root not created"
    assert not any(worktrees_root.iterdir()), "unexpected worktrees created"


@pytest.mark.script_smoke
def test_script_smoke_create_worktrees_from_tsv_path_collision(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    spec_path = fixture_spec_path(repo, "collision.tsv")

    worktrees_root = work_tree.parent / ".worktrees" / work_tree.name
    collision_path = worktrees_root / "feat__fixture-collision"
    collision_path.mkdir(parents=True, exist_ok=True)

    spec = {
        "args": ["--spec", str(spec_path)],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"path already exists"},
    }
    result = run_smoke_script(
        SCRIPT_CREATE_WORKTREES,
        "worktree-create-collision",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    listing = git_output(["worktree", "list", "--porcelain"], cwd=work_tree)
    assert str(collision_path) not in listing


@pytest.mark.script_smoke
def test_script_smoke_cleanup_worktrees_removes_matching(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    worktrees_root = work_tree.parent / ".worktrees" / work_tree.name
    worktrees_root.mkdir(parents=True, exist_ok=True)

    remove_a = worktrees_root / "fixture_remove_a"
    remove_b = worktrees_root / "fixture_remove_b"
    keep = worktrees_root / "fixture_keep"

    git(["worktree", "add", "-b", "feat/remove-a", str(remove_a), "main"], cwd=work_tree)
    git(["worktree", "add", "-b", "feat/remove-b", str(remove_b), "main"], cwd=work_tree)
    git(["worktree", "add", "-b", "feat/keep", str(keep), "main"], cwd=work_tree)

    repo = repo_root()
    prefix = f".worktrees/{work_tree.name}/fixture_remove"
    spec = {"args": ["--prefix", prefix, "--yes"], "timeout_sec": 20}
    result = run_smoke_script(
        SCRIPT_CLEANUP_WORKTREES,
        "cleanup-worktrees",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    assert not remove_a.exists(), "expected worktree to be removed"
    assert not remove_b.exists(), "expected worktree to be removed"
    assert keep.exists(), "non-matching worktree should remain"

    listing = git_output(["worktree", "list", "--porcelain"], cwd=work_tree)
    assert str(keep) in listing
    assert str(remove_a) not in listing
    assert str(remove_b) not in listing


@pytest.mark.script_smoke
def test_script_smoke_cleanup_worktrees_default_dry_run(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    worktrees_root = work_tree.parent / ".worktrees" / work_tree.name
    worktrees_root.mkdir(parents=True, exist_ok=True)

    remove_a = worktrees_root / "fixture_remove_a"
    keep = worktrees_root / "fixture_keep"

    git(["worktree", "add", "-b", "feat/remove-a", str(remove_a), "main"], cwd=work_tree)
    git(["worktree", "add", "-b", "feat/keep", str(keep), "main"], cwd=work_tree)

    repo = repo_root()
    prefix = f".worktrees/{work_tree.name}/fixture_remove"
    spec = {"args": ["--prefix", prefix], "timeout_sec": 20}
    result = run_smoke_script(
        SCRIPT_CLEANUP_WORKTREES,
        "cleanup-worktrees-dry-run",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result

    assert remove_a.exists(), "dry-run should not remove matching worktree"
    assert keep.exists(), "dry-run should not remove non-matching worktree"

    listing = git_output(["worktree", "list", "--porcelain"], cwd=work_tree)
    assert str(remove_a) in listing
    assert str(keep) in listing


@pytest.mark.script_smoke
def test_script_smoke_cleanup_worktrees_requires_prefix(tmp_path: Path) -> None:
    work_tree, _ = init_fixture_repo(tmp_path)

    repo = repo_root()
    spec = {
        "args": [],
        "timeout_sec": 10,
        "expect": {"exit_codes": [1], "stderr_regex": r"--prefix is required"},
    }
    result = run_smoke_script(
        SCRIPT_CLEANUP_WORKTREES,
        "cleanup-worktrees-missing-prefix",
        spec,
        repo,
        cwd=work_tree,
    )
    SCRIPT_SMOKE_RUN_RESULTS.append(result)
    assert result.status == "pass", result
