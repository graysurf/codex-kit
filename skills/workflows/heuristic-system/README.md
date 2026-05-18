# HEURISTIC_SYSTEM Workflow Skills

This area contains workflow skills for operating the agent-kit
HEURISTIC_SYSTEM loop. Keep skills here narrow: each skill should own one
lifecycle surface and route implementation work to planning, provider, or domain
workflows instead of becoming a catch-all maintenance mode.

## Skills

- `heuristic-error-inbox`: create, verify, triage, update, and archive curated
  `heuristic-system/error-inbox/` entries.

## Compression

Use lightweight compression before adding new workflow surfaces:

1. Update the relevant skill policy, script, test, runbook, or primitive
   contract.
2. Mark the inbox entry `promoted` or `wontfix` only after the durable outcome is
   linked.
3. Archive completed inbox entries so the active backlog stays small.
4. Create an operation record only for repeated, cross-skill, audit-worthy, or
   broader lessons.

## Future Slices

- `heuristic-operation-record`: promote fixed or accepted inbox entries into
  compressed operation records after real promotion cases prove the command
  surface.
- `heuristic-compression-review`: group repeated lessons and recommend smaller
  durable rules after several related archived inbox or operation records exist
  in one workflow family.
