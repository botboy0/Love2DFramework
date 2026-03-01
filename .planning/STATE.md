# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** Discovery-driven progression loop — every new material reveals recipe hints, pulling the player deeper into exploration and automation
**Current focus:** Phase 1 - DevOps Foundation

## Current Position

Phase: 1 of 2 (DevOps Foundation)
Plan: 1 of TBD in current phase
Status: In progress
Last activity: 2026-03-01 — Completed 01-01 (scaffold + linting + formatting)

Progress: [█░░░░░░░░░] 10%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 2 min
- Total execution time: 2 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-devops-foundation | 1 | 2 min | 2 min |

**Recent Trend:**
- Last 5 plans: 01-01 (2 min)
- Trend: establishing baseline

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- DevOps before game code: Previous attempt degraded without enforcement — ci and pre-commit come first
- Plugin architecture: Each feature registers via plugin:init(ctx); no cross-plugin imports allowed
- ECS-first: All game logic must live in ECS systems, nowhere else
- selene rule name: Use `unscoped_variables = "deny"` not `global_usage` — correct selene 0.30.0 rule name for undeclared globals
- Unused param convention: Prefix with `_` (e.g., `_dt`) to satisfy selene unused_variable rule

### Pending Todos

None yet.

### Blockers/Concerns

- Watch: bitser on Android must be verified early (interpreted Lua path) — defer to Phase 2 transport work

## Session Continuity

Last session: 2026-03-01
Stopped at: Completed 01-01-PLAN.md — scaffold, selene, and stylua configured
Resume file: None
