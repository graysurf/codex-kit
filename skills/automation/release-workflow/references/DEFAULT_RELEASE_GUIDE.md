# Default Release Guide (fallback)

Use this guide only when the target repository does not provide its own release guide.

## Preconditions

- Run in the target repo root.
- Working tree is clean: `git status -sb`
- On the target branch (default: `main`)
- GitHub CLI is authenticated (when publishing GitHub Releases): `gh auth status`

## Steps

1. Decide version + date
   - Version: `vX.Y.Z`
   - Date: `YYYY-MM-DD` (e.g. `date +%Y-%m-%d`)

2. Update `CHANGELOG.md`
   - Scaffold a new entry:
     - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-scaffold-entry.sh --repo . --version vX.Y.Z --date YYYY-MM-DD --output "$CODEX_HOME/out/release-entry-vX.Y.Z.md"`
   - Insert the scaffolded entry at the top of `CHANGELOG.md`.
   - Remove placeholders and scaffolding:
     - Remove any `...` placeholders and `<!-- ... -->` HTML comments.
     - Remove empty sections; keep section order.
   - Audit the changelog and stop if it fails:
     - `$CODEX_HOME/skills/automation/release-workflow/scripts/audit-changelog.zsh --repo . --check`

3. Verify prereqs (strict)
   - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-audit.sh --repo . --version vX.Y.Z --branch main --strict`

4. (Only when code changed) run the repo’s lint/test/build checks and record results

5. Commit the changelog
   - Commit message should match the repo’s conventions (if any).

6. Publish the GitHub release from the changelog entry
   - Extract release notes:
     - `$CODEX_HOME/skills/automation/release-workflow/scripts/release-notes-from-changelog.sh --version vX.Y.Z --output "$CODEX_HOME/out/release-notes-vX.Y.Z.md"`
   - Create the release:
     - `gh release create vX.Y.Z -F "$CODEX_HOME/out/release-notes-vX.Y.Z.md" --title "vX.Y.Z"`

7. Verify the release
   - `gh release view vX.Y.Z`

## Stop conditions

- Any step is unclear: stop and ask.
- `audit-changelog.zsh --check` fails: stop; do not publish.
- `release-audit.sh --strict` fails: stop; fix issues before publishing.
