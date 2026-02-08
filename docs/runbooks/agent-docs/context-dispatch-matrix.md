# Context Dispatch Matrix (Runtime Intent -> Resolution Order)

## Scope

- This document is the canonical dispatch contract for `agent-docs` context loading.
- Built-in contexts covered here: `startup`, `task-tools`, `project-dev`, `skill-dev`.
- `AGENTS.md` and `AGENTS.override.md` must reference this file instead of duplicating dispatch rules.

## Built-in contexts and trigger points

| Context | Trigger points | Runtime intent signals | Gate level |
| --- | --- | --- | --- |
| `startup` | First turn in a new session, session resume, or policy reload at task start | "continue", "resume", any new task start | Hard gate |
| `task-tools` | Technical lookup before/during work | "look up", "latest", "docs", "verify source", external API/library uncertainty | Soft gate (hard when user demands strict authoritative lookup) |
| `project-dev` | Any repository implementation flow | edit code, run tests/build, refactor, fix bug, prepare commit/PR | Hard gate for write actions |
| `skill-dev` | Skill lifecycle work | create/update/remove skills, skill contract/governance checks | Hard gate |

## Runtime intent decision examples

| Example user request | Runtime intent | Why this intent | Required preflight sequence |
| --- | --- | --- | --- |
| "Please check whether this repo is ready before we start." | `startup` | Session/readiness check only; no implementation scope yet. | `startup` strict |
| "Fix the merge-parent bug in `staged` and add tests." | `project implementation` | Requests file edits and test updates in a project repo. | `startup` strict -> `project-dev` strict |
| "Compare best practices for clap mutually exclusive flags and cite sources." | `technical research` | External lookup and analysis requested; no direct code change required. | `startup` strict -> `task-tools` strict |
| "Create a new Codex skill with `SKILL.md` and scripts." | `skill authoring` | Scope is skill lifecycle artifacts and governance/contracts. | `startup` strict -> `skill-dev` strict |
| "Research first, then implement once we pick an option." | staged (`technical research` -> `project implementation`) | Mixed flow: research phase first, implementation phase second. Re-evaluate intent at phase boundary. | Phase 1: `startup` strict -> `task-tools` strict. Phase 2: `startup` strict (if needed) -> `project-dev` strict. |

## Runtime intent -> context resolution order (with preflight)

| Workflow type | Required preflight commands | Context resolution order | Strictness policy | Missing required docs fallback |
| --- | --- | --- | --- | --- |
| Startup session load | `agent-docs resolve --context startup --strict --format checklist` | `startup` | Strict required | If strict resolve fails: run `agent-docs baseline --check --target all --strict --format text`, block task execution (read-only diagnostics only), report missing docs and stop. |
| Technical research | `agent-docs resolve --context startup --strict --format checklist` (session entry), `agent-docs resolve --context task-tools --strict --format checklist` | `startup -> task-tools` | Startup strict required; `task-tools` strict first, may downgrade to non-strict after strict failure | If `startup` strict resolve fails: run strict baseline check for all scopes and stop. If `task-tools` strict resolve fails: run strict baseline check for all scopes, rerun `agent-docs resolve --context task-tools --format checklist`; continue only with `status=present` docs and explicitly label degraded mode. If no usable docs remain, stop. |
| Project implementation | `agent-docs resolve --context startup --strict --format checklist` (session entry), `agent-docs resolve --context project-dev --strict --format checklist`; optional `agent-docs resolve --context task-tools --format checklist` when external lookup is needed | `startup -> project-dev -> task-tools` (optional) | `startup` and `project-dev` strict required before edits/tests/commit; `task-tools` strict optional | If `startup` or `project-dev` strict resolve fails: block file edits/commit, run `agent-docs baseline --check --target all --strict --format text`, request remediation. If only `task-tools` is missing: proceed with local-repo evidence only and mark assumptions. |
| Skill authoring | `agent-docs resolve --context startup --strict --format checklist` (session entry), `agent-docs resolve --context skill-dev --strict --format checklist`; optional `agent-docs resolve --context task-tools --format checklist` | `startup -> skill-dev -> task-tools` (optional) | `startup` and `skill-dev` strict required; `task-tools` strict optional | If `startup` or `skill-dev` strict resolve fails: block skill file changes, run `agent-docs baseline --check --target all --strict --format text`, remediation-first. If only `task-tools` is missing: continue with local skill templates/contracts only, no external claims without citation. |

## Strict vs non-strict rules (concrete)

1. Strict mode: use `agent-docs resolve --context <ctx> --strict --format checklist`. Any missing required doc is a failure signal for that context.
2. Non-strict mode: use `agent-docs resolve --context <ctx> --format checklist`. Missing required docs are allowed but must be surfaced.
3. Hard-gate contexts: `startup`, `project-dev` (for write operations), `skill-dev`.
4. Soft-gate context: `task-tools` unless user explicitly requests strict/authoritative verification, in which case treat it as hard gate.
5. Degraded-mode execution is allowed only after an explicit strict failure on a soft-gate context, and the response must list assumptions and missing documents.

## Operator checklist

1. Identify workflow type from runtime intent.
2. Execute preflight commands in the order defined by the matrix row.
3. Apply hard/soft gate behavior exactly as defined above.
4. If degraded mode is used, explicitly disclose it in the response.
