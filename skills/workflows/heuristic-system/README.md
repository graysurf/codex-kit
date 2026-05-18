# HEURISTIC_SYSTEM Workflow Skills

This area contains workflow skills for operating the agent-kit
HEURISTIC_SYSTEM loop. Keep skills here narrow: each skill should own one
lifecycle surface and route implementation work to planning, provider, or domain
workflows instead of becoming a catch-all maintenance mode.

## Skills

- `heuristic-error-inbox`: create, verify, triage, and update curated
  `heuristic-system/error-inbox/` entries.

## Future Slices

- `heuristic-operation-record`: promote fixed or accepted inbox entries into
  compressed operation records after real promotion cases prove the command
  surface.
- `heuristic-compression-review`: group repeated lessons and recommend smaller
  durable rules after enough inbox and operation records exist.
