# Project-specific skills (local-only)

This folder is intentionally excluded from git. Use it for per-project or private
skills (internal APIs, databases, or customer-specific workflows) that should
not be shared or versioned.

Tracked exception:

- `skills/_projects/_libs/` is versioned and intended for **shared, non-executable**
  helpers that are safe to share across multiple local `_projects` skills.

Keep anything meant to be tracked as a skill under the main `skills/` directories
instead.
