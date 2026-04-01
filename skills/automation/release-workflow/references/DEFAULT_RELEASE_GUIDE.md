# Default Release Guide (fallback)

Use this guide only when the target repository does not provide its own release guide.

## Preconditions

- Run in the target repo root.
- Working tree is clean: `git status -sb`
- On the target branch (default: `main`)
- Current branch tracks an upstream and is publishable (`git status -sb` should not show ahead/behind drift after the release commit is pushed)
- GitHub CLI is authenticated (when publishing GitHub Releases): `gh auth status`

## Steps

1. Decide version + date
   - Version: `vX.Y.Z`
   - Date: `YYYY-MM-DD` (e.g. `date +%Y-%m-%d`)

2. Update `CHANGELOG.md`
   - Add a new heading at the top: `## vX.Y.Z - YYYY-MM-DD`
   - Ensure release content is complete:
     - Remove any `...` placeholders and `<!-- ... -->` HTML comments.
     - Remove empty sections; keep section order.
     - For `### Added`, `### Changed`, `### Fixed`: if a section is `None`, remove the whole section (do not write `- None.`).
     - For issue/PR references, use plain `#123` (no backticks) so GitHub auto-links are clickable.

3. (Only when code changed) run the repo’s lint/test/build checks and record results

4. Commit the changelog
   - Commit message should match the repo’s conventions (if any).

5. Publish the GitHub release from the changelog entry
   - Use the single entrypoint script (extract notes + audit + current-branch push when needed + create/edit + non-empty body verification):
     - `$AGENT_HOME/skills/automation/release-workflow/scripts/release-publish-from-changelog.sh --repo . --version vX.Y.Z --push-current-branch`

6. Verify the release
   - `gh release view vX.Y.Z`

## Stop conditions

- Any step is unclear: stop and ask.
- `release-publish-from-changelog.sh` fails: stop; fix issues before publishing.
